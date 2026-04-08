"""
KozAlma AI — TTS Speak Route.

Minimal endpoint for UI speech synthesis.
Reuses the existing TTSEngine (Piper for Kazakh, gTTS for Russian).

Used by Flutter Web for Kazakh UI speech, since browser
speechSynthesis lacks quality kk-KZ voices.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/tts", tags=["tts"])


class SpeakRequest(BaseModel):
    text: str
    lang: str = "kz"
    speed: float = 1.0


@router.post("/speak")
async def speak(req: SpeakRequest, request: Request):
    """Synthesize text to speech and return base64 audio."""
    tts_engine = request.app.state.tts_engine

    audio_b64 = tts_engine.synthesize(
        text=req.text,
        lang=req.lang,
        speed=req.speed,
    )

    if audio_b64 is None:
        return {"audio_base64": None, "error": "synthesis_failed"}

    return {"audio_base64": audio_b64}
