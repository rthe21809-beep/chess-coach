#!/usr/bin/env bash
# bootstrap-01.sh — backend base: package init, config, models, openings, main, routers.
# Run from the repo root: bash bootstrap-01.sh
set -euo pipefail

mkdir -p backend/app/routers

echo "→ bootstrap-01: backend base"

cat > backend/app/__init__.py << 'PYEOF'
"""Chess Coach backend package."""
__version__ = "1.0.0"
PYEOF

cat > backend/app/config.py << 'PYEOF'
"""Environment-backed settings."""
from __future__ import annotations
from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"), env_file_encoding="utf-8", extra="ignore"
    )
    stockfish_path: str = ""
    lc0_path: str = ""
    maia_weights_dir: str = ""
    lc0_backend: str = "eigen"
    groq_api_key: str = ""
    groq_base_url: str = "https://api.groq.com/openai/v1"
    groq_default_model: str = "openai/gpt-oss-120b"
    enable_cloud_fallback: bool = True
    request_timeout_s: float = 90.0
    log_level: str = "INFO"

settings = Settings()
PYEOF

cat > backend/app/models.py << 'PYEOF'
"""Pydantic models. Python snake_case <-> JSON camelCase."""
from __future__ import annotations
from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field
from pydantic.alias_generators import to_camel

class CamelModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True, protected_namespaces=())

class EngineParams(CamelModel):
    kind: Literal["stockfish", "maia"] = "stockfish"
    limit_strength: bool = True
    elo: int = 1600
    skill_level: int = 20
    depth: int = 14
    move_time_ms: int = 800
    threads: int = 1
    hash_mb: int = 64
    multi_pv: int = 1
    maia_model: str = "maia-1500"

class AnalysisLine(CamelModel):
    multipv: int
    score_cp: Optional[int] = None
    mate: Optional[int] = None
    pv_san: list[str] = Field(default_factory=list)
    pv_uci: list[str] = Field(default_factory=list)
    depth: int = 0

class AnalysisResult(CamelModel):
    fen: str
    depth: int = 0
    nodes: int = 0
    time_ms: int = 0
    source: Literal["local", "lichess", "chess-api", "none"] = "none"
    best_move_uci: Optional[str] = None
    best_move_san: Optional[str] = None
    lines: list[AnalysisLine] = Field(default_factory=list)
    error: Optional[str] = None

class AnalyzeRequest(CamelModel):
    fen: str
    params: EngineParams = Field(default_factory=EngineParams)
    depth: Optional[int] = None
    multipv: Optional[int] = None
    move_time_ms: Optional[int] = None

class BotMoveRequest(CamelModel):
    fen: str
    params: EngineParams = Field(default_factory=EngineParams)

class ReviewRequest(CamelModel):
    pgn: str
    params: EngineParams = Field(default_factory=EngineParams)
    depth: int = 12
    max_moves: int = 120

class ReviewedMove(CamelModel):
    ply: int
    move_number: int
    color: Literal["w", "b"]
    san: str
    uci: str
    fen_before: str
    fen_after: str
    eval_before_cp: Optional[float] = None
    eval_after_cp: Optional[float] = None
    mate_before: Optional[int] = None
    mate_after: Optional[int] = None
    cp_loss: float = 0.0
    classification: str = "good"
    best_move_san: Optional[str] = None
    best_move_uci: Optional[str] = None

class GameReview(CamelModel):
    white_accuracy: float = 0.0
    black_accuracy: float = 0.0
    white_acpl: float = 0.0
    black_acpl: float = 0.0
    counts: dict[str, dict[str, int]] = Field(default_factory=dict)
    moves: list[ReviewedMove] = Field(default_factory=list)
    opening: Optional[str] = None
    source: str = "local"

class CoachMessage(CamelModel):
    role: Literal["system", "user", "assistant"]
    content: str

class CoachContext(CamelModel):
    fen: str
    pgn: Optional[str] = None
    last_moves: list[str] = Field(default_factory=list)
    player_color: Literal["w", "b"] = "w"
    player_rating: int = 1200
    language: str = "English"
    fen_before: Optional[str] = None
    last_move_san: Optional[str] = None
    analysis: Optional[AnalysisResult] = None
    extra_context: Optional[str] = None

class ChatRequest(CamelModel):
    messages: list[CoachMessage] = Field(default_factory=list)
    context: CoachContext
    params: EngineParams = Field(default_factory=EngineParams)
    model_name: str = Field(default="openai/gpt-oss-120b", alias="model")
    temperature: float = 0.4
    stream: bool = True
PYEOF

