"""
KozAlma AI — Text-to-Speech Engine (Dispatcher).

Dispatches synthesis to the appropriate backend:
  - Russian (ru) → gTTS (Google Translate TTS)  → base64 MP3
  - Kazakh (kz)  → KazakhTTSEngine (Piper TTS)  → base64 WAV

Fallback strategy:
  If the Kazakh Piper engine is not loaded or synthesis fails,
  the engine automatically falls back to gTTS with the 'kk' locale.

Returns base64-encoded audio string in all cases.

NOTE: The public interface (synthesize method signature and return type)
is identical to the previous version — no callers need to change.
"""

from __future__ import annotations

import base64
import io
import logging
from typing import TYPE_CHECKING, Optional

from gtts import gTTS

if TYPE_CHECKING:
    from app.tts.kazakh_tts_engine import KazakhTTSEngine

logger = logging.getLogger(__name__)

# gTTS language codes
_LANG_MAP = {
    "ru": "ru",
    "kz": "kk",  # Kazakh ISO 639-1
}


class TTSEngine:
    """Generate speech audio from text.

    Supports two language backends:
      • "ru" — always uses gTTS (MP3)
      • "kz" — uses KazakhTTSEngine (Piper, WAV) if available, gTTS otherwise

    The engine is instantiated once at app startup and stored in
    ``app.state.tts_engine``.  No per-request model loading occurs.
    """

    def __init__(self, kz_engine: Optional[KazakhTTSEngine] = None):
        """Initialize the TTS dispatcher.

        Args:
            kz_engine: A pre-loaded KazakhTTSEngine instance.
                       Pass ``None`` to disable Piper Kazakh TTS
                       and use gTTS for all languages.
        """
        self._kz_engine = kz_engine

        if kz_engine is not None:
            logger.info("TTSEngine: Kazakh Piper backend enabled")
        else:
            logger.info("TTSEngine: gTTS only (Kazakh Piper backend not loaded)")

    # ── Public API (unchanged signature) ───────────────────────────────

    def synthesize(
        self,
        text: str,
        lang: str = "ru",
        speed: float = 1.0,
    ) -> Optional[str]:
        """Convert text to speech and return base64-encoded audio.

        Args:
            text: Text to speak.
            lang: Language code ("ru" or "kz").
            speed: Speech speed multiplier (gTTS: slow=True when <0.8).

        Returns:
            Base64-encoded audio string, or ``None`` on failure.
        """
        # ── Kazakh path: Piper TTS engine ────────────────────────────
        if lang == "kz" and self._kz_engine is not None:
            try:
                audio_bytes = self._kz_engine.synthesize(text, speed=speed)
                if audio_bytes:
                    audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
                    logger.info(
                        "TTS: synthesized %d chars via Kazakh Piper engine",
                        len(text),
                    )
                    return audio_b64

                # synthesize() returned None → fall through to gTTS
                logger.warning(
                    "Kazakh Piper returned empty audio — falling back to gTTS"
                )
            except Exception as exc:
                logger.error(
                    "Kazakh Piper TTS error: %s — falling back to gTTS", exc
                )

        # ── Default path: gTTS (Russian, or Kazakh fallback) ─────────
        return self._gtts_synthesize(text, lang, speed)

    # ── Private: gTTS backend ──────────────────────────────────────────

    def _gtts_synthesize(
        self,
        text: str,
        lang: str = "ru",
        speed: float = 1.0,
    ) -> Optional[str]:
        """Synthesize using Google TTS.  Returns base64-encoded MP3."""
        gtts_lang = _LANG_MAP.get(lang, "ru")
        slow = speed < 0.8

        try:
            tts = gTTS(text=text, lang=gtts_lang, slow=slow)
            buf = io.BytesIO()
            tts.write_to_fp(buf)
            buf.seek(0)
            audio_b64 = base64.b64encode(buf.read()).decode("utf-8")
            logger.info(
                "TTS: synthesized %d chars via gTTS (lang=%s)",
                len(text), gtts_lang,
            )
            return audio_b64
        except Exception as exc:
            logger.error("gTTS synthesis failed: %s", exc)
            return None
