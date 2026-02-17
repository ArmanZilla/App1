"""Calibrate MiDaS depth values to meters.

You collect N photos (e.g. 50) at known distances and create CSV:
filename,distance_m

Then we compute depth_value (median MiDaS depth inside YOLO bbox) and fit:
distance_m = depth_value * scale + shift

Saves to: backend/app/assets/calibration.json

Usage:
python backend/ml/scripts/calibrate_depth.py --images data/calib_images --csv data/calib.csv --weights yolov8n.pt

Tip:
Do calibration on the SAME Android device camera for best results.
"""

import argparse, json
from pathlib import Path
import numpy as np
import pandas as pd
import cv2
from ultralytics import YOLO
import torch

def midas_load(model_type="MiDaS_small"):
    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = torch.hub.load("intel-isl/MiDaS", model_type).to(device).eval()
    transforms = torch.hub.load("intel-isl/MiDaS", "transforms")
    transform = transforms.small_transform if model_type not in ["DPT_Large","DPT_Hybrid"] else transforms.dpt_transform
    return model, transform, device

@torch.inference_mode()
def midas_predict(model, transform, device, bgr):
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    inp = transform(rgb).to(device)
    pred = model(inp)
    pred = torch.nn.functional.interpolate(pred.unsqueeze(1), size=rgb.shape[:2], mode="bicubic", align_corners=False).squeeze()
    return pred.detach().cpu().numpy().astype(np.float32)

def bbox_depth(depth, bbox):
    x1,y1,x2,y2 = bbox
    h,w = depth.shape
    x1 = max(0,min(w-1,int(x1))); x2 = max(0,min(w,int(x2)))
    y1 = max(0,min(h-1,int(y1))); y2 = max(0,min(h,int(y2)))
    patch = depth[y1:y2, x1:x2]
    if patch.size == 0:
        return float(np.median(depth))
    return float(np.median(patch))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", required=True)
    ap.add_argument("--csv", required=True)
    ap.add_argument("--weights", default="yolov8n.pt")
    ap.add_argument("--class_name", default=None)
    ap.add_argument("--out", default="backend/app/assets/calibration.json")
    args = ap.parse_args()

    img_dir = Path(args.images).resolve()
    df = pd.read_csv(args.csv)

    yolo = YOLO(args.weights)
    midas, tfm, device = midas_load()

    xs, ys = [], []

    for _, row in df.iterrows():
        fn = str(row["filename"])
        dist = float(row["distance_m"])
        p = img_dir / fn
        if not p.exists():
            print("Missing:", p)
            continue
        bgr = cv2.imread(str(p))
        if bgr is None:
            continue

        depth = midas_predict(midas, tfm, device, bgr)

        res = yolo.predict(source=bgr, verbose=False)[0]
        bbox = None

        if res.boxes is not None and len(res.boxes) > 0:
            candidates = []
            for box in res.boxes:
                cls = int(box.cls[0]); conf = float(box.conf[0])
                name = res.names.get(cls, str(cls))
                if args.class_name and name != args.class_name:
                    continue
                x1,y1,x2,y2 = [float(v) for v in box.xyxy[0].tolist()]
                candidates.append((conf, [x1,y1,x2,y2]))
            if candidates:
                candidates.sort(key=lambda x: x[0], reverse=True)
                bbox = candidates[0][1]

        if bbox is None:
            h,w = depth.shape
            cx,cy = w//2, h//2
            bw,bh = int(w*0.3), int(h*0.3)
            bbox = [cx-bw//2, cy-bh//2, cx+bw//2, cy+bh//2]

        dv = bbox_depth(depth, bbox)
        xs.append(dv); ys.append(dist)

    xs = np.array(xs, dtype=np.float64)
    ys = np.array(ys, dtype=np.float64)

    if len(xs) < 5:
        raise SystemExit("Need at least 5 samples in CSV that exist on disk.")

    a, b = np.polyfit(xs, ys, deg=1)
    out = {
        "method": "linear",
        "scale": float(a),
        "shift": float(b),
        "samples": int(len(xs)),
        "notes": "distance_m = depth_value*scale + shift (depth_value=median MiDaS depth in bbox)"
    }

    out_path = Path(args.out).resolve()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print("Saved:", out_path)
    print(out)

if __name__ == "__main__":
    main()
