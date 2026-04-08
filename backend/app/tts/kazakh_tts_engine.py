"""
KozAlma AI — Kazakh Text-to-Speech Engine (Piper TTS).

Uses Piper TTS for offline Kazakh speech synthesis.
Model is loaded once at startup — no per-request loading.

Design decisions:
  - Uses piper-tts with a local ONNX model (CPU-only by default).
  - Returns WAV bytes (16-bit mono PCM wrapped in WAV header).
  - Numbers are expanded to Kazakh words before synthesis.
  - All errors are caught and logged — None is returned on failure
    so the caller (TTSEngine) can fall back to gTTS.
"""

from __future__ import annotations

import io
import logging
import re
import wave
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


# ═══════════════════════════════════════════════════════════════════════
# Kazakh number-to-words conversion
# ═══════════════════════════════════════════════════════════════════════

_KZ_ONES = {
    0: "нөл",
    1: "бір",
    2: "екі",
    3: "үш",
    4: "төрт",
    5: "бес",
    6: "алты",
    7: "жеті",
    8: "сегіз",
    9: "тоғыз",
}

_KZ_TEENS = {
    10: "он",
    11: "он бір",
    12: "он екі",
    13: "он үш",
    14: "он төрт",
    15: "он бес",
    16: "он алты",
    17: "он жеті",
    18: "он сегіз",
    19: "он тоғыз",
}

_KZ_TENS = {
    20: "жиырма",
    30: "отыз",
    40: "қырық",
    50: "елу",
    60: "алпыс",
    70: "жетпіс",
    80: "сексен",
    90: "тоқсан",
}

_KZ_HUNDREDS = "жүз"
_KZ_THOUSANDS = "мың"


def _number_to_kz_words(n: int) -> str:
    """Convert an integer (0–9999) to Kazakh words."""
    if n < 0:
        return "минус " + _number_to_kz_words(-n)

    if n in _KZ_ONES:
        return _KZ_ONES[n]

    if n in _KZ_TEENS:
        return _KZ_TEENS[n]

    if n < 100:
        tens = (n // 10) * 10
        ones = n % 10
        if ones == 0:
            return _KZ_TENS[tens]
        return f"{_KZ_TENS[tens]} {_KZ_ONES[ones]}"

    if n < 1000:
        hundreds = n // 100
        remainder = n % 100
        prefix = f"{_KZ_ONES[hundreds]} {_KZ_HUNDREDS}" if hundreds > 1 else _KZ_HUNDREDS
        if remainder == 0:
            return prefix
        return f"{prefix} {_number_to_kz_words(remainder)}"

    if n < 10_000:
        thousands = n // 1000
        remainder = n % 1000
        prefix = f"{_KZ_ONES[thousands]} {_KZ_THOUSANDS}" if thousands > 1 else _KZ_THOUSANDS
        if remainder == 0:
            return prefix
        return f"{prefix} {_number_to_kz_words(remainder)}"

    return str(n)


# ═══════════════════════════════════════════════════════════════════════
# Text normalization for Kazakh TTS
# ═══════════════════════════════════════════════════════════════════════

def normalize_kz_text(text: str) -> str:
    """Normalize Kazakh text before TTS synthesis."""

    def _replace_decimal(match: re.Match) -> str:
        int_part = int(match.group(1))
        dec_part = int(match.group(2))
        return f"{_number_to_kz_words(int_part)} бүтін {_number_to_kz_words(dec_part)}"

    text = re.sub(r"(\d+)\.(\d+)", _replace_decimal, text)

    def _replace_int(match: re.Match) -> str:
        return _number_to_kz_words(int(match.group(0)))

    text = re.sub(r"\b\d+\b", _replace_int, text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


# ═══════════════════════════════════════════════════════════════════════
# Kazakh TTS Engine (Piper TTS)
# ═══════════════════════════════════════════════════════════════════════

class KazakhTTSEngine:
    """Piper TTS-based offline Kazakh speech engine."""

    def __init__(
        self,
        model_path: str,
        config_path: str,
        use_cuda: bool = False,
    ) -> None:
        mp = Path(model_path)
        cp = Path(config_path)

        if not mp.exists():
            raise FileNotFoundError(f"Piper model not found: {mp}")
        if not cp.exists():
            raise FileNotFoundError(f"Piper config not found: {cp}")

        from piper.voice import PiperVoice

        self._voice = PiperVoice.load(
            str(mp),
            config_path=str(cp),
            use_cuda=use_cuda,
        )

        # sample_rate берём из config, но если его нет — дефолт 22050
        self._sample_rate = int(getattr(self._voice.config, "sample_rate", 22050))

        logger.info(
            "✅ Kazakh TTS engine initialized (backend=piper, model=%s, sample_rate=%d, cuda=%s)",
            mp.name,
            self._sample_rate,
            use_cuda,
        )

    def synthesize(self, text: str, speed: float = 1.0) -> Optional[bytes]:
        """Synthesize Kazakh text to WAV bytes using Piper official WAV API."""
        if not text or not text.strip():
            logger.warning("Empty text passed to Kazakh TTS — skipping")
            return None

        try:
            normalized = normalize_kz_text(text)
            logger.debug("KZ TTS normalized: %s", normalized[:200])

            wav_buffer = io.BytesIO()

            # Official API path:
            # PiperVoice.synthesize_wav(text, wav_file)
            with wave.open(wav_buffer, "wb") as wav_file:
                self._voice.synthesize_wav(normalized, wav_file)

            wav_bytes = wav_buffer.getvalue()

            # 44 bytes = empty WAV header
            if len(wav_bytes) <= 1000:
                logger.error(
                    "Piper produced suspiciously small WAV (%d bytes). "
                    "This usually means synthesis failed or no phonemes were generated.",
                    len(wav_bytes),
                )
                return None

            logger.info(
                "KZ TTS synthesized %d chars → %d bytes WAV (speed=%.1f)",
                len(text),
                len(wav_bytes),
                speed,
            )
            return wav_bytes

        except Exception as exc:
            logger.error("Kazakh TTS synthesis failed: %s", exc, exc_info=True)
            return None