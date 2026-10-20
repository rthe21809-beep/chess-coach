#!/usr/bin/env bash
# bootstrap-04.sh — backend/app/coach.py
# Groq-backed coach, grounded in engine output, with an offline fallback.
set -euo pipefail

[ -f backend/app/analysis.py ] || { echo "ERROR: run bootstrap-03.sh first"; exit 1; }

echo "→ bootstrap-04: coach.py"

cat > backend/app/coach.py << 'PYEOF'
"""Groq-backed chess coach, grounded in engine output, with an offline fallback."""
from __future__ import annotations

import json
import logging
from typing import AsyncIterator, Optional

import chess
import httpx

from .analysis import analyze_position, line_white_cp
from .config import settings
from .models import AnalysisResult, ChatRequest, CoachContext, EngineParams

logger = logging.getLogger("chess_coach.coach")

SUGGESTED_MODELS = [
    "openai/gpt-oss-120b",
    "openai/gpt-oss-20b",
    "moonshotai/kimi-k2-instruct",
    "qwen/qwen3-32b",
    "deepseek-r1-distill-llama-70b",
    "llama-3.3-70b-versatile",
]

SYSTEM_PROMPT = """You are Coach Nova, a calm, precise chess coach.

Hard rules:
- Ground every claim in the ENGINE DATA and GAME DATA given to you.
- Never invent moves, evaluations, or variations. If the data does not contain an answer, say so.
- Recommend moves in SAN (Nf3, exd5, O-O), not UCI.
- Do not use markdown tables. Short bullet lists are fine.
- Answer in the language the student asked for.

Default answer shape:
1) Direct answer in 1-2 sentences.
2) "Why" - 2 to 4 short bullets.
3) "Train this" - 1 or 2 concrete drills.

Keep it under ~220 words unless the student explicitly asks for a deep dive.
"""

# ── context building ──────────────────────────────────────────────────────

async def _last_move_note(
    ctx: CoachContext, params: EngineParams
) -> tuple[Optional[str], Optional[AnalysisResult]]:
    if not ctx.fen_before or not ctx.last_move_san:
        return None, None
    try:
        before = await analyze_position(
            ctx.fen_before, params, depth=min(params.depth, 14), multipv=1
        )
        after = await analyze_position(
            ctx.fen, params, depth=min(params.depth, 14), multipv=1
        )
    except Exception as exc:
        logger.warning("last-move analysis failed: %s", exc)
        return None, None

    white_before = line_white_cp(before.lines[0] if before.lines else None)
    white_after = line_white_cp(after.lines[0] if after.lines else None)
    if white_before is None or white_after is None:
        return None, after

    mover_is_white = chess.Board(ctx.fen_before).turn == chess.WHITE
    loss = (white_before - white_after) if mover_is_white else (white_after - white_before)
    loss = max(0.0, loss)
    best = before.best_move_san or "unknown"
    note = (
        f"LAST MOVE: {ctx.last_move_san}. Engine eval before {white_before / 100:+.2f}, "
        f"after {white_after / 100:+.2f} (White POV). Centipawn loss for the mover: {loss:.0f}. "
        f"Engine preferred {best}."
    )
    return note, after

def _analysis_block(analysis: Optional[AnalysisResult]) -> list[str]:
    if not analysis or not analysis.lines:
        return ["ENGINE: no analysis available for this position."]
    out = [f"ENGINE ({analysis.source}, depth {analysis.depth}):"]
    for line in analysis.lines[:3]:
        if line.mate is not None:
            score = f"M{line.mate}" if line.mate > 0 else f"-M{abs(line.mate)}"
        else:
            score = f"{(line.score_cp or 0) / 100:+.2f}"
        pv = " ".join(line.pv_san[:10]) if line.pv_san else "(no variation)"
        out.append(f"  #{line.multipv} eval {score} (White POV): {pv}")
    if analysis.best_move_san:
        out.append(f"Engine best move: {analysis.best_move_san}")
    return out

def _context_block(
    ctx: CoachContext,
    analysis: Optional[AnalysisResult],
    last_move_note: Optional[str],
) -> str:
    board = chess.Board(ctx.fen)
    parts = [
        f"FEN: {ctx.fen}",
        f"Side to move: {'White' if board.turn else 'Black'}",
        f"Move number: {board.fullmove_number}",
        f"Student plays: {'White' if ctx.player_color == 'w' else 'Black'} "
        f"(~{ctx.player_rating} Elo)",
        f"Answer language: {ctx.language}",
    ]
    if ctx.last_moves:
        parts.append("Recent moves (SAN): " + " ".join(ctx.last_moves[-12:]))
    if ctx.pgn:
        parts.append("PGN so far:\n" + ctx.pgn[:4000])
    parts.extend(_analysis_block(analysis))
    if last_move_note:
        parts.append(last_move_note)
    if ctx.extra_context:
        parts.append("GAME REVIEW SUMMARY:\n" + ctx.extra_context[:2500])
    return "\n".join(parts)

async def build_messages(
    req: ChatRequest,
) -> tuple[list[dict], Optional[AnalysisResult]]:
    params = req.params
    analysis = req.context.analysis
    if analysis is None or not analysis.lines:
        analysis = await analyze_position(
            req.context.fen,
            params,
            depth=min(max(params.depth, 10), 16),
            multipv=1,
        )
    last_move_note, after = await _last_move_note(req.context, params)
    if after is not None and (analysis is None or not analysis.lines):
        analysis = after

    context = _context_block(req.context, analysis, last_move_note)

    messages: list[dict] = [{"role": "system", "content": SYSTEM_PROMPT}]
    messages.append(
        {"role": "system", "content": "REFERENCE DATA (authoritative):\n" + context}
    )
    for message in req.messages[-16:]:
        messages.append({"role": message.role, "content": message.content})
    if not req.messages:
        messages.append(
            {
                "role": "user",
                "content": "What should I be thinking about in this position?",
            }
        )
    return messages, analysis

