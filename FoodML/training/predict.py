#!/usr/bin/env python3
"""Run inference on a single image using the trained model."""

import sys
import json
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import models, transforms
from PIL import Image

RESULTS_DIR = Path(__file__).parent.parent / "results"
IMAGE_SIZE = 224

DEVICE = (
    torch.device("mps") if torch.backends.mps.is_available()
    else torch.device("cpu")
)


def main():
    if len(sys.argv) < 2:
        print("Usage: python predict.py <image_path>")
        sys.exit(1)

    image_path = sys.argv[1]

    # Load model
    checkpoint = torch.load(RESULTS_DIR / "best_model.pth", map_location=DEVICE, weights_only=False)
    class_names = checkpoint["class_names"]
    num_classes = checkpoint["num_classes"]

    model = models.mobilenet_v3_small(weights=None)
    in_features = model.classifier[0].in_features
    model.classifier = nn.Sequential(
        nn.Linear(in_features, 1024),
        nn.Hardswish(),
        nn.Dropout(0.2),
        nn.Linear(1024, num_classes),
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.to(DEVICE)
    model.eval()

    # Preprocess image
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(IMAGE_SIZE),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    img = Image.open(image_path).convert("RGB")
    tensor = transform(img).unsqueeze(0).to(DEVICE)

    # Predict
    with torch.no_grad():
        outputs = model(tensor)
        probs = torch.softmax(outputs, dim=1)[0]
        top5_probs, top5_indices = probs.topk(5)

    print(f"\nPredictions for: {image_path}\n")
    print(f"{'Rank':<6} {'Class':<25} {'Confidence':>10}")
    print("-" * 45)
    for i in range(5):
        cls = class_names[top5_indices[i].item()]
        conf = top5_probs[i].item()
        print(f"  {i+1:<4} {cls:<25} {conf:>9.1%}")


if __name__ == "__main__":
    main()
