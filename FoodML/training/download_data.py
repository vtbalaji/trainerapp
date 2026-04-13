#!/usr/bin/env python3
"""Download and organize FoodSight-100 dataset for Indian food model training."""

import os
import sys
import shutil
import json
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
RAW_DIR = DATA_DIR / "raw"
PROCESSED_DIR = DATA_DIR / "processed"

# Classes we want from FoodSight-100 and their mapping to our canonical names
# FoodSight-100 class name → our class name
FOODSIGHT_CLASS_MAP = {
    # Direct Indian food matches
    "biryani": "biryani",
    "butter_chicken": "butter_chicken",
    "chai": "tea",
    "chapati": "chapati",
    "chole_bhature": "chole",
    "dal_makhani": "dal",
    "dhokla": "dhokla",
    "dosa": "dosa",
    "fried_rice": "fried_rice",
    "gulab_jamun": "gulab_jamun",
    "idli": "idli",
    "jalebi": "jalebi",
    "kadai_paneer": "paneer",
    "naan": "naan",
    "pakora": "pakora",
    "palak_paneer": "palak_paneer",
    "pani_puri": "pani_puri",
    "paneer_tikka": "paneer",
    "paratha": "paratha",
    "poha": "poha",
    "rasgulla": "rasgulla",
    "samosa": "samosa",
    "tandoori_chicken": "tandoori_chicken",
    "upma": "upma",
    "vada": "vada",
    # Generic food classes useful for our model
    "fried_egg": "omelette",
    "boiled_egg": "boiled_egg",
    "chicken_curry": "chicken_curry",
    "fish_curry": "fish_curry",
    "egg_curry": "egg_curry",
    "rice": "rice",
    "salad": "salad",
    "banana": "banana",
    "mango": "mango",
    "apple": "apple",
    "orange": "orange",
    "watermelon": "watermelon",
    "omelette": "omelette",
    "ice_cream": "ice_cream",
    "pizza": "pizza",
    "burger": "burger",
    "sandwich": "sandwich",
    "soup": "soup",
    "noodles": "noodles",
}

# Additional classes we need to collect manually (not in FoodSight-100)
MANUAL_CLASSES = [
    "uttapam", "rava_dosa", "masala_dosa", "pongal", "puttu", "appam",
    "idiyappam", "pesarattu", "paniyaram", "sambar", "rasam",
    "coconut_chutney", "poriyal", "avial", "kootu", "thoran",
    "curd_rice", "lemon_rice", "tamarind_rice", "bisibelebath",
    "murukku", "bonda", "bajji", "sundal", "banana_chips",
    "chicken_chettinad", "chicken_65", "fish_fry", "prawn_masala",
    "mutton_curry", "egg_roast", "payasam", "halwa", "ladoo",
    "kesari", "curd", "buttermilk", "lassi", "filter_coffee",
    "raita", "rajma", "aloo_gobi", "palak",
    "papaya", "pomegranate", "coconut", "guava",
    "ragi_dosa", "millet_dosa",
]


def download_foodsight():
    """Download FoodSight-100 from Kaggle."""
    kaggle_bin = os.path.expanduser("~/Library/Python/3.9/bin/kaggle")
    if not os.path.exists(kaggle_bin):
        kaggle_bin = "kaggle"

    # Check kaggle credentials
    kaggle_json = Path.home() / ".kaggle" / "kaggle.json"
    if not kaggle_json.exists():
        print("ERROR: Kaggle API credentials not found.")
        print("1. Go to https://www.kaggle.com/settings → API → Create New Token")
        print(f"2. Save the downloaded kaggle.json to {kaggle_json}")
        print("3. Run: chmod 600 ~/.kaggle/kaggle.json")
        print("4. Re-run this script")
        sys.exit(1)

    print("Downloading FoodSight-100 dataset...")
    os.makedirs(RAW_DIR, exist_ok=True)
    ret = os.system(
        f'{kaggle_bin} datasets download -d maestros231/foodsight-100-dataset '
        f'-p "{RAW_DIR}" --unzip'
    )
    if ret != 0:
        print("ERROR: Kaggle download failed. Check credentials and dataset name.")
        sys.exit(1)
    print("Download complete.")


