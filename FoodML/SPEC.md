# Food Recognition ML — Specification

## Goal

Replace the generic Vision classifier with a custom CoreML model that accurately identifies Indian foods from photos, maps them to GDQS food groups, and returns nutrition estimates.

---

## Model Architecture

| Item | Choice | Rationale |
|------|--------|-----------|
| Base model | MobileNetV3-Small | Fast on-device inference (<50ms on A14+), small bundle (~5MB) |
| Framework | Create ML (or PyTorch → CoreML via coremltools) | Native Apple tooling, easy `.mlmodel` export |
| Task | Image Classification (multi-label) | One photo may contain multiple foods (thali) |
| Input | 224x224 RGB image | Standard MobileNet input |
| Output | Top-5 class predictions with confidence scores | Map each class → GDQS group + nutrition |

---

## Classes (Target: 80 Indian food classes)

### Breakfast (15)
idli, dosa, masala_dosa, rava_dosa, uttapam, vada, pongal, upma, poha, puttu, appam, idiyappam, paratha, aloo_paratha, pesarattu

### Rice (10)
plain_rice, biryani, curd_rice, lemon_rice, tamarind_rice, coconut_rice, tomato_rice, bisibelebath, pulao, fried_rice

### Bread (5)
chapati, naan, poori, parotta, dosa (shared with breakfast)

### Curries & Sides (15)
sambar, rasam, dal, chicken_curry, fish_curry, egg_curry, mutton_curry, butter_chicken, palak_paneer, paneer_butter_masala, chole, rajma, aloo_gobi, poriyal, avial

### Snacks (10)
samosa, pakora, bajji, bonda, murukku, mixture, banana_chips, sundal, vada_pav, bhel_puri

### Sweets (5)
gulab_jamun, jalebi, payasam, halwa, ladoo

### Fruits (8)
banana, mango, papaya, apple, orange, watermelon, pomegranate, coconut

### Dairy & Eggs (5)
curd, milk_glass, boiled_egg, omelette, paneer_piece

### Beverages (4)
tea, coffee, buttermilk, lassi

### Misc (3)
salad, nuts_bowl, roti_with_curry (combo plate)

---

## Training Data

### Sources
1. **FoodSight-100** (Kaggle: maestros231/foodsight-100-dataset) — 100 food classes with Indian coverage (dosa, idli, samosa, biryani, naan, dal, chole, gulab jamun, jalebi, etc.). Primary dataset — use as backbone.
2. **Indian Food Images Dataset** (Kaggle) — ~4,000 images across 80 classes
3. **Food-101** (ETH Zurich) — 101k images, pick overlapping classes (rice, omelette, samosa, etc.)
4. **IIIT-Delhi Indian Food Dataset** — research dataset with Indian food categories
5. **Self-collected** — photograph real meals for classes underrepresented in above datasets (pongal, rasam, poriyal, kootu, etc.)

### Target per class
- **Minimum**: 100 images per class
- **Goal**: 300+ images per class
- **Total**: ~15,000–25,000 images

### Data pipeline
```
raw_images/
├── idli/           # 300+ images
├── dosa/           # 300+ images
├── sambar/         # 300+ images
└── ...
```

### Augmentation (applied during training)
- Random rotation (±15 degrees)
- Random crop (80-100% of image)
- Horizontal flip
- Color jitter (brightness ±20%, saturation ±20%)
- Random zoom (0.8x–1.2x)
- Lighting variation (simulate indoor/outdoor)

### Data quality rules
- Real photos only (no illustrations, no stock photos with watermarks)
- Must show the food clearly (not packaging or menus)
- Mix of: restaurant plates, home plates, steel plates, banana leaf, close-up, top-down
- Exclude images where food is <30% of frame
- Label with primary food only (thali → label the dominant item)

---

## Class → GDQS Mapping

Hardcoded lookup table (not learned by the model):

```swift
let classToGDQS: [String: GDQSFoodGroup] = [
    "idli": .wholeGrains,
    "dosa": .refinedGrains,
    "masala_dosa": .refinedGrains,
    "sambar": .legumes,
    "dal": .legumes,
    "chicken_curry": .poultryGameMeat,
    "fish_curry": .fishShellfish,
    "egg_curry": .eggs,
    "mutton_curry": .redMeat,
    // ... (reuse IndianFoodDatabase mappings)
]
```

