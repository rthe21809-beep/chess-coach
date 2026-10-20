"""Coach chat endpoints."""
from __future__ import annotations
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse
from ..coach import SUGGESTED_MODELS, complete_chat, stream_chat
from ..config import settings
from ..models import ChatRequest

router = APIRouter()
SSE_HEADERS = {"Cache-Control": "no-cache", "Connection": "keep-alive", "X-Accel-Buffering": "no"}

@router.get("/models")
async def models():
    return {"suggested": SUGGESTED_MODELS, "default": settings.groq_default_model,
            "groqConfigured": bool(settings.groq_api_key)}

@router.post("/chat")
async def chat(payload: ChatRequest):
    if payload.stream:
        return StreamingResponse(stream_chat(payload),
                                 media_type="text/event-stream", headers=SSE_HEADERS)
    try:
        content, meta = await complete_chat(payload)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    return {"content": content, **meta}