def organize_classes():
    """Organize downloaded images into our class structure."""
    # Find the extracted folder
    foodsight_dir = None
    for item in RAW_DIR.iterdir():
        if item.is_dir():
            foodsight_dir = item
            break

    if not foodsight_dir:
        # Images might be directly in raw/
        # Look for class folders
        subdirs = [d for d in RAW_DIR.iterdir() if d.is_dir() and not d.name.startswith('.')]
        if subdirs:
            foodsight_dir = RAW_DIR
        else:
            print("ERROR: Could not find extracted dataset. Contents of raw/:")
            for item in RAW_DIR.iterdir():
                print(f"  {item.name}")
            sys.exit(1)

    print(f"Found dataset at: {foodsight_dir}")
    print(f"Available classes: {sorted([d.name for d in foodsight_dir.iterdir() if d.is_dir()])}")

    os.makedirs(PROCESSED_DIR, exist_ok=True)

    # Create train/val/test splits
    for split in ["train", "val", "test"]:
        os.makedirs(PROCESSED_DIR / split, exist_ok=True)

    mapped = 0
    skipped = 0

    for src_class_dir in sorted(foodsight_dir.iterdir()):
        if not src_class_dir.is_dir() or src_class_dir.name.startswith('.'):
            continue

        src_name = src_class_dir.name.lower().replace(" ", "_").replace("-", "_")

        # Check if this class maps to one of ours
        target_name = FOODSIGHT_CLASS_MAP.get(src_name)
        if not target_name:
            # Try fuzzy match
            for key in FOODSIGHT_CLASS_MAP:
                if key in src_name or src_name in key:
                    target_name = FOODSIGHT_CLASS_MAP[key]
                    break

        if not target_name:
            skipped += 1
            continue

        # Collect all images
        images = sorted([
            f for f in src_class_dir.rglob("*")
            if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")
        ])

        if not images:
            continue

        # Split 70/15/15
        n = len(images)
        n_train = int(n * 0.70)
        n_val = int(n * 0.15)

        splits = {
            "train": images[:n_train],
            "val": images[n_train:n_train + n_val],
            "test": images[n_train + n_val:],
        }

        for split, split_images in splits.items():
            dest_dir = PROCESSED_DIR / split / target_name
            os.makedirs(dest_dir, exist_ok=True)
            for img_path in split_images:
                dest = dest_dir / img_path.name
                if not dest.exists():
                    shutil.copy2(img_path, dest)

        mapped += 1
        print(f"  {src_name} → {target_name}: {n} images")

    print(f"\nMapped {mapped} classes, skipped {skipped}")

    # Create placeholder dirs for manual classes
    for cls in MANUAL_CLASSES:
        for split in ["train", "val", "test"]:
            os.makedirs(PROCESSED_DIR / split / cls, exist_ok=True)

    # Report
    print("\n--- Dataset Summary ---")
    train_dir = PROCESSED_DIR / "train"
    total = 0
    empty = []
    for cls_dir in sorted(train_dir.iterdir()):
        if cls_dir.is_dir():
            count = len(list(cls_dir.glob("*")))
            total += count
            if count == 0:
                empty.append(cls_dir.name)
            else:
                print(f"  {cls_dir.name}: {count} training images")

    print(f"\nTotal training images: {total}")
    if empty:
        print(f"\nEmpty classes (need manual collection): {len(empty)}")
        for name in empty:
            print(f"  - {name}")

    # Save split info
    splits_info = {}
    for split in ["train", "val", "test"]:
        split_dir = PROCESSED_DIR / split
        splits_info[split] = {}
        for cls_dir in sorted(split_dir.iterdir()):
            if cls_dir.is_dir():
                splits_info[split][cls_dir.name] = len(list(cls_dir.glob("*")))

    with open(DATA_DIR / "splits.json", "w") as f:
        json.dump(splits_info, f, indent=2)
    print(f"\nSplit info saved to {DATA_DIR / 'splits.json'}")


if __name__ == "__main__":
    download_foodsight()
    organize_classes()
