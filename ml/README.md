# ML (training / evaluation / analysis)

Scripts:
- split_dataset.py — split YOLO dataset 80/10/10
- train_yolo.py — train YOLOv8
- eval_yolo.py — evaluate on test split
- data_mining_basic.py — basic analytics plots
- calibrate_depth.py — fit MiDaS depth -> meters

## Workflow
1) Put labeled data:
- data/annotated/images
- data/annotated/labels

2) Split:
python backend/ml/scripts/split_dataset.py --data-root data

3) Config:
copy backend/ml/configs/data.yaml.template -> backend/ml/configs/data.yaml and edit names.

4) Train:
python backend/ml/scripts/train_yolo.py --data backend/ml/configs/data.yaml --epochs 50 --imgsz 640 --batch 8

5) Connect weights:
Edit backend/app/ml/detector.py weights_path -> your best.pt

6) Calibrate:
Create data/calib_images + data/calib.csv then:
python backend/ml/scripts/calibrate_depth.py --images data/calib_images --csv data/calib.csv --weights yolov8n.pt
