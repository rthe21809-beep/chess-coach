"""Stockfish / lc0 process management and UCI -> JSON conversion."""
from __future__ import annotations

import asyncio
import logging
import os
import random
import shutil
import time
from typing import Any, Optional

import chess
import chess.engine

from .config import settings
from .models import AnalysisLine, AnalysisResult, EngineParams

logger = logging.getLogger("chess_coach.engine")

KINDS = ("stockfish", "maia")

class EngineUnavailable(RuntimeError):
    """Raised when the engine binary or weights cannot be used."""

class EngineService:
    """One lazily spawned subprocess per engine kind, serialised by a lock."""

    def __init__(self) -> None:
        self._engines: dict[str, chess.engine.SimpleEngine] = {}
        self._locks: dict[str, asyncio.Lock] = {k: asyncio.Lock() for k in KINDS}
        self._applied: dict[str, dict[str, Any]] = {k: {} for k in KINDS}

    # ── discovery ─────────────────────────────────────────────────────────

    def _candidate(self, kind: str) -> str:
        if kind == "maia":
            return settings.lc0_path or shutil.which("lc0") or ""
        return settings.stockfish_path or shutil.which("stockfish") or ""

    @staticmethod
    def _hint(kind: str) -> str:
        if kind == "maia":
            return (
                "Maia/lc0 is not available. In Termux run `pkg install lc0`, "
                "download Maia weights (maia-1100.pb.gz .. maia-1900.pb.gz) and set "
                "LC0_PATH and MAIA_WEIGHTS_DIR in backend/.env. See docs/MAIA.md."
            )
        return (
            "Stockfish was not found. In Termux run `pkg install stockfish`, "
            "or set STOCKFISH_PATH in backend/.env to the full binary path."
        )

    def _binary(self, kind: str) -> str:
        candidate = self._candidate(kind)
        if not candidate:
            raise EngineUnavailable(self._hint(kind))
        resolved = shutil.which(candidate) or (
            candidate if os.path.isfile(candidate) else None
        )
        if not resolved:
            raise EngineUnavailable(self._hint(kind))
        return resolved

    def _weights(self, model: str) -> str:
        if not settings.maia_weights_dir:
            raise EngineUnavailable(
                "MAIA_WEIGHTS_DIR is not set in backend/.env. See docs/MAIA.md."
            )
        safe = model if model.startswith("maia-") else f"maia-{model}"
        for suffix in (".pb.gz", ".pb"):
            path = os.path.join(settings.maia_weights_dir, f"{safe}{suffix}")
            if os.path.isfile(path):
                return path
        raise EngineUnavailable(
            f"Maia weights for '{safe}' not found in {settings.maia_weights_dir}. "
            "See docs/MAIA.md."
        )

    # ── lifecycle ─────────────────────────────────────────────────────────

    def _get(self, kind: str) -> chess.engine.SimpleEngine:
        engine = self._engines.get(kind)
        if engine is not None:
            try:
                engine.ping()
                return engine
            except Exception:
                logger.warning("%s engine died, restarting", kind)
                try:
                    engine.quit()
                except Exception:
                    pass
                self._engines.pop(kind, None)
                self._applied[kind] = {}

        path = self._binary(kind)
        try:
            engine = chess.engine.SimpleEngine.popen_uci(path, timeout=25)
        except Exception as exc:
            raise EngineUnavailable(f"Could not start {kind} ({path}): {exc}") from exc

        if kind == "maia" and "Backend" in engine.options:
            try:
                engine.configure({"Backend": settings.lc0_backend})
            except Exception:
                logger.warning("lc0 backend '%s' rejected", settings.lc0_backend)

        self._engines[kind] = engine
        self._applied[kind] = {}
        return engine

    def _reset(self, kind: str) -> None:
        engine = self._engines.pop(kind, None)
        self._applied[kind] = {}
        if engine is not None:
            try:
                engine.quit()
            except Exception:
                pass

    # ── configuration ─────────────────────────────────────────────────────

    def _configure(
        self,
        kind: str,
        engine: chess.engine.SimpleEngine,
        params: EngineParams,
    ) -> None:
        if kind == "stockfish":
            # Skill Level is forced to max in Elo mode so we do not weaken twice.
            skill = 20 if params.limit_strength else max(0, min(20, params.skill_level))
            desired: dict[str, Any] = {
                "Threads": params.threads,
                "Hash": params.hash_mb,
                "UCI_LimitStrength": params.limit_strength,
                "UCI_Elo": params.elo,
                "Skill Level": skill,
            }
        else:
            desired = {
                "Threads": params.threads,
                "WeightsFile": self._weights(params.maia_model),
            }

        filtered: dict[str, Any] = {}
        for key, value in desired.items():
            option = engine.options.get(key)
            if option is None:
                continue
            if isinstance(value, int) and option.min is not None and option.max is not None:
                value = max(option.min, min(option.max, value))
            filtered[key] = value

        applied = self._applied.setdefault(kind, {})
        diff = {k: v for k, v in filtered.items() if applied.get(k) != v}
        if diff:
            try:
                engine.configure(diff)
            except Exception as exc:
                raise EngineUnavailable(f"Failed to configure {kind}: {exc}") from exc
            applied.update(diff)

    # ── public API ────────────────────────────────────────────────────────

    async def analyze(
        self,
        fen: str,
        params: EngineParams,
        *,
        depth: Optional[int] = None,
        multipv: Optional[int] = None,
        move_time_ms: Optional[int] = None,
    ) -> AnalysisResult:
        kind = params.kind
        try:
            board = chess.Board(fen)
        except ValueError as exc:
            return AnalysisResult(fen=fen, source="none", error=f"Invalid FEN: {exc}")

        if board.is_game_over(claim_draw=False):
            return AnalysisResult(fen=board.fen(), source="local", lines=[])

        want_depth = max(1, depth or params.depth)
        want_time = max(0.05, (move_time_ms or params.move_time_ms) / 1000.0)
        want_multipv = max(1, multipv or params.multi_pv)

        def work():
            engine = self._get(kind)
            self._configure(kind, engine, params)
            if kind == "maia":
                limit = chess.engine.Limit(time=want_time)
            else:
                limit = chess.engine.Limit(depth=want_depth, time=want_time)
            return engine.analyse(board, limit, multipv=want_multipv)

        started = time.perf_counter()
        try:
            async with self._locks[kind]:
                infos = await asyncio.to_thread(work)
        except EngineUnavailable:
            raise
        except Exception as exc:
            self._reset(kind)
            raise EngineUnavailable(str(exc)) from exc
        elapsed_ms = int((time.perf_counter() - started) * 1000)

        if isinstance(infos, dict):
            infos = [infos]

        lines: list[AnalysisLine] = []
        total_nodes = 0
        max_depth = 0
        for index, info in enumerate(infos or [], start=1):
            pv = info.get("pv") or []
            if not pv:
                continue
            total_nodes = max(total_nodes, int(info.get("nodes") or 0))
            max_depth = max(max_depth, int(info.get("depth") or 0))

            score_cp: Optional[int] = None
            mate: Optional[int] = None
            pov = info.get("score")
            if pov is not None:
                white = pov.pov(chess.WHITE)
                mate = white.mate()
                if mate is None:
                    score_cp = white.score()

            probe = board.copy(stack=False)
            sans: list[str] = []
            ucis: list[str] = []
            for move in pv:
                if move not in probe.legal_moves:
                    break
                ucis.append(move.uci())
                sans.append(probe.san(move))
                probe.push(move)

            lines.append(
                AnalysisLine(
                    multipv=index,
                    score_cp=score_cp,
                    mate=mate,
                    pv_san=sans,
                    pv_uci=ucis,
                    depth=max_depth,
                )
            )

        lines.sort(key=lambda line: line.multipv)
        best_uci = lines[0].pv_uci[0] if lines and lines[0].pv_uci else None
        best_san = lines[0].pv_san[0] if lines and lines[0].pv_san else None

        return AnalysisResult(
            fen=board.fen(),
            depth=max_depth,
            nodes=total_nodes,
            time_ms=elapsed_ms,
            source="local",
            best_move_uci=best_uci,
            best_move_san=best_san,
            lines=lines,
        )

    async def best_move(self, fen: str, params: EngineParams) -> dict[str, Any]:
        board = chess.Board(fen)
        if board.is_game_over(claim_draw=False):
            return {"uci": None, "san": None, "promotion": None, "analysis": None}

        result = await self.analyze(
            fen, params, depth=params.depth, multipv=max(1, params.multi_pv)
        )
        candidates = [line for line in result.lines if line.pv_uci]
        if not candidates:
            raise EngineUnavailable(
                result.error or "Engine returned no move for this position."
            )

        # Variety for weaker bots: sample among top lines instead of always #1.
        if params.limit_strength and params.elo <= 1600 and len(candidates) > 1:
            weights = [1.0 / (i + 1) for i in range(len(candidates))]
            chosen = random.choices(candidates, weights=weights, k=1)[0]
        else:
            chosen = candidates[0]

        uci = chosen.pv_uci[0]
        move = chess.Move.from_uci(uci)
        promotion = chess.piece_symbol(move.promotion) if move.promotion else None
        return {
            "uci": uci,
            "san": chosen.pv_san[0] if chosen.pv_san else None,
            "promotion": promotion,
            "analysis": result,
        }

    async def status(self) -> dict[str, Any]:
        out: dict[str, Any] = {}
        for kind in KINDS:
            info: dict[str, Any] = {
                "available": False,
                "path": "",
                "error": None,
                "options": {},
            }
            try:
                info["path"] = self._binary(kind)
                info["available"] = True
            except EngineUnavailable as exc:
                info["error"] = str(exc)
                out[kind] = info
                continue

            def probe():
                engine = self._get(kind)
                wanted = (
                    "UCI_Elo",
                    "Skill Level",
                    "Threads",
                    "Hash",
                    "MultiPV",
                    "WeightsFile",
                    "Backend",
                )
                return {
                    name: {
                        "min": getattr(engine.options[name], "min", None),
                        "max": getattr(engine.options[name], "max", None),
                    }
                    for name in wanted
                    if name in engine.options
                }

            try:
                async with self._locks[kind]:
                    info["options"] = await asyncio.wait_for(
                        asyncio.to_thread(probe), timeout=30
                    )
            except Exception as exc:
                info["error"] = str(exc)
            out[kind] = info
        return out

    async def close(self) -> None:
        for kind in list(self._engines):
            self._reset(kind)

engines = EngineService()
