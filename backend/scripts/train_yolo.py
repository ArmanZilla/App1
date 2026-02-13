"""
KozAlma AI — YOLOv8 Training Script.

Trains a YOLOv8 model using the project's data.yaml config.
Saves best weights to runs/detect/train/weights/best.pt.

Usage:
    python train_yolo.py --epochs 100 --imgsz 640 --batch 16
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# Add backend to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train YOLOv8 on KozAlma dataset")
    parser.add_argument("--data", type=str, default="../../data/data.yaml",
                        help="Path to data.yaml")
    parser.add_argument("--model", type=str, default="yolov8n.pt",
                        help="Base model (e.g. yolov8n.pt, yolov8s.pt)")
    parser.add_argument("--epochs", type=int, default=100,
                        help="Number of training epochs")
    parser.add_argument("--imgsz", type=int, default=640,
                        help="Image size for training")
    parser.add_argument("--batch", type=int, default=16,
                        help="Batch size")
    parser.add_argument("--device", type=str, default="",
                        help="Device: '' (auto), 'cpu', '0', '0,1'")
    parser.add_argument("--name", type=str, default="koz_alma_train",
                        help="Run name")
    parser.add_argument("--patience", type=int, default=20,
                        help="Early stopping patience")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    from ultralytics import YOLO

    print(f"📦 Loading base model: {args.model}")
    model = YOLO(args.model)

    print(f"🚀 Starting training — {args.epochs} epochs, imgsz={args.imgsz}, batch={args.batch}")
    results = model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        device=args.device if args.device else None,
        name=args.name,
        patience=args.patience,
        save=True,
        plots=True,
        verbose=True,
    )

    # Print summary
    print("\n" + "=" * 60)
    print("✅ Training complete!")
    print(f"   Best weights: runs/detect/{args.name}/weights/best.pt")
    print(f"   Results dir:  runs/detect/{args.name}/")
    print("=" * 60)


if __name__ == "__main__":
    main()
