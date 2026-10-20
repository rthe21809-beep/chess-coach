"""Engine endpoints."""
from __future__ import annotations
from fastapi import APIRouter, HTTPException
from ..analysis import analyze_position
from ..engine import EngineUnavailable, engines
from ..models import AnalysisResult, AnalyzeRequest, BotMoveRequest

router = APIRouter()

@router.post("/engine/analyze", response_model=AnalysisResult)
async def analyze(payload: AnalyzeRequest) -> AnalysisResult:
    return await analyze_position(payload.fen, payload.params,
                                   depth=payload.depth, multipv=payload.multipv)

@router.post("/engine/move")
async def bot_move(payload: BotMoveRequest):
    try:
        return await engines.best_move(payload.fen, payload.params)
    except EngineUnavailable as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=f"Invalid FEN: {exc}") from exc
