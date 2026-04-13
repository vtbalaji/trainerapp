#!/usr/bin/env python3
"""Organize FoodSight-100 into our processed directory with normalized class names."""

import os
import json
import shutil
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / "data"
RAW_DIR = DATA_DIR / "raw" / "foodsight_dataset" / "dataset"
PROCESSED_DIR = DATA_DIR / "processed"

# Map FoodSight-100 class names → our canonical underscore names
# All 100 classes included — even non-Indian ones help the model distinguish
CLASS_MAP = {
    "Aloo Gobi": "aloo_gobi",
    "Aloo Mutter": "aloo_mutter",
    "Aloo Paratha": "aloo_paratha",
    "Amritsari Kulcha": "amritsari_kulcha",
    "Appam": "appam",
    "Aviyal": "avial",
    "Balushahi": "balushahi",
    "Bhindi Masala": "bhindi_masala",
    "Biryani": "biryani",
    "Bisi Bele Bath": "bisibelebath",
    "Burger": "burger",
    "Butter Naan": "butter_naan",
    "Chaas": "buttermilk",
    "Chai": "tea",
    "Chana Masala": "chole",
    "Chapati": "chapati",
    "Chicken 65": "chicken_65",
    "Chicken Chettinad": "chicken_chettinad",
    "Chicken Wings": "chicken_wings",
    "Chilli Chicken": "chilli_chicken",
    "Chivda": "mixture",
    "Chole Bhature": "chole_bhature",
    "Curd Rice": "curd_rice",
    "Dabeli": "dabeli",
    "Dal Khichdi": "dal_khichdi",
    "Dal Makhani": "dal",
    "Dhokla": "dhokla",
    "Egg Curry": "egg_curry",
    "Falooda": "falooda",
    "Fish Curry": "fish_curry",
    "Fish Fry": "fish_fry",
    "Fried Rice": "fried_rice",
    "Gajar Ka Halwa": "halwa",
    "Garlic Bread": "garlic_bread",
    "Garlic Naan": "naan",
    "Ghevar": "ghevar",
    "Grilled Sandwich": "sandwich",
    "Gujhia": "gujhia",
    "Gulab Jamun": "gulab_jamun",
    "Hara Bhara Kebab": "hara_bhara_kebab",
    "Idiyappam": "idiyappam",
    "Idli": "idli",
    "Jalebi": "jalebi",
    "Kaathi Rolls": "kaathi_rolls",
    "Kadai Paneer": "paneer",
    "Kaju Katli": "kaju_katli",
    "Karimeen Pollichathu": "fish_curry",  # Kerala fish curry variant
    "Kerala Fish Curry": "fish_curry",
    "Kheer": "payasam",
    "Kothu Parotta": "parotta",
    "Kulfi": "kulfi",
    "Laddu": "ladoo",
    "Lemon Rice": "lemon_rice",
    "Litti Chokha": "litti_chokha",
    "Macher Jhol": "fish_curry",
    "Manchurian": "manchurian",
    "Masala Dosa": "masala_dosa",
    "Masala Papad": "masala_papad",
    "Medu Vada": "vada",
    "Methi Thepla": "methi_thepla",
    "Misal Pav": "misal_pav",
    "Modak": "modak",
    "Momos": "momos",
    "Moong Dal Halwa": "halwa",
    "Mysore Pak": "mysore_pak",
    "Navratan Korma": "navratan_korma",
    "Paani Puri": "pani_puri",
    "Pakora": "pakora",
    "Palak Paneer": "palak_paneer",
    "Paneer Masala": "paneer",
    "Paniyaram": "paniyaram",
    "Papdi Chaat": "papdi_chaat",
    "Pav Bhaji": "pav_bhaji",
    "Payasam": "payasam",
    "Phirni": "phirni",
    "Pizza": "pizza",
    "Poha": "poha",
    "Pongal": "pongal",
    "Puran Poli": "puran_poli",
    "Puri Bhaji": "poori",
    "Puttu": "puttu",
    "Rajma Chawal": "rajma",
    "Rasam": "rasam",
    "Rasgulla": "rasgulla",
    "Rava Dosa": "rava_dosa",
    "Sabudana Khichdi": "sabudana_khichdi",
    "Sabudana Vada": "sabudana_vada",
    "Sambar Rice": "sambar",
    "Samosa": "samosa",
    "Sandesh": "sandesh",
    "Seekh Kebab": "seekh_kebab",
    "Set Dosa": "set_dosa",
    "Sev Puri": "sev_puri",
    "Tamarind Rice": "tamarind_rice",
    "Thali": "thali",
    "Thukpa": "thukpa",
    "Unni Appam": "unni_appam",
    "Upma": "upma",
    "Uttapam": "uttapam",
    "Vada Pav": "vada_pav",
}

