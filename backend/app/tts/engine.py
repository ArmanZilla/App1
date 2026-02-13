"""
KozAlma AI — Text-to-Speech Engine.

Uses gTTS for Russian; Kazakh falls back to gTTS with 'kk' locale.
Returns base64-encoded MP3 audio.
"""

from __future__ import annotations

import base64
import io
import logging
from typing import Optional

from gtts import gTTS

logger = logging.getLogger(__name__)

# gTTS language codes
_LANG_MAP = {
    "ru": "ru",
    "kz": "kk",  # Kazakh ISO 639-1
}


class TTSEngine:
    """Generate speech audio from text."""

    def synthesize(
        self,
        text: str,
        lang: str = "ru",
        speed: float = 1.0,
    ) -> Optional[str]:
        """
        Convert text to speech and return base64-encoded MP3.

        Args:
            text: Text to speak.
            lang: Language code ("ru" or "kz").
            speed: Speech speed multiplier (gTTS supports slow=True).

        Returns:
            Base64-encoded MP3 string, or None on failure.
        """
        gtts_lang = _LANG_MAP.get(lang, "ru")
        slow = speed < 0.8

        try:
            tts = gTTS(text=text, lang=gtts_lang, slow=slow)
            buf = io.BytesIO()
            tts.write_to_fp(buf)
            buf.seek(0)
            audio_b64 = base64.b64encode(buf.read()).decode("utf-8")
            logger.info("TTS synthesized %d chars (lang=%s)", len(text), lang)
            return audio_b64
        except Exception as exc:
            logger.error("TTS synthesis failed: %s", exc)
            return None
