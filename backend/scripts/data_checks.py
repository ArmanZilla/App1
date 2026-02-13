"""
KozAlma AI — Dataset Analysis / Data Mining Script.

Performs:
  1. Class distribution histogram
  2. Bounding box size statistics
  3. Corrupted / unreadable image detection
  4. Near-duplicate detection via perceptual hash
  5. Generates plots to output/

Usage:
    python data_checks.py --data ../../data/data.yaml
"""

from __future__ import annotations

import argparse
import os
import sys
from collections import Counter, defaultdict
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import yaml
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

OUTPUT_DIR = Path(__file__).parent / "output"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="KozAlma dataset analysis")
    parser.add_argument("--data", type=str, default="../../data/data.yaml",
                        help="Path to data.yaml")
    return parser.parse_args()


def load_config(data_path: str) -> dict:
    """Load YOLO data.yaml."""
    with open(data_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def find_label_files(images_dir: Path) -> list[Path]:
    """Find corresponding label files for an images directory."""
    labels_dir = images_dir.parent.parent / "labels" / images_dir.parent.name
    if not labels_dir.exists():
        # Try sibling
        labels_dir = images_dir.parent / "labels"
    if not labels_dir.exists():
        return []
    return sorted(labels_dir.glob("*.txt"))


def analyze_class_distribution(config: dict, base_path: Path) -> Counter:
    """Count class occurrences across all splits."""
    names = config.get("names", [])
    counter: Counter = Counter()

    for split in ["train", "val", "test"]:
        split_path = config.get(split)
        if not split_path:
            continue
        images_dir = (base_path / split_path).resolve()
        labels_dir = images_dir.parent.parent / images_dir.parent.name
        # Try YOLO standard layout: images/ -> labels/
        labels_dir = Path(str(images_dir).replace("/images", "/labels").replace("\\images", "\\labels"))

        if not labels_dir.exists():
            print(f"  ⚠ Labels dir not found: {labels_dir}")
            continue

        for lbl_file in labels_dir.glob("*.txt"):
            with open(lbl_file, "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if parts:
                        cls_id = int(parts[0])
                        cls_name = names[cls_id] if cls_id < len(names) else f"class_{cls_id}"
                        counter[cls_name] += 1

    return counter


def analyze_bbox_sizes(config: dict, base_path: Path) -> dict:
    """Compute bbox width/height statistics."""
    widths, heights, areas = [], [], []

    for split in ["train", "val", "test"]:
        split_path = config.get(split)
        if not split_path:
            continue
        images_dir = (base_path / split_path).resolve()
        labels_dir = Path(str(images_dir).replace("/images", "/labels").replace("\\images", "\\labels"))

        if not labels_dir.exists():
            continue

        for lbl_file in labels_dir.glob("*.txt"):
            with open(lbl_file, "r") as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 5:
                        w, h = float(parts[3]), float(parts[4])
                        widths.append(w)
                        heights.append(h)
                        areas.append(w * h)

    return {
        "count": len(widths),
        "widths": np.array(widths),
        "heights": np.array(heights),
        "areas": np.array(areas),
    }


def check_corrupted(config: dict, base_path: Path) -> list[str]:
    """Find corrupted / unreadable images."""
    corrupted = []

    for split in ["train", "val", "test"]:
        split_path = config.get(split)
        if not split_path:
            continue
        images_dir = (base_path / split_path).resolve()
        if not images_dir.exists():
            continue

        for img_path in images_dir.iterdir():
            if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                continue
            try:
                img = Image.open(img_path)
                img.verify()
            except Exception:
                corrupted.append(str(img_path))

    return corrupted


def find_duplicates(config: dict, base_path: Path) -> list[tuple[str, str]]:
    """Find near-duplicate images using perceptual hash."""
    try:
        import imagehash
    except ImportError:
        print("  ⚠ imagehash not installed — skipping duplicate check")
        return []

    hashes: dict[str, str] = {}
    duplicates: list[tuple[str, str]] = []

    for split in ["train", "val", "test"]:
        split_path = config.get(split)
        if not split_path:
            continue
        images_dir = (base_path / split_path).resolve()
        if not images_dir.exists():
            continue

        for img_path in images_dir.iterdir():
            if img_path.suffix.lower() not in (".jpg", ".jpeg", ".png", ".bmp", ".webp"):
                continue
            try:
                h = str(imagehash.phash(Image.open(img_path)))
                if h in hashes:
                    duplicates.append((hashes[h], str(img_path)))
                else:
                    hashes[h] = str(img_path)
            except Exception:
                pass

    return duplicates


def plot_class_distribution(counter: Counter) -> None:
    """Save class distribution histogram."""
    if not counter:
        return
    classes = sorted(counter.keys())
    counts = [counter[c] for c in classes]

    fig, ax = plt.subplots(figsize=(14, 6))
    bars = ax.barh(classes, counts, color="#6c63ff")
    ax.set_xlabel("Count")
    ax.set_title("Class Distribution")
    ax.invert_yaxis()
    for bar, count in zip(bars, counts):
        ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height() / 2,
                str(count), va="center", fontsize=8)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "class_distribution.png", dpi=150)
    plt.close()
    print(f"  📊 Saved class_distribution.png")


