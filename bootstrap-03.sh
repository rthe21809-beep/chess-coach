#!/usr/bin/env bash
# bootstrap-03.sh — backend/app/analysis.py
# Analysis orchestration, cloud fallbacks, and full game review.
set -euo pipefail

[ -f backend/app/engine.py ] || { echo "ERROR: run bootstrap-02.sh first"; exit 1; }

echo "→ bootstrap-03: analysis.py"

cat > backend/app/analysis.py << 'PYEOF'
"""Analysis orchestration, cloud fallbacks, and full-game review."""
from __future__ import annotations

import asyncio
import io
import logging
import math
import re
from typing import AsyncIterator, Optional

import chess
import chess.pgn
import httpx

from .config import settings
from .engine import EngineUnavailable, engines
from .models import (
    AnalysisLine,
    AnalysisResult,
    EngineParams,
    GameReview,
    ReviewedMove,
)
from .openings import opening_name

logger = logging.getLogger("chess_coach.analysis")

MATE_CP = 1200.0
UCI_RE = re.compile(r"^[a-h][1-8][a-h][1-8][qrbn]?$")

CLASSES = [
    "brilliant",
    "great",
    "best",
    "excellent",
    "good",
    "book",
    "inaccuracy",
    "mistake",
    "blunder",
    "miss",
]

# ── helpers ───────────────────────────────────────────────────────────────

def line_white_cp(line: Optional[AnalysisLine]) -> Optional[float]:
    """White-POV centipawns, mates mapped to +/-1200."""
    if line is None:
        return None
    if line.mate is not None:
        return MATE_CP if line.mate > 0 else -MATE_CP
    return float(line.score_cp or 0)

def win_percent(white_cp: Optional[float]) -> float:
    """Lichess win% model, White POV."""
    cp = max(-MATE_CP, min(MATE_CP, white_cp or 0.0))
    return 50.0 + 50.0 * (2.0 / (1.0 + math.exp(-0.00368208 * cp)) - 1.0)

def accuracy_from_drop(drop: float) -> float:
    """Lichess accuracy curve for one move."""
    value = 103.1668 * math.exp(-0.04354 * max(0.0, drop)) - 3.1669
    return max(0.0, min(100.0, value))

# ── local engine with cloud fallback ──────────────────────────────────────

async def analyze_position(
    fen: str,
    params: EngineParams,
    *,
    depth: Optional[int] = None,
    multipv: Optional[int] = None,
) -> AnalysisResult:
    try:
        return await engines.analyze(fen, params, depth=depth, multipv=multipv)
    except EngineUnavailable as exc:
        logger.warning("local engine unavailable: %s", exc)
        local_error = str(exc)
    except Exception as exc:
        logger.exception("engine failure")
        local_error = str(exc)

    if settings.enable_cloud_fallback:
        for fallback in (lichess_cloud_eval, chess_api_analyze):
            try:
                result = await fallback(fen, depth or 14, multipv or 1)
                if result is not None:
                    return result
            except Exception as exc:
                logger.warning("cloud fallback %s failed: %s", fallback.__name__, exc)

    return AnalysisResult(fen=fen, source="none", lines=[], error=local_error)

async def lichess_cloud_eval(
    fen: str, depth: int, multipv: int
) -> Optional[AnalysisResult]:
    """Free, no API key. Values are White POV."""
    url = "https://lichess.org/api/cloud-eval"
    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.get(
            url, params={"fen": fen, "multiPv": str(max(1, multipv))}
        )
        if response.status_code != 200:
            return None
        data = response.json()

    board = chess.Board(fen)
    lines: list[AnalysisLine] = []
    for index, pv in enumerate(data.get("pvs", [])[:multipv], start=1):
        probe = board.copy(stack=False)
        sans: list[str] = []
        ucis: list[str] = []
        for uci in (pv.get("moves") or "").split():
            try:
                move = chess.Move.from_uci(uci)
            except ValueError:
                break
            if move not in probe.legal_moves:
                break
            ucis.append(uci)
            sans.append(probe.san(move))
            probe.push(move)
        if not ucis:
            continue
        lines.append(
            AnalysisLine(
                multipv=index,
                score_cp=pv.get("cp"),
                mate=None,
                pv_san=sans,
                pv_uci=ucis,
                depth=int(data.get("depth") or depth),
            )
        )

    if not lines:
        return None

    return AnalysisResult(
        fen=fen,
        depth=int(data.get("depth") or depth),
        nodes=int((data.get("knodes") or 0) * 1000),
        time_ms=0,
        source="lichess",
        best_move_uci=lines[0].pv_uci[0],
        best_move_san=lines[0].pv_san[0],
        lines=lines,
    )