Nutrition values: reuse existing `IndianFoodDatabase.foods` dictionary. Model predicts class name → lookup nutrition.

---

## Training Protocol

### Split
| Set | % | Purpose |
|-----|---|---------|
| Train | 70% | Model training |
| Validation | 15% | Hyperparameter tuning, early stopping |
| Test | 15% | Final evaluation (never seen during training) |

### Hyperparameters (starting point)
- Epochs: 30 (with early stopping, patience=5)
- Batch size: 32
- Learning rate: 0.001 (cosine decay)
- Optimizer: Adam
- Transfer learning: freeze base layers for 5 epochs, then fine-tune all

### Using Create ML (recommended for first pass)
```
1. Open Xcode → Create ML
2. New → Image Classifier
3. Set training data folder (class-per-folder structure)
4. Set validation data folder
5. Augmentations: flip, rotation, crop, exposure
6. Max iterations: 50
7. Transfer learning: on
8. Train → Export .mlmodel
```

---

## Success Criteria

### Accuracy targets

| Metric | Minimum | Target | How measured |
|--------|---------|--------|-------------|
| Top-1 accuracy | 70% | 85% | Test set |
| Top-3 accuracy | 85% | 95% | Test set — at least one of top 3 predictions is correct |
| Per-class recall | >50% for all classes | >70% for all classes | No class left behind |
| Confusion rate between similar foods | <20% | <10% | e.g., idli vs. appam, dosa vs. uttapam |
| Inference time (iPhone 12+) | <200ms | <100ms | On-device benchmark |
| Model size | <20MB | <10MB | .mlmodel file |

### Confusable pairs to specifically test
- idli ↔ appam (both white, round)
- dosa ↔ uttapam (flat, round, different texture)
- chapati ↔ paratha (flat bread, paratha is layered/oily)
- sambar ↔ rasam (both liquid, sambar thicker)
- gulab jamun ↔ ladoo (both round, brown)
- pongal ↔ upma (both mushy, yellow/white)
- curd ↔ raita (white, raita has vegetables)
- biryani ↔ pulao ↔ fried rice (rice dishes)

### Real-world test scenarios
1. **Home cooking on steel plate** — typical Indian household
2. **Banana leaf meal** — South Indian style
3. **Restaurant plating** — ceramic/porcelain
4. **Low light** — dinner table, indoor
5. **Multiple items** — thali with 4-5 items
6. **Partially eaten** — half-eaten dosa
7. **Close-up** — only part of food visible
8. **With hand/spoon** — natural eating context

---

## Integration Plan (after model passes criteria)

### Step 1: Drop-in replacement
```
FoodML/
├── SPEC.md              ← this file
├── IndianFood.mlmodel   ← trained model (output)
├── training/
│   ├── train.py         ← PyTorch training script
│   ├── export_coreml.py ← Convert to CoreML
│   └── evaluate.py      ← Test set evaluation
├── data/
│   ├── raw/             ← original images (gitignored)
│   ├── processed/       ← resized 224x224 (gitignored)
│   └── splits.json      ← train/val/test split record
└── results/
    ├── confusion_matrix.png
    ├── per_class_accuracy.csv
    └── benchmark.json   ← inference timing
```

### Step 2: Swap in FoodRecognitionService
Replace `VNClassifyImageRequest` with:
```swift
let model = try IndianFood(configuration: MLModelConfiguration())
let prediction = try model.prediction(image: pixelBuffer)
// prediction.classLabel → "idli"
// prediction.classLabelProbs → ["idli": 0.92, "appam": 0.04, ...]
```

### Step 3: Wire to existing database
```swift
let className = prediction.classLabel
let dbName = className.replacingOccurrences(of: "_", with: " ")
if let (group, nutrition) = IndianFoodDatabase.lookup(dbName) {
    // auto-fill food entry
}
```

No changes to GDQS scoring, food entry model, or UI needed. Only `FoodRecognitionService.swift` changes.

---

## Timeline estimate

| Phase | Work |
|-------|------|
| Data collection | Gather/download images, clean, organize into folders |
| Training v1 | Create ML quick pass — baseline accuracy |
| Error analysis | Review misclassifications, add more data for weak classes |
| Training v2 | PyTorch fine-tuned MobileNetV3 if Create ML isn't enough |
| Testing | Run all test scenarios, generate confusion matrix |
| Integration | Swap model into app, test end-to-end |
