"""
KozAlma AI — FastAPI Application Entry Point.

Loads ML models on startup, mounts static files, and includes all routers.
"""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.config import get_settings

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ML models and shared services on startup."""
    settings = get_settings()
    logger.info("Starting KozAlma AI backend...")

    # ── ML models ──
    from app.ml.detector import YOLODetector
    from app.ml.depth import DepthEstimator
    from app.ml.pipeline import ScanPipeline

    detector = YOLODetector(
        weights_path=settings.yolo_weights_path,
        confidence=settings.confidence_threshold,
    )
    depth_estimator = DepthEstimator(model_type=settings.midas_model)
    pipeline = ScanPipeline(
        detector=detector,
        depth_estimator=depth_estimator,
        unknown_threshold=settings.unknown_threshold,
    )

    # ── TTS ──
    from app.tts.engine import TTSEngine

    tts_engine = TTSEngine()

    # ── S3 / Unknown Manager ──
    unknown_manager = None
    if settings.s3_access_key:
        from app.storage.s3_client import S3Client
        from app.storage.unknown_manager import UnknownManager

        s3 = S3Client(
            access_key=settings.s3_access_key,
            secret_key=settings.s3_secret_key,
            bucket=settings.s3_bucket,
            endpoint=settings.s3_endpoint,
            region=settings.s3_region,
        )
        unknown_manager = UnknownManager(s3)
        logger.info("S3 unknown manager enabled")
    else:
        logger.warning("S3 credentials not set — unknown image storage disabled")

    # Store in app state for access in routes
    app.state.pipeline = pipeline
    app.state.tts_engine = tts_engine
    app.state.unknown_manager = unknown_manager

    logger.info("✅ KozAlma AI backend ready")
    yield

    logger.info("Shutting down KozAlma AI backend...")


def create_app() -> FastAPI:
    """Factory function to create the FastAPI application."""
    app = FastAPI(
        title="KozAlma AI",
        description="Visual assistant API for visually impaired users",
        version="1.0.0",
        lifespan=lifespan,
    )

    # ── Mount static files for admin panel ──
    static_dir = Path(__file__).parent / "admin_web" / "static"
    if static_dir.exists():
        app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

    # ── Include routers ──
    from app.api.routes.scan import router as scan_router
    from app.api.routes.unknown import router as unknown_router
    from app.admin_web.router import router as admin_router

    app.include_router(scan_router)
    app.include_router(unknown_router)
    app.include_router(admin_router)

    @app.get("/health")
    async def health():
        return {"status": "ok", "service": "koz-alma-ai"}

    return app


app = create_app()
