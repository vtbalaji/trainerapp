#!/usr/bin/env python3
"""Train Indian food classifier using MobileNetV3-Small with transfer learning."""

import os
import json
import time
from pathlib import Path

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision import datasets, transforms, models

DATA_DIR = Path(__file__).parent.parent / "data" / "processed"
RESULTS_DIR = Path(__file__).parent.parent / "results"
MODEL_DIR = Path(__file__).parent.parent

DEVICE = (
    torch.device("mps") if torch.backends.mps.is_available()
    else torch.device("cuda") if torch.cuda.is_available()
    else torch.device("cpu")
)

# Hyperparameters
BATCH_SIZE = 32
NUM_EPOCHS = 30
LEARNING_RATE = 0.001
PATIENCE = 5  # early stopping
IMAGE_SIZE = 224
NUM_WORKERS = 4


def get_transforms():
    train_transform = transforms.Compose([
        transforms.RandomResizedCrop(IMAGE_SIZE, scale=(0.8, 1.0)),
        transforms.RandomHorizontalFlip(),
        transforms.RandomRotation(15),
        transforms.ColorJitter(brightness=0.2, contrast=0.2, saturation=0.2, hue=0.05),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    val_transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    return train_transform, val_transform


def build_model(num_classes):
    model = models.mobilenet_v3_small(weights=models.MobileNet_V3_Small_Weights.DEFAULT)

    # Freeze base layers initially
    for param in model.features.parameters():
        param.requires_grad = False

    # Replace classifier head
    in_features = model.classifier[0].in_features
    model.classifier = nn.Sequential(
        nn.Linear(in_features, 1024),
        nn.Hardswish(),
        nn.Dropout(0.2),
        nn.Linear(1024, num_classes),
    )

    return model


def train_one_epoch(model, loader, criterion, optimizer, device):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0

    for images, labels in loader:
        images, labels = images.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(images)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()

        running_loss += loss.item() * images.size(0)
        _, predicted = outputs.max(1)
        total += labels.size(0)
        correct += predicted.eq(labels).sum().item()

    return running_loss / total, correct / total


def evaluate(model, loader, criterion, device):
    model.eval()
    running_loss = 0.0
    correct = 0
    total = 0
    top3_correct = 0

    with torch.no_grad():
        for images, labels in loader:
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)

            running_loss += loss.item() * images.size(0)
            _, predicted = outputs.max(1)
            total += labels.size(0)
            correct += predicted.eq(labels).sum().item()

            # Top-3 accuracy
            _, top3_pred = outputs.topk(3, dim=1)
            for i in range(labels.size(0)):
                if labels[i] in top3_pred[i]:
                    top3_correct += 1

    return running_loss / total, correct / total, top3_correct / total


def main():
    os.makedirs(RESULTS_DIR, exist_ok=True)

    train_transform, val_transform = get_transforms()

    # Load datasets — skip empty class folders
    print(f"Loading data from {DATA_DIR}...")
    train_dataset = datasets.ImageFolder(DATA_DIR / "train", transform=train_transform)
    val_dataset = datasets.ImageFolder(DATA_DIR / "val", transform=val_transform)

    if len(train_dataset) == 0:
        print("ERROR: No training images found. Run download_data.py first.")
        return

    num_classes = len(train_dataset.classes)
    class_names = train_dataset.classes

    print(f"Classes: {num_classes}")
    print(f"Training images: {len(train_dataset)}")
    print(f"Validation images: {len(val_dataset)}")
    print(f"Device: {DEVICE}")

    # Check class distribution
    class_counts = {}
    for _, label in train_dataset:
        name = class_names[label]
        class_counts[name] = class_counts.get(name, 0) + 1

    min_count = min(class_counts.values())
    max_count = max(class_counts.values())
    print(f"Class distribution: min={min_count}, max={max_count}")

    # Weighted sampler for imbalanced classes
    sample_weights = []
    for _, label in train_dataset:
        name = class_names[label]
        sample_weights.append(1.0 / class_counts[name])
    sampler = torch.utils.data.WeightedRandomSampler(sample_weights, len(sample_weights))

    train_loader = DataLoader(
        train_dataset, batch_size=BATCH_SIZE, sampler=sampler,
        num_workers=NUM_WORKERS, pin_memory=True
    )
    val_loader = DataLoader(
        val_dataset, batch_size=BATCH_SIZE, shuffle=False,
        num_workers=NUM_WORKERS, pin_memory=True
    )

    # Build model
    model = build_model(num_classes).to(DEVICE)

    criterion = nn.CrossEntropyLoss()
    optimizer = optim.Adam(model.classifier.parameters(), lr=LEARNING_RATE)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=NUM_EPOCHS)

    # Training loop
    best_val_acc = 0.0
    patience_counter = 0
    history = {"train_loss": [], "val_loss": [], "train_acc": [], "val_acc": [], "val_top3": []}

    print("\n--- Phase 1: Train classifier head (base frozen) ---")
    unfreeze_epoch = 5

    for epoch in range(NUM_EPOCHS):
        # Unfreeze base layers after warmup
        if epoch == unfreeze_epoch:
            print("\n--- Phase 2: Fine-tune all layers ---")
            for param in model.features.parameters():
                param.requires_grad = True
            # Reset optimizer with lower LR for base layers
            optimizer = optim.Adam([
                {"params": model.features.parameters(), "lr": LEARNING_RATE * 0.1},
                {"params": model.classifier.parameters(), "lr": LEARNING_RATE},
            ])
            scheduler = optim.lr_scheduler.CosineAnnealingLR(
                optimizer, T_max=NUM_EPOCHS - unfreeze_epoch
            )

        start = time.time()
        train_loss, train_acc = train_one_epoch(model, train_loader, criterion, optimizer, DEVICE)
        val_loss, val_acc, val_top3 = evaluate(model, val_loader, criterion, DEVICE)
        scheduler.step()
        elapsed = time.time() - start

        history["train_loss"].append(train_loss)
        history["val_loss"].append(val_loss)
        history["train_acc"].append(train_acc)
        history["val_acc"].append(val_acc)
        history["val_top3"].append(val_top3)

        lr = optimizer.param_groups[0]["lr"]
        print(
            f"Epoch {epoch+1:2d}/{NUM_EPOCHS} | "
            f"Train Loss: {train_loss:.4f} Acc: {train_acc:.1%} | "
            f"Val Loss: {val_loss:.4f} Acc: {val_acc:.1%} Top3: {val_top3:.1%} | "
            f"LR: {lr:.6f} | {elapsed:.1f}s"
        )

        # Save best model
        if val_acc > best_val_acc:
            best_val_acc = val_acc
            patience_counter = 0
            torch.save({
                "epoch": epoch,
                "model_state_dict": model.state_dict(),
                "optimizer_state_dict": optimizer.state_dict(),
                "val_acc": val_acc,
                "val_top3": val_top3,
                "class_names": class_names,
                "num_classes": num_classes,
            }, RESULTS_DIR / "best_model.pth")
            print(f"  ✓ New best model saved (val_acc={val_acc:.1%})")
        else:
            patience_counter += 1
            if patience_counter >= PATIENCE and epoch >= unfreeze_epoch:
                print(f"  Early stopping after {patience_counter} epochs without improvement")
                break

    # Save training history
    with open(RESULTS_DIR / "history.json", "w") as f:
        json.dump(history, f, indent=2)

    # Save class names mapping
    with open(RESULTS_DIR / "class_names.json", "w") as f:
        json.dump(class_names, f, indent=2)

    print(f"\nBest validation accuracy: {best_val_acc:.1%}")
    print(f"Model saved to {RESULTS_DIR / 'best_model.pth'}")
    print(f"Run evaluate.py for detailed test metrics, then export_coreml.py to convert.")


if __name__ == "__main__":
    main()
