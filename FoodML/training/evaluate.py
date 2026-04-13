#!/usr/bin/env python3
"""Evaluate trained model on test set — per-class accuracy, confusion matrix, timing."""

import json
import time
from pathlib import Path
from collections import defaultdict

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms, models

DATA_DIR = Path(__file__).parent.parent / "data" / "processed"
RESULTS_DIR = Path(__file__).parent.parent / "results"

IMAGE_SIZE = 224
BATCH_SIZE = 32
NUM_WORKERS = 4

DEVICE = (
    torch.device("mps") if torch.backends.mps.is_available()
    else torch.device("cuda") if torch.cuda.is_available()
    else torch.device("cpu")
)

# Confusable pairs to specifically report
CONFUSABLE_PAIRS = [
    ("idli", "appam"), ("dosa", "uttapam"), ("chapati", "paratha"),
    ("sambar", "rasam"), ("gulab_jamun", "ladoo"), ("pongal", "upma"),
    ("curd", "raita"), ("biryani", "fried_rice"), ("rice", "biryani"),
    ("dosa", "masala_dosa"), ("boiled_egg", "omelette"),
]


def load_model(checkpoint_path, num_classes):
    model = models.mobilenet_v3_small(weights=None)
    in_features = model.classifier[0].in_features
    model.classifier = nn.Sequential(
        nn.Linear(in_features, 1024),
        nn.Hardswish(),
        nn.Dropout(0.2),
        nn.Linear(1024, num_classes),
    )
    checkpoint = torch.load(checkpoint_path, map_location=DEVICE, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(DEVICE)
    model.eval()
    return model, checkpoint["class_names"]


def main():
    checkpoint_path = RESULTS_DIR / "best_model.pth"
    if not checkpoint_path.exists():
        print("ERROR: No trained model found. Run train.py first.")
        return

    checkpoint = torch.load(checkpoint_path, map_location=DEVICE, weights_only=False)
    num_classes = checkpoint["num_classes"]
    class_names = checkpoint["class_names"]

    model, _ = load_model(checkpoint_path, num_classes)

    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    test_dataset = datasets.ImageFolder(DATA_DIR / "test", transform=val_transform)
    test_loader = DataLoader(
        test_dataset, batch_size=BATCH_SIZE, shuffle=False,
        num_workers=NUM_WORKERS, pin_memory=True
    )

    print(f"Test images: {len(test_dataset)}")
    print(f"Classes: {num_classes}")
    print(f"Device: {DEVICE}")

    # Per-class tracking
    class_correct = defaultdict(int)
    class_total = defaultdict(int)
    class_top3_correct = defaultdict(int)
    confusion = defaultdict(lambda: defaultdict(int))  # confusion[true][predicted]

    total_correct = 0
    total_top3 = 0
    total = 0

    # Inference timing
    inference_times = []

    with torch.no_grad():
        for images, labels in test_loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)

            start = time.time()
            outputs = model(images)
            elapsed = (time.time() - start) / images.size(0)  # per-image
            inference_times.append(elapsed)

            _, predicted = outputs.max(1)
            _, top3_pred = outputs.topk(min(3, num_classes), dim=1)

            for i in range(labels.size(0)):
                true_class = class_names[labels[i].item()]
                pred_class = class_names[predicted[i].item()]

                class_total[true_class] += 1
                total += 1

                confusion[true_class][pred_class] += 1

                if predicted[i] == labels[i]:
                    class_correct[true_class] += 1
                    total_correct += 1

                if labels[i] in top3_pred[i]:
                    class_top3_correct[true_class] += 1
                    total_top3 += 1

    # Overall metrics
    top1_acc = total_correct / total if total > 0 else 0
    top3_acc = total_top3 / total if total > 0 else 0
    avg_time_ms = sum(inference_times) / len(inference_times) * 1000

    print(f"\n{'='*60}")
    print(f"OVERALL RESULTS")
    print(f"{'='*60}")
    print(f"Top-1 Accuracy: {top1_acc:.1%}")
    print(f"Top-3 Accuracy: {top3_acc:.1%}")
    print(f"Avg inference:  {avg_time_ms:.1f}ms per image")

    # Per-class results
    print(f"\n{'='*60}")
    print(f"PER-CLASS ACCURACY")
    print(f"{'='*60}")
    print(f"{'Class':<25} {'Top-1':>8} {'Top-3':>8} {'Count':>6}")
    print("-" * 50)

    per_class = {}
    weak_classes = []
    for cls in sorted(class_names):
        t = class_total.get(cls, 0)
        if t == 0:
            continue
        acc1 = class_correct.get(cls, 0) / t
        acc3 = class_top3_correct.get(cls, 0) / t
        per_class[cls] = {"top1": acc1, "top3": acc3, "count": t}
        flag = " ⚠" if acc1 < 0.5 else ""
        print(f"{cls:<25} {acc1:>7.1%} {acc3:>7.1%} {t:>6}{flag}")
        if acc1 < 0.5:
            weak_classes.append(cls)

    # Confusable pairs
    print(f"\n{'='*60}")
    print(f"CONFUSABLE PAIRS")
    print(f"{'='*60}")
    for a, b in CONFUSABLE_PAIRS:
        if a not in class_total or b not in class_total:
            continue
        a_as_b = confusion[a].get(b, 0)
        b_as_a = confusion[b].get(a, 0)
        a_total = class_total[a]
        b_total = class_total[b]
        print(f"  {a} → {b}: {a_as_b}/{a_total} ({a_as_b/a_total:.0%})")
        print(f"  {b} → {a}: {b_as_a}/{b_total} ({b_as_a/b_total:.0%})")
        print()

    # Pass/fail criteria
    print(f"\n{'='*60}")
    print(f"PASS/FAIL CRITERIA")
    print(f"{'='*60}")

    checks = [
        ("Top-1 >= 70%", top1_acc >= 0.70),
        ("Top-3 >= 85%", top3_acc >= 0.85),
        ("All classes recall > 50%", len(weak_classes) == 0),
        ("Inference < 200ms", avg_time_ms < 200),
    ]

    all_pass = True
    for name, passed in checks:
        status = "PASS" if passed else "FAIL"
        if not passed:
            all_pass = False
        print(f"  [{status}] {name}")

    if weak_classes:
        print(f"\n  Weak classes (recall < 50%): {', '.join(weak_classes)}")

    print(f"\n  {'ALL CRITERIA MET — ready for CoreML export' if all_pass else 'NEEDS MORE WORK'}")

    # Save results
    results = {
        "top1_accuracy": top1_acc,
        "top3_accuracy": top3_acc,
        "avg_inference_ms": avg_time_ms,
        "per_class": per_class,
        "weak_classes": weak_classes,
        "all_criteria_met": all_pass,
        "confusable_pairs": {
            f"{a}_vs_{b}": {
                f"{a}_as_{b}": confusion[a].get(b, 0),
                f"{b}_as_{a}": confusion[b].get(a, 0),
            }
            for a, b in CONFUSABLE_PAIRS
            if a in class_total and b in class_total
        },
    }

    with open(RESULTS_DIR / "evaluation.json", "w") as f:
        json.dump(results, f, indent=2)

    # Save confusion matrix as CSV
    with open(RESULTS_DIR / "confusion_matrix.csv", "w") as f:
        classes_with_data = sorted([c for c in class_names if class_total.get(c, 0) > 0])
        f.write("," + ",".join(classes_with_data) + "\n")
        for true_cls in classes_with_data:
            row = [str(confusion[true_cls].get(pred_cls, 0)) for pred_cls in classes_with_data]
            f.write(true_cls + "," + ",".join(row) + "\n")

    print(f"\nResults saved to {RESULTS_DIR}/")


if __name__ == "__main__":
    main()
