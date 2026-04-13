#!/usr/bin/env python3
"""Export trained PyTorch model to CoreML (.mlpackage) for on-device inference."""

import json
from pathlib import Path

import torch
import torch.nn as nn
from torchvision import models
import coremltools as ct

RESULTS_DIR = Path(__file__).parent.parent / "results"
MODEL_DIR = Path(__file__).parent.parent

IMAGE_SIZE = 224


def main():
    checkpoint_path = RESULTS_DIR / "best_model.pth"
    if not checkpoint_path.exists():
        print("ERROR: No trained model found. Run train.py first.")
        return

    print("Loading checkpoint...")
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
    class_names = checkpoint["class_names"]
    num_classes = checkpoint["num_classes"]

    # Rebuild model
    model = models.mobilenet_v3_small(weights=None)
    in_features = model.classifier[0].in_features
    model.classifier = nn.Sequential(
        nn.Linear(in_features, 1024),
        nn.Hardswish(),
        nn.Dropout(0.2),
        nn.Linear(1024, num_classes),
    )
    model.load_state_dict(checkpoint["model_state_dict"])
    model.eval()

    # Trace model
    print("Tracing model...")
    dummy_input = torch.randn(1, 3, IMAGE_SIZE, IMAGE_SIZE)
    traced = torch.jit.trace(model, dummy_input)

    # Convert to CoreML
    print("Converting to CoreML...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.ImageType(
                name="image",
                shape=(1, 3, IMAGE_SIZE, IMAGE_SIZE),
                scale=1.0 / (255.0 * 0.226),  # approximate for ImageNet normalization
                bias=[
                    -0.485 / 0.229,
                    -0.456 / 0.224,
                    -0.406 / 0.225,
                ],
                color_layout=ct.colorlayout.RGB,
            )
        ],
        classifier_config=ct.ClassifierConfig(class_names),
        minimum_deployment_target=ct.target.iOS15,
    )

    # Add metadata
    mlmodel.author = "TrainerApp"
    mlmodel.short_description = "Indian food classifier — 80 classes, MobileNetV3-Small"
    mlmodel.version = "1.0"
    mlmodel.license = "Private"

    # Save
    output_path = MODEL_DIR / "IndianFood.mlpackage"
    mlmodel.save(str(output_path))

    # Report size
    import subprocess
    result = subprocess.run(
        ["du", "-sh", str(output_path)], capture_output=True, text=True
    )
    size = result.stdout.strip().split("\t")[0] if result.stdout else "unknown"

    print(f"\nExported to: {output_path}")
    print(f"Model size: {size}")
    print(f"Classes: {num_classes}")
    print(f"Input: {IMAGE_SIZE}x{IMAGE_SIZE} RGB image")
    print(f"Output: classLabel (String), classLabelProbs (Dict)")

    # Save class-to-GDQS mapping for integration
    class_to_gdqs = {}
    for name in class_names:
        # Convert class name to lookup format (underscore → space)
        lookup_name = name.replace("_", " ")
        class_to_gdqs[name] = lookup_name

    with open(RESULTS_DIR / "class_to_food_db.json", "w") as f:
        json.dump(class_to_gdqs, f, indent=2)

    print(f"\nClass→FoodDB mapping saved to {RESULTS_DIR / 'class_to_food_db.json'}")
    print("\nNext steps:")
    print("1. Drag IndianFood.mlpackage into Xcode project")
    print("2. Update FoodRecognitionService.swift to use IndianFood model")
    print("3. Test end-to-end with real photos")


if __name__ == "__main__":
    main()
