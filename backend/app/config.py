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