async def chess_api_analyze(
    fen: str, depth: int, multipv: int
) -> Optional[AnalysisResult]:
    """Free Stockfish endpoint (best effort; schema is loosely documented)."""
    payload = {"fen": fen, "depth": max(10, min(18, depth)), "variants": 1}
    async with httpx.AsyncClient(timeout=25.0) as client:
        response = await client.post("https://chess-api.com/v1", json=payload)
        if response.status_code != 200:
            return None
        data = response.json()

    item = data[0] if isinstance(data, list) and data else data
    if not isinstance(item, dict):
        return None

    board = chess.Board(fen)
    raw_eval = item.get("eval")
    score_cp: Optional[int] = None
    if isinstance(raw_eval, (int, float)):
        if abs(float(raw_eval)) <= 50:
            score_cp = int(round(float(raw_eval) * 100))
        else:
            score_cp = int(raw_eval)

    best_uci: Optional[str] = None
    best_san: Optional[str] = None
    raw_move = str(item.get("move") or "").strip()
    if UCI_RE.match(raw_move):
        best_uci = raw_move
    elif raw_move:
        try:
            best_san = raw_move
            best_uci = board.parse_san(raw_move).uci()
        except ValueError:
            best_uci = None

    if not best_uci and score_cp is None:
        return None

    pv_san = [best_san] if best_san else []
    pv_uci = [best_uci] if best_uci else []
    if best_uci and not best_san:
        try:
            pv_san = [board.san(chess.Move.from_uci(best_uci))]
        except ValueError:
            pv_san = []

    lines = (
        [
            AnalysisLine(
                multipv=1,
                score_cp=score_cp,
                mate=None,
                pv_san=pv_san,
                pv_uci=pv_uci,
                depth=int(item.get("depth") or depth),
            )
        ]
        if (pv_uci or score_cp is not None)
        else []
    )

    return AnalysisResult(
        fen=fen,
        depth=int(item.get("depth") or depth),
        nodes=0,
        time_ms=0,
        source="chess-api",
        best_move_uci=best_uci,
        best_move_san=pv_san[0] if pv_san else None,
        lines=lines,
    )

# ── full game review ──────────────────────────────────────────────────────

def _classify(
    *,
    drop: float,
    is_best: bool,
    missed_mate: bool,
    is_book: bool,
) -> str:
    if missed_mate:
        return "miss"
    if is_book:
        return "book"
    if is_best:
        return "best"
    if drop >= 30:
        return "blunder"
    if drop >= 20:
        return "mistake"
    if drop >= 10:
        return "inaccuracy"
    if drop >= 5:
        return "good"
    if drop >= 2:
        return "excellent"
    return "good"

