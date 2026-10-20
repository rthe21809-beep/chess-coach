"""Environment-backed settings (stdlib only)."""
from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None


def _load_env() -> None:
    if load_dotenv is None:
        return
    here = Path(__file__).resolve().parent
    for candidate in (here.parent / ".env", here.parent.parent / ".env"):
        if candidate.is_file():
            load_dotenv(candidate, override=False)
            break


_load_env()


def _str(name: str, default: str = "") -> str:
    return (os.environ.get(name) or default).strip()


def _bool(name: str, default: bool = False) -> bool:
    raw = (os.environ.get(name) or "").strip().lower()
    if not raw:
        return default
    return raw in {"1", "true", "yes", "on"}


def _float(name: str, default: float) -> float:
    raw = (os.environ.get(name) or "").strip()
    if not raw:
        return default
    try:
        return float(raw)
    except ValueError:
        return default


@dataclass(frozen=True)
class Settings:
    stockfish_path: str
    lc0_path: str
    maia_weights_dir: str
    lc0_backend: str
    groq_api_key: str
    groq_base_url: str
    groq_default_model: str
    enable_cloud_fallback: bool
    request_timeout_s: float
    log_level: str


settings = Settings(
    stockfish_path=_str("STOCKFISH_PATH"),
    lc0_path=_str("LC0_PATH"),
    maia_weights_dir=_str("MAIA_WEIGHTS_DIR"),
    lc0_backend=_str("LC0_BACKEND", "eigen") or "eigen",
    groq_api_key=_str("GROQ_API_KEY"),
    groq_base_url=_str("GROQ_BASE_URL", "https://api.groq.com/openai/v1")
    or "https://api.groq.com/openai/v1",
    groq_default_model=_str("GROQ_DEFAULT_MODEL", "openai/gpt-oss-120b")
    or "openai/gpt-oss-120b",
    enable_cloud_fallback=_bool("ENABLE_CLOUD_FALLBACK", True),
    request_timeout_s=_float("REQUEST_TIMEOUT_S", 90.0),
    log_level=_str("LOG_LEVEL", "INFO") or "INFO",
)
