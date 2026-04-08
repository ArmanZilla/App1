"""
KozAlma AI — Kazakh TTS Test Script.

Verifies that:
  1. Number normalization works correctly
  2. gTTS synthesizes MP3 audio (Russian)
  3. KazakhTTSEngine (Piper TTS) synthesizes REAL WAV audio (Kazakh)
  4. TTSEngine dispatcher routes correctly + fallback works
  5. Base64 roundtrip is valid for both languages

Usage:
    cd backend
    python tests/test_kz_tts.py

Requirements:
    pip install piper-tts==1.3.0
    Download Kazakh model from https://huggingface.co/rhasspy/piper-voices
"""

from __future__ import annotations

import base64
import os
import sys
import wave
from io import BytesIO

# Ensure the backend package is importable
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

# Default model paths (relative to backend/)
_DEFAULT_MODEL = os.environ.get(
    "KZ_TTS_MODEL_PATH", "models/kk_KZ-issai-high.onnx"
)
_DEFAULT_CONFIG = os.environ.get(
    "KZ_TTS_CONFIG_PATH", "models/kk_KZ-issai-high.onnx.json"
)

# Minimum acceptable WAV size to treat as real audio.
# 44 bytes is only WAV header; real speech should be much larger.
_MIN_WAV_BYTES = 1000


def _validate_wav_bytes(wav_bytes: bytes) -> tuple[bool, str]:
    """Validate that WAV bytes represent real audio, not just a header."""
    if not wav_bytes:
        return False, "empty bytes"

    if len(wav_bytes) <= _MIN_WAV_BYTES:
        return False, f"suspiciously small WAV: {len(wav_bytes)} bytes"

    if wav_bytes[:4] != b"RIFF":
        return False, "missing RIFF header"

    try:
        with wave.open(BytesIO(wav_bytes), "rb") as wf:
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            framerate = wf.getframerate()
            n_frames = wf.getnframes()
            duration = n_frames / float(framerate) if framerate else 0.0

        if n_frames <= 0:
            return False, "WAV contains zero frames"

        if duration <= 0:
            return False, "WAV duration is zero"

        return True, (
            f"valid WAV: {len(wav_bytes)} bytes, "
            f"{n_channels} ch, {sampwidth * 8}-bit, "
            f"{framerate} Hz, {duration:.2f}s"
        )
    except Exception as exc:
        return False, f"invalid WAV parse: {exc}"


def test_kz_number_normalization():
    """Test Kazakh number-to-words conversion."""
    from app.tts.kazakh_tts_engine import normalize_kz_text, _number_to_kz_words

    print("=" * 60)
    print("TEST 1: Kazakh Number Normalization")
    print("=" * 60)

    cases = [
        (0, "нөл"),
        (1, "бір"),
        (10, "он"),
        (15, "он бес"),
        (23, "жиырма үш"),
        (100, "жүз"),
        (256, "екі жүз елу алты"),
        (1000, "мың"),
        (1500, "мың бес жүз"),
    ]

    all_pass = True
    for num, expected in cases:
        result = _number_to_kz_words(num)
        status = "✅" if result == expected else "❌"
        if result != expected:
            all_pass = False
        print(f"  {status} {num} → '{result}' (expected '{expected}')")

    text_cases = [
        ("1.5 метр", "бір бүтін бес метр"),
        ("Шамамен 3 метр", "Шамамен үш метр"),
    ]

    for text_in, expected in text_cases:
        result = normalize_kz_text(text_in)
        status = "✅" if result == expected else "❌"
        if result != expected:
            all_pass = False
        print(f"  {status} '{text_in}' → '{result}' (expected '{expected}')")

    print(f"\n  {'ALL PASSED' if all_pass else 'SOME FAILED'}\n")
    return all_pass


