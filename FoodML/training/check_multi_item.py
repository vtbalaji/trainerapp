#!/usr/bin/env python3
"""Check if FoodSight-100 images contain multiple food items or single items.
Sample a few images from various classes and analyze."""

import sys
from pathlib import Path

# Check the thali class — most likely to have multiple items
DATA_DIR = Path(__file__).parent.parent / "data" / "processed" / "train"

# Count images per class
print("Classes that likely contain multiple items:")
multi_item_classes = ["thali", "chole_bhature", "misal_pav", "pav_bhaji", "vada_pav",
                      "masala_dosa", "idli", "curd_rice", "biryani", "sambar"]

for cls in multi_item_classes:
    cls_dir = DATA_DIR / cls
    if cls_dir.exists():
        count = len(list(cls_dir.glob("*")))
        print(f"  {cls}: {count} images")

# Check thali specifically — these are combo plates
thali_dir = DATA_DIR / "thali"
if thali_dir.exists():
    imgs = list(thali_dir.glob("*"))
    print(f"\nThali images: {len(imgs)}")
    print("(Thali = full meal plate with multiple items)")
