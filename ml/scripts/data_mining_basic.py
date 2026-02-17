"""Basic dataset analytics (data mining): class distribution, bbox sizes, examples.

- reads YOLO labels in `data/splits/train/labels`
- prints distributions
- saves simple plots (matplotlib)

Usage:
py data_mining_basic.py --data-root ../../data/splits/train
"""

import argparse
from pathlib import Path
import numpy as np
import matplotlib.pyplot as plt

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-root", type=str, default="../../data/splits/train")
    ap.add_argument("--out", type=str, default="../../data/analysis_outputs")
    args = ap.parse_args()

    root = Path(args.data_root).resolve()
    labels_dir = root / "labels"
    out_dir = Path(args.out).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    class_counts = {}
    bbox_wh = []

    for p in labels_dir.glob("*.txt"):
        for line in p.read_text(encoding="utf-8").strip().splitlines():
            parts = line.split()
            if len(parts) != 5:
                continue
            cls = int(parts[0])
            x, y, w, h = map(float, parts[1:])
            class_counts[cls] = class_counts.get(cls, 0) + 1
            bbox_wh.append((w, h))

    if not class_counts:
        print("No labels found. Check your path.")
        return

    # Bar plot of class counts
    keys = sorted(class_counts.keys())
    vals = [class_counts[k] for k in keys]
    plt.figure()
    plt.bar([str(k) for k in keys], vals)
    plt.title("Class distribution (train)")
    plt.xlabel("class_id")
    plt.ylabel("count")
    plt.tight_layout()
    plt.savefig(out_dir / "class_distribution_train.png", dpi=150)
    plt.close()

    bbox_wh = np.array(bbox_wh)
    plt.figure()
    plt.hist(bbox_wh[:,0], bins=30)
    plt.title("BBox width (normalized)")
    plt.tight_layout()
    plt.savefig(out_dir / "bbox_width_hist.png", dpi=150)
    plt.close()

    plt.figure()
    plt.hist(bbox_wh[:,1], bins=30)
    plt.title("BBox height (normalized)")
    plt.tight_layout()
    plt.savefig(out_dir / "bbox_height_hist.png", dpi=150)
    plt.close()

    print("Saved plots to:", out_dir)

if __name__ == "__main__":
    main()
