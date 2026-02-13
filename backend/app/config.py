"""
KozAlma AI — Application Configuration.

Loads settings from .env via pydantic-settings.
"""

from __future__ import annotations

from pathlib import Path
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


_ROOT = Path(__file__).resolve().parent.parent  # backend/


class Settings(BaseSettings):
    """Global application settings populated from environment variables."""

    model_config = SettingsConfigDict(
        env_file=str(_ROOT / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # ── S3 / Yandex Object Storage ──────────────────────────────────────
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket: str = "koz-alma-unknown"
    s3_endpoint: str = "https://storage.yandexcloud.net"
    s3_region: str = "ru-central1"

    # ── Admin ───────────────────────────────────────────────────────────
    admin_username: str = "admin"
    admin_password: str = "changeme123"
    admin_session_secret: str = "super-secret-session-key"

    # ── ML Models ───────────────────────────────────────────────────────
    yolo_weights_path: str = "weights/best.pt"
    midas_model: str = "MiDaS_small"
    confidence_threshold: float = 0.35
    unknown_threshold: float = 0.30

    # ── TTS ─────────────────────────────────────────────────────────────
    tts_default_lang: str = "ru"
    tts_default_speed: float = 1.0

    # ── Server ──────────────────────────────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8000

    # ── Dataset ─────────────────────────────────────────────────────────
    data_yaml_path: str = str(_ROOT.parent / "data" / "data.yaml")


@lru_cache
def get_settings() -> Settings:
    """Return cached settings singleton."""
    return Settings()
