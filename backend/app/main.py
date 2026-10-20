"""FastAPI entrypoint."""
from __future__ import annotations
import logging
import warnings
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .config import settings
from .engine import engines
from .routers import coach, engine, review, system

logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO),
                    format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger("chess_coach")
warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")

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