def test_gtts_russian():
    """Test gTTS Russian synthesis (existing behavior)."""
    from app.tts.engine import TTSEngine

    print("=" * 60)
    print("TEST 2: gTTS Russian Synthesis")
    print("=" * 60)

    engine = TTSEngine(kz_engine=None)
    text = "Обнаружено: человек слева, примерно 2 метра от вас."

    audio_b64 = engine.synthesize(text, lang="ru", speed=1.0)

    if not audio_b64:
        print("  ❌ Russian TTS returned None (gTTS may need internet)")
        return False

    try:
        audio_bytes = base64.b64decode(audio_b64)
    except Exception as exc:
        print(f"  ❌ Russian TTS base64 decode failed: {exc}")
        return False

    if len(audio_bytes) < 1000:
        print(f"  ❌ Russian MP3 too small: {len(audio_bytes)} bytes")
        return False

    print(f"  ✅ Russian TTS: {len(audio_bytes)} bytes (base64: {len(audio_b64)} chars)")

    sample_path = os.path.join(os.path.dirname(__file__), "sample_ru.mp3")
    with open(sample_path, "wb") as f:
        f.write(audio_bytes)
    print(f"  ✅ Saved to: {sample_path}")
    return True


def test_kazakh_piper_tts():
    """Test Piper TTS Kazakh synthesis."""
    print("=" * 60)
    print("TEST 3: Piper TTS Kazakh Synthesis")
    print("=" * 60)

    try:
        from app.tts.kazakh_tts_engine import KazakhTTSEngine

        engine = KazakhTTSEngine(
            model_path=_DEFAULT_MODEL,
            config_path=_DEFAULT_CONFIG,
        )

        text = "Сол жақта шамамен бір бүтін бес метр жерде адам бар."
        print(f"  ⏳ Synthesizing: '{text}'")

        wav_bytes = engine.synthesize(text, speed=1.0)

        if not wav_bytes:
            print("  ❌ Kazakh TTS returned None")
            return False

        ok, message = _validate_wav_bytes(wav_bytes)
        if not ok:
            print(f"  ❌ Kazakh TTS invalid WAV: {message}")
            return False

        audio_b64 = base64.b64encode(wav_bytes).decode("utf-8")
        print(f"  ✅ Kazakh TTS: {len(wav_bytes)} bytes WAV (base64: {len(audio_b64)} chars)")
        print(f"  ✅ {message}")

        sample_path = os.path.join(os.path.dirname(__file__), "sample_kz.wav")
        with open(sample_path, "wb") as f:
            f.write(wav_bytes)
        print(f"  ✅ Saved to: {sample_path}")
        return True

    except ImportError as exc:
        print(f"  ⚠️  piper-tts not installed: {exc}")
        print("  ℹ️  Install with: pip install piper-tts==1.3.0")
        return False
    except FileNotFoundError as exc:
        print(f"  ⚠️  Model files not found: {exc}")
        print("  ℹ️  Download from: https://huggingface.co/rhasspy/piper-voices")
        return False
    except Exception as exc:
        print(f"  ❌ Kazakh TTS failed: {exc}")
        return False


def test_dispatcher_fallback():
    """Test TTSEngine dispatcher with fallback behavior."""
    from app.tts.engine import TTSEngine

    print("=" * 60)
    print("TEST 4: TTSEngine Dispatcher + Fallback")
    print("=" * 60)

    all_pass = True

    # Test 1: No Kazakh engine → should fall back to gTTS
    engine_no_kz = TTSEngine(kz_engine=None)
    audio = engine_no_kz.synthesize("Сәлеметсіз бе", lang="kz", speed=1.0)
    if audio:
        print("  ✅ Fallback to gTTS for lang='kz' when no KZ engine: OK")
    else:
        print("  ⚠️  gTTS fallback returned None (may need internet)")

    # Test 2: Russian always uses gTTS
    audio_ru = engine_no_kz.synthesize("Привет", lang="ru", speed=1.0)
    if audio_ru:
        print("  ✅ Russian via gTTS: OK")
    else:
        print("  ⚠️  Russian gTTS returned None (may need internet)")

    # Test 3: With Kazakh engine (Piper TTS)
    try:
        from app.tts.kazakh_tts_engine import KazakhTTSEngine

        kz = KazakhTTSEngine(
            model_path=_DEFAULT_MODEL,
            config_path=_DEFAULT_CONFIG,
        )
        engine_with_kz = TTSEngine(kz_engine=kz)

        audio_kz = engine_with_kz.synthesize("Сәлеметсіз бе", lang="kz", speed=1.0)
        if not audio_kz:
            print("  ❌ Dispatcher with KZ engine returned None")
            all_pass = False
        else:
            decoded = base64.b64decode(audio_kz)
            ok, message = _validate_wav_bytes(decoded)
            if not ok:
                print(f"  ❌ Kazakh via Piper dispatcher invalid WAV: {message}")
                all_pass = False
            else:
                print(f"  ✅ Kazakh via Piper dispatcher: {len(decoded)} bytes WAV")
                print(f"  ✅ {message}")

        # Russian must still use gTTS
        audio_ru2 = engine_with_kz.synthesize("Привет", lang="ru", speed=1.0)
        if audio_ru2:
            print("  ✅ Russian still routes to gTTS (not Piper): OK")
        else:
            print("  ⚠️  Russian gTTS returned None (may need internet)")

    except (ImportError, FileNotFoundError) as exc:
        print(f"  ⚠️  Skipping dispatcher+KZ test: {exc}")

    return all_pass


