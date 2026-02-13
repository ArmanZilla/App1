"""
KozAlma AI — YOLOv8 Evaluation Script.

Evaluates a trained YOLOv8 model on the validation/test split.
Prints mAP, precision, recall.

Usage:
    python eval_yolo.py --weights runs/detect/koz_alma_train/weights/best.pt
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate YOLOv8 model")
    parser.add_argument("--weights", type=str, default="weights/best.pt",
                        help="Path to trained weights")
    parser.add_argument("--data", type=str, default="../../data/data.yaml",
                        help="Path to data.yaml")
    parser.add_argument("--imgsz", type=int, default=640,
                        help="Image size")
    parser.add_argument("--split", type=str, default="val",
                        choices=["val", "test"], help="Dataset split to evaluate")
    parser.add_argument("--device", type=str, default="",
                        help="Device")
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    from ultralytics import YOLO

    print(f"📦 Loading model: {args.weights}")
    model = YOLO(args.weights)

    print(f"📊 Evaluating on '{args.split}' split...")
    metrics = model.val(
        data=args.data,
        imgsz=args.imgsz,
        split=args.split,
        device=args.device if args.device else None,
        verbose=True,
    )

    print("\n" + "=" * 60)
    print("📈 Evaluation Results")
    print("=" * 60)
    print(f"  mAP@0.5       : {metrics.box.map50:.4f}")
    print(f"  mAP@0.5:0.95  : {metrics.box.map:.4f}")
    print(f"  Precision      : {metrics.box.mp:.4f}")
    print(f"  Recall         : {metrics.box.mr:.4f}")
    print("=" * 60)

    # Per-class metrics
    names = metrics.names
    if names and metrics.box.ap_class_index is not None:
        print("\n📋 Per-class AP@0.5:")
        for i, cls_idx in enumerate(metrics.box.ap_class_index):
            cls_name = names.get(int(cls_idx), f"class_{cls_idx}")
            ap50 = metrics.box.ap50[i]
            print(f"  {cls_name:25s}: {ap50:.4f}")


if __name__ == "__main__":
    main()
