"""
KozAlma AI — Bilingual Text Builder.

Builds fully localized detection descriptions in Russian (RU) and Kazakh (KZ).
Loads class name translations from assets/class_dict.json.
"""

from __future__ import annotations

import json
import logging
from pathlib import Path
from typing import Any, Dict, List

logger = logging.getLogger(__name__)

_ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets"

# ── Load class dictionary ──────────────────────────────────────────────
_class_dict: Dict[str, Dict[str, str]] = {}

def _load_class_dict() -> None:
    global _class_dict
    dict_path = _ASSETS_DIR / "class_dict.json"
    if dict_path.exists():
        with open(dict_path, encoding="utf-8") as f:
            _class_dict = json.load(f)
        logger.info("Loaded class_dict.json: %d languages", len(_class_dict))
    else:
        logger.warning("class_dict.json not found at %s", dict_path)

_load_class_dict()

# ── Phrase templates ───────────────────────────────────────────────────
_PHRASES = {
    "ru": {
        "detected": "Обнаружено:",
        "no_objects": "Объекты не обнаружены.",
        "approx": "примерно",
        "meter": "метр",
        "meters_2_4": "метра",
        "meters": "метров",
        "from_you": "от вас",
        "left": "слева",
        "center": "по центру",
        "right": "справа",
    },
    "kz": {
        "detected": "Табылды:",
        "no_objects": "Нысандар табылмады.",
        "approx": "шамамен",
        "meter": "метр",
        "meters_2_4": "метр",
        "meters": "метр",
        "at_place": "жерде",
        "exists": "бар",
        "left": "сол жақта",
        "center": "ортада",
        "right": "оң жақта",
    },
}


def _get_phrases(lang: str) -> Dict[str, str]:
    return _PHRASES.get(lang, _PHRASES["ru"])


# ── Public API ─────────────────────────────────────────────────────────

def localize_class_name(class_name: str, lang: str) -> str:
    """Translate a YOLO class name to the target language.

    Uses case-insensitive lookup. Falls back to original name if missing.
    """
    lang_dict = _class_dict.get(lang, {})
    key = class_name.lower().strip()
    localized = lang_dict.get(key)
    if localized is None:
        logger.debug("Translation missing: class='%s' lang='%s'", class_name, lang)
        return class_name
    return localized


def localize_position(position: str, lang: str) -> str:
    """Translate a position (left/center/right) to the target language."""
    p = _get_phrases(lang)
    return p.get(position, position)


def _meters_word(n: float, lang: str) -> str:
    """Return correct declension of 'meters' for RU/KZ."""
    p = _get_phrases(lang)
    if lang != "ru":
        return p["meters"]
    # In Russian, any decimal (e.g. 1.7, 3.2) always takes genitive singular
    if n != int(n):
        return p["meters_2_4"]
    n_int = int(abs(n))
    mod10 = n_int % 10
    mod100 = n_int % 100
    if mod10 == 1 and mod100 != 11:
        return p["meter"]
    if 2 <= mod10 <= 4 and not (12 <= mod100 <= 14):
        return p["meters_2_4"]
    return p["meters"]


def build_detection_text(
    detections: List[Dict[str, Any]],
    lang: str = "ru",
) -> str:
    """Build a fully localized text description from detection dicts.

    Each dict should have: class_name, position, distance_m (optional).
    Returns natural-sounding sentences:
      RU: "Обнаружено: человек слева, примерно 1.7 метра от вас."
      KZ: "Табылды: сол жақта шамамен 1.7 метр жерде адам бар."
    """
    p = _get_phrases(lang)

    if not detections:
        return p["no_objects"]

    parts: list[str] = [p["detected"]]

    for det in detections:
        name = localize_class_name(det["class_name"], lang)
        pos = localize_position(det["position"], lang)
        dist = det.get("distance_m")

        if lang == "kz":
            if dist is not None and dist > 0:
                word = _meters_word(dist, lang)
                # "Сол жақта шамамен 1.7 метр жерде адам бар."
                parts.append(
                    f"{pos} {p['approx']} {dist:.1f} {word} "
                    f"{p['at_place']} {name} {p['exists']}."
                )
            else:
                # "Сол жақта адам бар."
                parts.append(f"{pos} {name} {p['exists']}.")
        else:
            if dist is not None and dist > 0:
                word = _meters_word(dist, lang)
                # "Человек слева, примерно 1.7 метра от вас."
                parts.append(
                    f"{name} {pos}, {p['approx']} {dist:.1f} {word} "
                    f"{p['from_you']}."
                )
            else:
                # "Человек слева."
                parts.append(f"{name} {pos}.")

    return " ".join(parts)