def test_base64_validity():
    """Verify both KZ (WAV via Piper) and RU (MP3 via gTTS) produce valid base64."""
    from app.tts.engine import TTSEngine

    print("=" * 60)
    print("TEST 5: Base64 Output Validity")
    print("=" * 60)

    all_pass = True
    engine = TTSEngine(kz_engine=None)

    # Russian (MP3 via gTTS)
    audio_ru = engine.synthesize("Тест", lang="ru")
    if audio_ru:
        try:
            decoded = base64.b64decode(audio_ru)
            re_encoded = base64.b64encode(decoded).decode("utf-8")
            roundtrip_ok = re_encoded == audio_ru
            print(f"  ✅ Russian MP3 base64 roundtrip: {roundtrip_ok} ({len(decoded)} bytes)")
        except Exception as exc:
            print(f"  ❌ Russian base64 decode failed: {exc}")
            all_pass = False
    else:
        print("  ⚠️  Skipped RU (gTTS needs internet)")

    # Kazakh (WAV via Piper)
    try:
        from app.tts.kazakh_tts_engine import KazakhTTSEngine

        kz = KazakhTTSEngine(
            model_path=_DEFAULT_MODEL,
            config_path=_DEFAULT_CONFIG,
        )
        engine_kz = TTSEngine(kz_engine=kz)
        audio_kz = engine_kz.synthesize("Тест", lang="kz")
        if not audio_kz:
            print("  ❌ Skipped KZ (Piper returned None)")
            all_pass = False
        else:
            try:
                decoded = base64.b64decode(audio_kz)
                ok, message = _validate_wav_bytes(decoded)
                if not ok:
                    print(f"  ❌ Kazakh WAV invalid after base64 decode: {message}")
                    all_pass = False
                else:
                    re_encoded = base64.b64encode(decoded).decode("utf-8")
                    roundtrip_ok = re_encoded == audio_kz
                    print(f"  ✅ Kazakh WAV base64 roundtrip: {roundtrip_ok} ({len(decoded)} bytes)")
                    print(f"  ✅ {message}")
            except Exception as exc:
                print(f"  ❌ Kazakh base64 decode failed: {exc}")
                all_pass = False
    except (ImportError, FileNotFoundError) as exc:
        print(f"  ⚠️  Skipped KZ: {exc}")

    return all_pass


if __name__ == "__main__":
    print("\n🔊 KozAlma AI — Kazakh TTS Integration Tests (Piper TTS)\n")

    results = {}
    results["normalization"] = test_kz_number_normalization()
    results["gtts_ru"] = test_gtts_russian()
    results["piper_tts_kz"] = test_kazakh_piper_tts()
    results["dispatcher"] = test_dispatcher_fallback()
    results["base64"] = test_base64_validity()

    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    for name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        print(f"  {status}  {name}")

    all_ok = all(results.values())
    print(f"\n{'✅ All tests passed!' if all_ok else '⚠️  Some tests failed.'}\n")
    sys.exit(0 if all_ok else 1)