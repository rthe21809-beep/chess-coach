"""Streamed game review."""
from __future__ import annotations
import json
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from ..analysis import review_game
from ..models import ReviewRequest

router = APIRouter()
SSE_HEADERS = {"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"}

@router.post("/review")
async def review(payload: ReviewRequest):
    async def gen():
        try:
            async for item in review_game(payload.pgn, payload.params,
                                           depth=payload.depth, max_moves=payload.max_moves):
                event = item.get("event", "message")
                data = item.get("data", {})
                yield f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"
        except Exception as exc:
            yield f"event: error\ndata: {json.dumps({'detail': str(exc)})}\n\n"
    return StreamingResponse(gen(), media_type="text/event-stream", headers=SSE_HEADERS)
