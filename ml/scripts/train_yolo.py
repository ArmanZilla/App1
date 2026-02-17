"""YOLOv8 training script (Ultralytics).

1) Prepare splits:
python split_dataset.py --data-root ../../data

2) Update configs/data.yaml.template -> configs/data.yaml

3) Train:
python train_yolo.py --data configs/data.yaml --model yolov8n.pt --epochs 50 --imgsz 640 --batch 8

Outputs:
- backend/runs/detect/train*/weights/best.pt
"""

import argparse
from ultralytics import YOLO

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", type=str, required=True)
    ap.add_argument("--model", type=str, default="yolov8n.pt")
    ap.add_argument("--epochs", type=int, default=50)
    ap.add_argument("--imgsz", type=int, default=640)
    ap.add_argument("--batch", type=int, default=8)
    ap.add_argument("--project", type=str, default="../runs")
    ap.add_argument("--name", type=str, default="detect")
    args = ap.parse_args()

    model = YOLO(args.model)
    model.train(
        data=args.data,
        epochs=args.epochs,
        imgsz=args.imgsz,
        batch=args.batch,
        project=args.project,
        name=args.name,
    )

if __name__ == "__main__":
    main()
