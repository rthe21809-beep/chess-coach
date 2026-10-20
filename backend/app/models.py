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