# GDQS mapping for each class (for reference/integration)
CLASS_TO_GDQS = {
    "aloo_gobi": "whiteRootsTubers",
    "aloo_mutter": "whiteRootsTubers",
    "aloo_paratha": "refinedGrains",
    "amritsari_kulcha": "refinedGrains",
    "appam": "refinedGrains",
    "avial": "otherVegetables",
    "balushahi": "sweetsIceCream",
    "bhindi_masala": "otherVegetables",
    "biryani": "refinedGrains",
    "bisibelebath": "legumes",
    "burger": "refinedGrains",
    "butter_naan": "refinedGrains",
    "buttermilk": "lowFatDairy",
    "tea": "other",
    "chole": "legumes",
    "chapati": "wholeGrains",
    "chicken_65": "poultryGameMeat",
    "chicken_chettinad": "poultryGameMeat",
    "chicken_wings": "poultryGameMeat",
    "chilli_chicken": "poultryGameMeat",
    "mixture": "purchasedDeepFried",
    "chole_bhature": "legumes",
    "curd_rice": "lowFatDairy",
    "dabeli": "refinedGrains",
    "dal_khichdi": "legumes",
    "dal": "legumes",
    "dhokla": "legumes",
    "egg_curry": "eggs",
    "falooda": "sweetsIceCream",
    "fish_curry": "fishShellfish",
    "fish_fry": "fishShellfish",
    "fried_rice": "refinedGrains",
    "halwa": "sweetsIceCream",
    "garlic_bread": "refinedGrains",
    "naan": "refinedGrains",
    "ghevar": "sweetsIceCream",
    "sandwich": "refinedGrains",
    "gujhia": "sweetsIceCream",
    "gulab_jamun": "sweetsIceCream",
    "hara_bhara_kebab": "otherVegetables",
    "idiyappam": "refinedGrains",
    "idli": "wholeGrains",
    "jalebi": "sweetsIceCream",
    "kaathi_rolls": "refinedGrains",
    "paneer": "highFatDairy",
    "kaju_katli": "sweetsIceCream",
    "payasam": "sweetsIceCream",
    "parotta": "refinedGrains",
    "kulfi": "sweetsIceCream",
    "ladoo": "sweetsIceCream",
    "lemon_rice": "refinedGrains",
    "litti_chokha": "wholeGrains",
    "manchurian": "purchasedDeepFried",
    "masala_dosa": "refinedGrains",
    "masala_papad": "purchasedDeepFried",
    "vada": "purchasedDeepFried",
    "methi_thepla": "wholeGrains",
    "misal_pav": "legumes",
    "modak": "sweetsIceCream",
    "momos": "refinedGrains",
    "mysore_pak": "sweetsIceCream",
    "navratan_korma": "otherVegetables",
    "pani_puri": "purchasedDeepFried",
    "pakora": "purchasedDeepFried",
    "palak_paneer": "highFatDairy",
    "paniyaram": "wholeGrains",
    "papdi_chaat": "purchasedDeepFried",
    "pav_bhaji": "refinedGrains",
    "phirni": "sweetsIceCream",
    "pizza": "refinedGrains",
    "poha": "refinedGrains",
    "pongal": "wholeGrains",
    "puran_poli": "sweetsIceCream",
    "poori": "refinedGrains",
    "puttu": "wholeGrains",
    "rajma": "legumes",
    "rasam": "otherVegetables",
    "rasgulla": "sweetsIceCream",
    "rava_dosa": "refinedGrains",
    "sabudana_khichdi": "whiteRootsTubers",
    "sabudana_vada": "purchasedDeepFried",
    "sambar": "legumes",
    "samosa": "purchasedDeepFried",
    "sandesh": "sweetsIceCream",
    "seekh_kebab": "redMeat",
    "set_dosa": "refinedGrains",
    "sev_puri": "purchasedDeepFried",
    "tamarind_rice": "refinedGrains",
    "thali": "other",
    "thukpa": "refinedGrains",
    "unni_appam": "sweetsIceCream",
    "upma": "refinedGrains",
    "uttapam": "wholeGrains",
    "vada_pav": "purchasedDeepFried",
}


