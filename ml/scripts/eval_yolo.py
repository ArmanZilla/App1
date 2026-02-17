"""Evaluate YOLOv8 model on test split.

py eval_yolo.py --data configs/data.yaml --weights best.pt
"""

import argparse
from ultralytics import YOLO

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=str, required=True)
    ap.add_argument("--weights", type=str, required=True)
    args = ap.parse_args()

    model = YOLO(args.weights)
    metrics = model.val(data=args.data, split="test")
    print(metrics)

if __name__ == "__main__":
    main()
