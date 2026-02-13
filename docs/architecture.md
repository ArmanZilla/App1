# KozAlma AI — Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────┐
│                    Flutter Mobile App                     │
│  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌───────────┐ │
│  │ Welcome  │  │  Camera   │  │ Result  │  │ Settings  │ │
│  │ Screen   │→ │  Screen   │→ │ Screen  │  │  Screen   │ │
│  └─────────┘  └────┬─────┘  └─────────┘  └───────────┘ │
│                     │ image                               │
│              ┌──────┴──────┐                              │
│              │ API Service │                              │
│              └──────┬──────┘                              │
└─────────────────────┼────────────────────────────────────┘
                      │ POST /scan
┌─────────────────────┼────────────────────────────────────┐
│                FastAPI Backend                            │
│              ┌──────┴──────┐                              │
│              │  Scan Route  │                             │
│              └──────┬──────┘                              │
│         ┌───────────┼───────────┐                         │
│   ┌─────┴────┐ ┌────┴────┐ ┌───┴───┐                    │
│   │  YOLOv8  │ │  MiDaS  │ │  TTS  │                    │
│   │ Detector │ │  Depth  │ │Engine │                     │
│   └──────────┘ └─────────┘ └───────┘                     │
│         │                                                 │
│   ┌─────┴──────────┐                                     │
│   │  S3 Unknown    │  ← low-confidence images            │
│   │  Manager       │  → Yandex Object Storage            │
│   └────────────────┘                                     │
│         │                                                 │
│   ┌─────┴──────────┐                                     │
│   │  Admin Panel   │  ← view/download unknowns           │
│   │  (Jinja2)      │                                     │
│   └────────────────┘                                     │
└──────────────────────────────────────────────────────────┘
```

## ML Pipeline

1. **YOLOv8** — Object detection with custom 39-class weights
2. **MiDaS** — Monocular depth estimation (relative depth)
3. **Calibration** — Convert depth values to approximate meters: `distance ≈ SCALE / (depth + ε)`
4. **Text Builder** — Position (left/center/right) + distance in RU/KZ
5. **gTTS** — Generate speech audio (MP3, base64)

## Active Learning Loop

```
Camera → Low confidence? → Store to S3 → Admin reviews → Label → Retrain
```

## Data Flow

- Images grouped by `YYYY-MM-DD/session_id/` in S3
- Each image stored with `_meta.json` (timestamp, detection count)
- Admin downloads ZIP → labels in annotation tool → adds to training data
