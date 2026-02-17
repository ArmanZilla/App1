"""Split YOLO-format dataset into train/val/test: 80/10/10.

Expected input:
- data/annotated/images/*.jpg|png
- data/annotated/labels/*.txt  (same basename)

Output:
- data/splits/{train,val,test}/{images,labels}/...

Usage:
python split_dataset.py --data-root ../../data --seed 42
"""

import argparse, random, shutil
from pathlib import Path

IMG_EXT = {".jpg",".jpeg",".png",".webp"}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-root", type=str, default="../../data")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--train", type=float, default=0.8)
    ap.add_argument("--val", type=float, default=0.1)
    ap.add_argument("--test", type=float, default=0.1)
    args = ap.parse_args()

    random.seed(args.seed)

    root = Path(args.data_root).resolve()
    src_img = root / "annotated" / "images"
    src_lbl = root / "annotated" / "labels"
    out = root / "splits"

    imgs = [p for p in src_img.iterdir() if p.suffix.lower() in IMG_EXT]
    imgs.sort()
    random.shuffle(imgs)

    n = len(imgs)
    n_train = int(n * args.train)
    n_val = int(n * args.val)
    train_set = imgs[:n_train]
    val_set = imgs[n_train:n_train+n_val]
    test_set = imgs[n_train+n_val:]

    def copy_set(items, split):
        (out / split / "images").mkdir(parents=True, exist_ok=True)
        (out / split / "labels").mkdir(parents=True, exist_ok=True)
        for img in items:
            lbl = src_lbl / (img.stem + ".txt")
            if not lbl.exists():
                continue
            shutil.copy2(img, out / split / "images" / img.name)
            shutil.copy2(lbl, out / split / "labels" / lbl.name)

    if out.exists():
        # keep old, but you may want to delete manually
        pass

    copy_set(train_set, "train")
    copy_set(val_set, "val")
    copy_set(test_set, "test")

    print(f"Total: {n} | train={len(train_set)} val={len(val_set)} test={len(test_set)}")
    print(f"Output: {out}")

if __name__ == "__main__":
    main()