async def review_game(
    pgn: str,
    params: EngineParams,
    *,
    depth: int = 12,
    max_moves: int = 120,
) -> AsyncIterator[dict]:
    """Async generator of SSE-shaped dicts: progress ... result | error."""
    try:
        game = chess.pgn.read_game(io.StringIO(pgn))
    except Exception as exc:
        yield {"event": "error", "data": {"detail": f"Could not parse PGN: {exc}"}}
        return

    if game is None:
        yield {"event": "error", "data": {"detail": "The PGN is empty."}}
        return

    moves = list(game.mainline_moves())[: max(1, max_moves)]
    if not moves:
        yield {"event": "error", "data": {"detail": "The PGN contains no moves."}}
        return

    total = len(moves) + 1
    board = chess.Board()
    before = await analyze_position(board.fen(), params, depth=depth, multipv=1)
    if before.error and not before.lines:
        yield {"event": "error", "data": {"detail": before.error}}
        return

    yield {"event": "progress", "data": {"done": 1, "total": total}}

    reviewed: list[ReviewedMove] = []
    counts: dict[str, dict[str, int]] = {name: {"w": 0, "b": 0} for name in CLASSES}
    accuracies: dict[str, list[float]] = {"w": [], "b": []}
    losses: dict[str, list[float]] = {"w": [], "b": []}
    san_history: list[str] = []

    for ply, move in enumerate(moves, start=1):
        fen_before = board.fen()
        mover = "w" if board.turn == chess.WHITE else "b"
        san = board.san(move)
        uci = move.uci()
        san_history.append(san)
        board.push(move)
        after = await analyze_position(board.fen(), params, depth=depth, multipv=1)

        line_before = before.lines[0] if before.lines else None
        line_after = after.lines[0] if after.lines else None
        white_before = line_white_cp(line_before)
        white_after = line_white_cp(line_after)

        if white_before is not None and white_after is not None:
            if mover == "w":
                mover_before = win_percent(white_before)
                mover_after = win_percent(white_after)
                cp_loss = max(0.0, white_before - white_after)
            else:
                mover_before = 100.0 - win_percent(white_before)
                mover_after = 100.0 - win_percent(white_after)
                cp_loss = max(0.0, white_after - white_before)
            drop = max(0.0, mover_before - mover_after)
        else:
            drop = 0.0
            cp_loss = 0.0

        best_uci = before.best_move_uci
        is_best = bool(best_uci and best_uci == uci)
        mate_before = line_before.mate if line_before else None
        mate_after = line_after.mate if line_after else None
        sign = 1 if mover == "w" else -1
        missed_mate = bool(
            mate_before is not None
            and (mate_before * sign) > 0
            and (mate_after is None or (mate_after * sign) <= 0)
        )
        is_book = ply <= 16 and opening_name(san_history) is not None

        classification = _classify(
            drop=drop,
            is_best=is_best,
            missed_mate=missed_mate,
            is_book=is_book,
        )
        counts[classification][mover] += 1
        accuracies[mover].append(accuracy_from_drop(drop))
        losses[mover].append(min(cp_loss, 1000.0))

        reviewed.append(
            ReviewedMove(
                ply=ply,
                move_number=(ply + 1) // 2,
                color=mover,
                san=san,
                uci=uci,
                fen_before=fen_before,
                fen_after=board.fen(),
                eval_before_cp=white_before,
                eval_after_cp=white_after,
                mate_before=mate_before,
                mate_after=mate_after,
                cp_loss=round(cp_loss, 1),
                classification=classification,
                best_move_san=before.best_move_san,
                best_move_uci=best_uci,
            )
        )

        before = after
        yield {"event": "progress", "data": {"done": ply + 1, "total": total}}
        await asyncio.sleep(0)

    def mean(values: list[float]) -> float:
        return round(sum(values) / len(values), 1) if values else 0.0

    review = GameReview(
        white_accuracy=mean(accuracies["w"]),
        black_accuracy=mean(accuracies["b"]),
        white_acpl=mean(losses["w"]),
        black_acpl=mean(losses["b"]),
        counts=counts,
        moves=reviewed,
        opening=opening_name(san_history),
        source=before.source,
    )
    yield {"event": "result", "data": review.model_dump(by_alias=True)}
PYEOF

echo ""
echo "✓ bootstrap-03 done. analysis.py created."
python -c "import ast; ast.parse(open('backend/app/analysis.py').read()); print('analysis.py parses OK')"
echo ""
echo "Backend python files:"
find backend -name '*.py' | sort
echo ""
echo "Next: bootstrap-04.sh (coach.py)"