def fallback_text(
    analysis: Optional[AnalysisResult], note: Optional[str]
) -> str:
    parts: list[str] = []
    if analysis and analysis.lines:
        line = analysis.lines[0]
        if line.mate is not None:
            score = (
                f"mate in {abs(line.mate)} for "
                f"{'White' if line.mate > 0 else 'Black'}"
            )
        else:
            score = f"{(line.score_cp or 0) / 100:+.2f} (White POV)"
        parts.append(f"Engine view at depth {analysis.depth}: {score}.")
        if analysis.best_move_san:
            parts.append(f"Best move: {analysis.best_move_san}.")
        if line.pv_san:
            parts.append("Main line: " + " ".join(line.pv_san[:8]) + ".")
    else:
        parts.append("The engine did not return an evaluation for this position.")
    if note:
        parts.append(note)
    parts.append(
        "This is the offline summary. Add GROQ_API_KEY to backend/.env to unlock "
        "full conversational coaching."
    )
    return " ".join(parts)

# ── Groq ──────────────────────────────────────────────────────────────────

def _sse(payload: dict, event: Optional[str] = None) -> str:
    prefix = f"event: {event}\n" if event else ""
    return f"{prefix}data: {json.dumps(payload, ensure_ascii=False)}\n\n"

async def stream_chat(req: ChatRequest) -> AsyncIterator[str]:
    try:
        messages, analysis = await build_messages(req)
        note, _ = await _last_move_note(req.context, req.params)
    except Exception as exc:
        logger.exception("failed to build coach context")
        yield _sse(
            {"detail": f"Could not prepare coaching context: {exc}"}, "error"
        )
        return

    if not settings.groq_api_key:
        text = fallback_text(analysis, note)
        for start in range(0, len(text), 24):
            yield _sse({"delta": text[start : start + 24]})
        yield _sse({"done": True, "offline": True})
        return

    payload = {
        "model": req.model_name or settings.groq_default_model,
        "messages": messages,
        "temperature": max(0.0, min(1.5, req.temperature)),
        "max_tokens": 900,
        "stream": True,
    }
    headers = {
        "Authorization": f"Bearer {settings.groq_api_key}",
        "Content-Type": "application/json",
    }
    url = f"{settings.groq_base_url.rstrip('/')}/chat/completions"

    timeout = httpx.Timeout(settings.request_timeout_s, connect=10.0)
    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            async with client.stream(
                "POST", url, headers=headers, json=payload
            ) as response:
                if response.status_code != 200:
                    body = (await response.aread()).decode("utf-8", "replace")[:400]
                    hint = ""
                    if response.status_code == 429:
                        retry = response.headers.get("retry-after")
                        hint = (
                            f" Rate limited; retry after {retry}s."
                            if retry
                            else " Rate limited."
                        )
                    yield _sse(
                        {
                            "detail": f"Groq error {response.status_code}.{hint} {body}"
                        },
                        "error",
                    )
                    return

                async for raw_line in response.aiter_lines():
                    if not raw_line or not raw_line.startswith("data:"):
                        continue
                    chunk = raw_line[5:].strip()
                    if chunk == "[DONE]":
                        break
                    try:
                        obj = json.loads(chunk)
                    except json.JSONDecodeError:
                        continue
                    choices = obj.get("choices") or []
                    if not choices:
                        continue
                    delta = (choices[0].get("delta") or {}).get("content")
                    if delta:
                        yield _sse({"delta": delta})
    except httpx.TimeoutException:
        yield _sse({"detail": "Groq request timed out."}, "error")
        return
    except Exception as exc:
        logger.exception("groq stream failed")
        yield _sse({"detail": f"Groq request failed: {exc}"}, "error")
        return

    yield _sse({"done": True})

async def complete_chat(req: ChatRequest) -> tuple[str, dict]:
    if not settings.groq_api_key:
        messages, analysis = await build_messages(req)
        note, _ = await _last_move_note(req.context, req.params)
        return fallback_text(analysis, note), {"offline": True}

    messages, _ = await build_messages(req)
    payload = {
        "model": req.model_name or settings.groq_default_model,
        "messages": messages,
        "temperature": max(0.0, min(1.5, req.temperature)),
        "max_tokens": 900,
        "stream": False,
    }
    headers = {
        "Authorization": f"Bearer {settings.groq_api_key}",
        "Content-Type": "application/json",
    }
    url = f"{settings.groq_base_url.rstrip('/')}/chat/completions"
    async with httpx.AsyncClient(timeout=settings.request_timeout_s) as client:
        response = await client.post(url, headers=headers, json=payload)
    if response.status_code != 200:
        raise RuntimeError(
            f"Groq error {response.status_code}: {response.text[:300]}"
        )
    data = response.json()
    content = data["choices"][0]["message"]["content"]
    return content, {"offline": False}
PYEOF

echo ""
echo "✓ bootstrap-04 done. coach.py created."
python -c "import ast; ast.parse(open('backend/app/coach.py').read()); print('coach.py parses OK')"
echo ""
echo "Backend python files:"
find backend -name '*.py' | sort
echo ""
echo "Backend is now COMPLETE. Next: bootstrap-05 will install deps and test the backend."
