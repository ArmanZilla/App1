"""
KozAlma AI — API Pydantic Schemas.
"""

from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class DetectionItem(BaseModel):
    """Single detection in the scan response."""

    class_id: int
    class_name: str
    class_name_localized: str = Field("", description="Translated class name (RU/KZ)")
    confidence: float
    bbox: list[float] = Field(description="[x1, y1, x2, y2]")
    position: str = Field(description="left | center | right")
    distance_m: Optional[float] = Field(None, description="Approx distance in meters")


class ScanResponse(BaseModel):
    """Response from /scan endpoint."""

    lang: str = Field("ru", description="Response language: ru | kz")
    detections: List[DetectionItem]
    text: str
    audio_base64: Optional[str] = None
    is_unknown: bool = False


class UnknownGroupItem(BaseModel):
    """A group of unknown images."""

    group_id: str
    date: str
    image_count: int


class UnknownImageItem(BaseModel):
    """Single unknown image metadata."""

    key: str
    name: str
    size: int = 0