def organize():
    if not RAW_DIR.exists():
        print(f"ERROR: Raw dataset not found at {RAW_DIR}")
        print("Run download_data.py first.")
        return

    # Clean previous processed data
    if PROCESSED_DIR.exists():
        shutil.rmtree(PROCESSED_DIR)

    stats = {"train": {}, "val": {}, "test": {}}
    split_map = {"train": "train", "validation": "val", "test": "test"}

    for src_split, dst_split in split_map.items():
        src_dir = RAW_DIR / src_split
        if not src_dir.exists():
            print(f"WARNING: {src_dir} not found, skipping")
            continue

        for class_dir in sorted(src_dir.iterdir()):
            if not class_dir.is_dir() or class_dir.name.startswith("."):
                continue

            canonical = CLASS_MAP.get(class_dir.name)
            if not canonical:
                print(f"  UNMAPPED: {class_dir.name}")
                continue

            dest_dir = PROCESSED_DIR / dst_split / canonical
            os.makedirs(dest_dir, exist_ok=True)

            images = [
                f for f in class_dir.iterdir()
                if f.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp")
            ]

            for img in images:
                # Avoid name collisions when multiple source classes merge
                dest = dest_dir / f"{class_dir.name.replace(' ', '_')}_{img.name}"
                if not dest.exists():
                    shutil.copy2(img, dest)

            count = len(list(dest_dir.glob("*")))
            stats[dst_split][canonical] = stats[dst_split].get(canonical, 0)
            stats[dst_split][canonical] = count

    # Report
    print("\n=== Dataset Summary ===\n")
    print(f"{'Class':<25} {'Train':>6} {'Val':>6} {'Test':>6} {'GDQS Group':<25}")
    print("-" * 75)

    total_train = 0
    total_val = 0
    total_test = 0

    for cls in sorted(set(CLASS_MAP.values())):
        tr = stats["train"].get(cls, 0)
        va = stats["val"].get(cls, 0)
        te = stats["test"].get(cls, 0)
        gdqs = CLASS_TO_GDQS.get(cls, "?")
        total_train += tr
        total_val += va
        total_test += te
        print(f"{cls:<25} {tr:>6} {va:>6} {te:>6} {gdqs:<25}")

    num_classes = len(set(CLASS_MAP.values()))
    print(f"\n{'TOTAL':<25} {total_train:>6} {total_val:>6} {total_test:>6}")
    print(f"Unique classes: {num_classes}")

    # Save metadata
    meta = {
        "num_classes": num_classes,
        "class_names": sorted(set(CLASS_MAP.values())),
        "class_to_gdqs": CLASS_TO_GDQS,
        "splits": stats,
    }
    with open(DATA_DIR / "splits.json", "w") as f:
        json.dump(meta, f, indent=2)

    print(f"\nMetadata saved to {DATA_DIR / 'splits.json'}")
    print("Ready for training — run: python3 training/train.py")


if __name__ == "__main__":
    organize()