cat > backend/app/openings.py << 'PYEOF'
"""Tiny prefix-matched opening book."""
from __future__ import annotations
from typing import Optional

_RAW = [
    (("e4","e5","Nf3","Nc6","Bb5"), "Ruy Lopez"),
    (("e4","e5","Nf3","Nc6","Bc4"), "Italian Game"),
    (("e4","e5","Nf3","Nc6","d4"), "Scotch Game"),
    (("e4","e5","Nf3","Nc6","Nc3"), "Four Knights"),
    (("e4","e5","Nf3","Nf6"), "Petrov Defence"),
    (("e4","e5","Nf3","d6"), "Philidor Defence"),
    (("e4","e5","Bc4"), "Bishop Opening"),
    (("e4","e5","Nc3"), "Vienna Game"),
    (("e4","e5","f4"), "King Gambit"),
    (("e4","c5","Nf3","d6","d4"), "Sicilian Open"),
    (("e4","c5","Nf3","Nc6"), "Sicilian Old"),
    (("e4","c5","Nf3","e6"), "Sicilian Kan"),
    (("e4","c5","Nc3"), "Sicilian Closed"),
    (("e4","c5","c3"), "Sicilian Alapin"),
    (("e4","c5","d4"), "Sicilian Morra"),
    (("e4","e6"), "French Defence"),
    (("e4","c6"), "Caro-Kann"),
    (("e4","d5"), "Scandinavian"),
    (("e4","Nf6"), "Alekhine Defence"),
    (("e4","d6"), "Pirc Defence"),
    (("e4","g6"), "Modern Defence"),
    (("d4","d5","c4","e6"), "QGD"),
    (("d4","d5","c4","c6"), "Slav Defence"),
    (("d4","d5","c4","dxc4"), "QGA"),
    (("d4","d5","c4"), "Queen Gambit"),
    (("d4","Nf6","c4","g6","Nc3","Bg7"), "King Indian"),
    (("d4","Nf6","c4","e6","Nc3","Bb4"), "Nimzo-Indian"),
    (("d4","Nf6","c4","e6","Nf3","b6"), "Queen Indian"),
    (("d4","Nf6","c4","c5","d5"), "Benoni Defence"),
    (("d4","f5"), "Dutch Defence"),
    (("d4","d5","Bf4"), "London System"),
    (("d4","Nf6","Bf4"), "London System"),
    (("c4",), "English Opening"),
    (("Nf3",), "Reti Opening"),
    (("b3",), "Nimzo-Larsen"),
    (("f4",), "Bird Opening"),
    (("g3",), "Benko Opening"),
    (("b4",), "Polish Opening"),
    (("d4","d5"), "Queen Pawn Game"),
    (("e4","e5"), "Open Game"),
    (("e4",), "King Pawn"),
    (("d4",), "Queen Pawn"),
]
_TABLE = sorted(_RAW, key=lambda x: len(x[0]), reverse=True)

def opening_name(san_moves):
    for moves, name in _TABLE:
        if len(moves) <= len(san_moves) and tuple(san_moves[:len(moves)]) == moves:
            return name
    return None
PYEOF

cat > backend/app/main.py << 'PYEOF'
"""FastAPI entrypoint."""
from __future__ import annotations
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .engine import engines
from .routers import coach, engine, review, system

logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO),
                    format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("chess_coach")

@asynccontextmanager
async def lifespan(app):
    logger.info("Chess Coach starting")
    yield
    await engines.close()

app = FastAPI(title="Chess Coach API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=False,
                    allow_methods=["*"], allow_headers=["*"])
app.include_router(system.router, prefix="/api/system", tags=["system"])
app.include_router(engine.router, prefix="/api", tags=["engine"])
app.include_router(review.router, prefix="/api", tags=["review"])
app.include_router(coach.router, prefix="/api/coach", tags=["coach"])

@app.get("/")
async def root():
    return {"name": "Chess Coach API", "version": "1.0.0",
            "docs": "/docs", "health": "/api/system/health"}
PYEOF

cat > backend/app/routers/__init__.py << 'PYEOF'
"""API routers."""
PYEOF

cat > backend/app/routers/system.py << 'PYEOF'
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
PYEOF

cat > backend/app/routers/engine.py << 'PYEOF'
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
PYEOF

cat > backend/app/routers/review.py << 'PYEOF'
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
PYEOF

cat > backend/app/routers/coach.py << 'PYEOF'
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
PYEOF

echo ""
echo "✓ bootstrap-01 done. Created:"
find backend -name '*.py' | sort
echo ""
echo "Next: bootstrap-02.sh (engine.py)"