def plot_bbox_stats(stats: dict) -> None:
    """Save bbox size distribution plots."""
    if stats["count"] == 0:
        return

    fig, axes = plt.subplots(1, 3, figsize=(15, 4))

    axes[0].hist(stats["widths"], bins=50, color="#6c63ff", alpha=0.8)
    axes[0].set_title("BBox Widths (normalized)")
    axes[0].set_xlabel("Width")

    axes[1].hist(stats["heights"], bins=50, color="#ff6384", alpha=0.8)
    axes[1].set_title("BBox Heights (normalized)")
    axes[1].set_xlabel("Height")

    axes[2].hist(stats["areas"], bins=50, color="#36a2eb", alpha=0.8)
    axes[2].set_title("BBox Areas (normalized)")
    axes[2].set_xlabel("Area")

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / "bbox_stats.png", dpi=150)
    plt.close()
    print(f"  📊 Saved bbox_stats.png")


def main() -> None:
    args = parse_args()
    data_path = Path(args.data).resolve()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    print("🔍 KozAlma AI Dataset Analysis")
    print("=" * 50)

    config = load_config(str(data_path))
    base_path = (data_path.parent / config.get("path", ".")).resolve()
    names = config.get("names", [])

    print(f"\n📁 Dataset base: {base_path}")
    print(f"   Classes: {len(names)}")
    print(f"   Names: {names[:5]}... ({len(names)} total)")

    # 1. Class distribution
    print("\n1️⃣  Class Distribution")
    class_counts = analyze_class_distribution(config, base_path)
    total_annotations = sum(class_counts.values())
    print(f"   Total annotations: {total_annotations}")
    for cls, cnt in class_counts.most_common(5):
        print(f"   {cls}: {cnt}")
    plot_class_distribution(class_counts)

    # 2. BBox stats
    print("\n2️⃣  Bounding Box Statistics")
    bbox_stats = analyze_bbox_sizes(config, base_path)
    if bbox_stats["count"] > 0:
        print(f"   Total bboxes: {bbox_stats['count']}")
        print(f"   Avg width:  {bbox_stats['widths'].mean():.4f}")
        print(f"   Avg height: {bbox_stats['heights'].mean():.4f}")
        print(f"   Avg area:   {bbox_stats['areas'].mean():.4f}")
        plot_bbox_stats(bbox_stats)
    else:
        print("   No bounding boxes found")

    # 3. Corrupted images
    print("\n3️⃣  Corrupted Image Check")
    corrupted = check_corrupted(config, base_path)
    if corrupted:
        print(f"   ⚠ Found {len(corrupted)} corrupted images:")
        for c in corrupted[:10]:
            print(f"     - {c}")
    else:
        print("   ✅ No corrupted images found")

    # 4. Duplicates
    print("\n4️⃣  Near-Duplicate Detection")
    duplicates = find_duplicates(config, base_path)
    if duplicates:
        print(f"   ⚠ Found {len(duplicates)} potential duplicates:")
        for a, b in duplicates[:10]:
            print(f"     - {Path(a).name} ↔ {Path(b).name}")
    else:
        print("   ✅ No duplicates found")

    print("\n" + "=" * 50)
    print("✅ Analysis complete! Plots saved to:", OUTPUT_DIR)


if __name__ == "__main__":
    main()
