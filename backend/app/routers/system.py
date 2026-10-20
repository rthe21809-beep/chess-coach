"""Health and metadata."""
from __future__ import annotations
import chess
from fastapi import APIRouter
from ..config import settings
from ..coach import SUGGESTED_MODELS
from ..engine import engines
from ..openings import opening_name

router = APIRouter()

@router.get("/health")
async def health():
    return {
        "ok": True, "version": "1.0.0",
        "groqConfigured": bool(settings.groq_api_key),
        "cloudFallback": settings.enable_cloud_fallback,
        "engines": await engines.status(),
        "suggestedModels": SUGGESTED_MODELS,
        "defaultModel": settings.groq_default_model,
    }

@router.get("/opening")
async def opening(fen: str):
    board = chess.Board(fen)
    san_moves = [board.san(m) for m in board.move_stack]
    return {"name": opening_name(san_moves) if san_moves else None}
