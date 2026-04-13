import Foundation
import UIKit
import CoreML
import Vision

class FoodRecognitionService {
    static let shared = FoodRecognitionService()

    private var mlModel: VNCoreMLModel?

    private init() {
        do {
            let config = MLModelConfiguration()
            let foodModel = try IndianFood(configuration: config)
            mlModel = try VNCoreMLModel(for: foodModel.model)
        } catch {
            print("Failed to load IndianFood model: \(error)")
        }
    }

    func recognizeFood(image: UIImage, completion: @escaping (Result<[RecognizedFood], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(FoodRecognitionError.invalidImage))
            return
        }

        // Use our trained IndianFood model if available, else fall back to Vision
        if let model = mlModel {
            recognizeWithMLModel(model: model, cgImage: cgImage, completion: completion)
        } else {
            recognizeWithVision(cgImage: cgImage, completion: completion)
        }
    }

    private func recognizeWithMLModel(model: VNCoreMLModel, cgImage: CGImage, completion: @escaping (Result<[RecognizedFood], Error>) -> Void) {
        let request = VNCoreMLRequest(model: model) { request, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            // Get top prediction above threshold
            let topPredictions = results
                .filter { $0.confidence > 0.05 }
                .prefix(5)

            guard let top = topPredictions.first else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            var foods: [RecognizedFood] = []

            // Only suggest if model is reasonably confident (>30%)
            // Low confidence means the image doesn't match known dishes well
            if top.confidence > 0.30 {
                let primaryFood = Self.classToFoodName(top.identifier)

                // Build combo suggestions based on primary food
                let combos = MealCombos.suggestions(for: top.identifier)

                // Add combo meals first
                for combo in combos {
                    foods.append(RecognizedFood(
                        name: combo.displayName,
                        confidence: Double(top.confidence),
                        comboItems: combo.items
                    ))
                }

                // Add single item as well
                foods.append(RecognizedFood(
                    name: primaryFood,
                    confidence: Double(top.confidence),
                    comboItems: nil
                ))

                // Add other top predictions as single items (>10% confidence)
                for pred in topPredictions.dropFirst() where pred.confidence > 0.10 {
                    foods.append(RecognizedFood(
                        name: Self.classToFoodName(pred.identifier),
                        confidence: Double(pred.confidence),
                        comboItems: nil
                    ))
                }
            }

            DispatchQueue.main.async { completion(.success(foods)) }
        }

        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // Fallback: generic Vision classifier
    private func recognizeWithVision(cgImage: CGImage, completion: @escaping (Result<[RecognizedFood], Error>) -> Void) {
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            let foodLabels = observations
                .filter { $0.confidence > 0.05 && Self.isFoodRelated($0.identifier) }
                .prefix(5)
                .map { RecognizedFood(name: Self.cleanLabel($0.identifier), confidence: Double($0.confidence), comboItems: nil) }

            DispatchQueue.main.async { completion(.success(Array(foodLabels))) }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Convert model class name (underscore) to display name
    static func classToFoodName(_ className: String) -> String {
        className.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func hasApiKey() -> Bool { true }

    // MARK: - Vision fallback helpers

    private static let foodKeywords: Set<String> = [
        "food", "fruit", "vegetable", "meat", "bread", "rice", "pasta",
        "sandwich", "salad", "soup", "cake", "cheese", "egg", "fish",
        "chicken", "curry", "stew", "noodle", "dumpling", "dessert",
        "pancake", "yogurt", "milk", "coffee", "tea", "banana", "mango",
    ]

    private static func isFoodRelated(_ identifier: String) -> Bool {
        let lower = identifier.lowercased().replacingOccurrences(of: "_", with: " ")
        return foodKeywords.contains(where: { lower.contains($0) })
    }

    private static func cleanLabel(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}

// MARK: - Models

struct RecognizedFood {
    let name: String
    let confidence: Double
    let comboItems: [MealComboItem]?

    var isCombo: Bool { comboItems != nil }
}

enum FoodRecognitionError: LocalizedError {
    case invalidImage
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process image"
        case .noData: return "No response from analysis"
        }
    }
}

// MARK: - Meal Combos

struct MealComboItem {
    let name: String         // food database lookup name
    let servingSize: Double  // grams
}

struct MealCombo {
    let displayName: String
    let items: [MealComboItem]
}

enum MealCombos {
    /// Return common meal combos for a detected food class
    static func suggestions(for classLabel: String) -> [MealCombo] {
        switch classLabel {
        // South Indian Breakfast
        case "idli":
            return [
                MealCombo(displayName: "Idli + Sambar + Chutney", items: [
                    MealComboItem(name: "idli", servingSize: 120),
                    MealComboItem(name: "sambar", servingSize: 100),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
                MealCombo(displayName: "Idli + Vada + Sambar", items: [
                    MealComboItem(name: "idli", servingSize: 120),
                    MealComboItem(name: "vada", servingSize: 50),
                    MealComboItem(name: "sambar", servingSize: 100),
                ]),
            ]
        case "vada":
            return [
                MealCombo(displayName: "Vada + Sambar + Chutney", items: [
                    MealComboItem(name: "vada", servingSize: 100),
                    MealComboItem(name: "sambar", servingSize: 100),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
                MealCombo(displayName: "Idli + Vada + Sambar", items: [
                    MealComboItem(name: "idli", servingSize: 120),
                    MealComboItem(name: "vada", servingSize: 50),
                    MealComboItem(name: "sambar", servingSize: 100),
                ]),
            ]
        case "masala_dosa", "set_dosa", "rava_dosa":
            let dosaName = classLabel.replacingOccurrences(of: "_", with: " ")
            return [
                MealCombo(displayName: "\(dosaName.capitalized) + Sambar + Chutney", items: [
                    MealComboItem(name: dosaName, servingSize: 120),
                    MealComboItem(name: "sambar", servingSize: 100),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
            ]
        case "uttapam":
            return [
                MealCombo(displayName: "Uttapam + Sambar + Chutney", items: [
                    MealComboItem(name: "uttapam", servingSize: 150),
                    MealComboItem(name: "sambar", servingSize: 100),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
            ]
        case "pongal":
            return [
                MealCombo(displayName: "Pongal + Chutney + Sambar", items: [
                    MealComboItem(name: "pongal", servingSize: 150),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                    MealComboItem(name: "sambar", servingSize: 100),
                ]),
            ]
        case "upma":
            return [
                MealCombo(displayName: "Upma + Chutney", items: [
                    MealComboItem(name: "upma", servingSize: 150),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
            ]
        case "poha":
            return [
                MealCombo(displayName: "Poha + Tea", items: [
                    MealComboItem(name: "poha", servingSize: 150),
                    MealComboItem(name: "tea", servingSize: 150),
                ]),
            ]
        case "appam", "idiyappam", "puttu":
            let name = classLabel.replacingOccurrences(of: "_", with: " ")
            return [
                MealCombo(displayName: "\(name.capitalized) + Curry", items: [
                    MealComboItem(name: name, servingSize: 120),
                    MealComboItem(name: "egg curry", servingSize: 100),
                ]),
            ]
        case "paniyaram":
            return [
                MealCombo(displayName: "Paniyaram + Chutney", items: [
                    MealComboItem(name: "paniyaram", servingSize: 100),
                    MealComboItem(name: "coconut chutney", servingSize: 30),
                ]),
            ]

        // South Indian Meals
        case "sambar":
            return [
                MealCombo(displayName: "Rice + Sambar + Poriyal", items: [
                    MealComboItem(name: "rice", servingSize: 200),
                    MealComboItem(name: "sambar", servingSize: 150),
                    MealComboItem(name: "poriyal", servingSize: 100),
                ]),
            ]
        case "rasam":
            return [
                MealCombo(displayName: "Rice + Rasam + Poriyal + Curd", items: [
                    MealComboItem(name: "rice", servingSize: 200),
                    MealComboItem(name: "rasam", servingSize: 150),
                    MealComboItem(name: "poriyal", servingSize: 80),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
            ]
        case "curd_rice":
            return [
                MealCombo(displayName: "Curd Rice", items: [
                    MealComboItem(name: "curd rice", servingSize: 250),
                ]),
            ]
        case "lemon_rice", "tamarind_rice":
            let name = classLabel.replacingOccurrences(of: "_", with: " ")
            return [
                MealCombo(displayName: "\(name.capitalized) + Papad", items: [
                    MealComboItem(name: name, servingSize: 200),
                ]),
            ]
        case "bisibelebath":
            return [
                MealCombo(displayName: "Bisibelebath + Chips", items: [
                    MealComboItem(name: "bisibelebath", servingSize: 250),
                ]),
            ]

        // North Indian
        case "chapati":
            return [
                MealCombo(displayName: "Chapati + Dal + Curd", items: [
                    MealComboItem(name: "chapati", servingSize: 120),
                    MealComboItem(name: "dal", servingSize: 150),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
                MealCombo(displayName: "Chapati + Sabzi + Dal", items: [
                    MealComboItem(name: "chapati", servingSize: 120),
                    MealComboItem(name: "poriyal", servingSize: 100),
                    MealComboItem(name: "dal", servingSize: 100),
                ]),
            ]
        case "naan", "butter_naan":
            return [
                MealCombo(displayName: "Naan + Butter Chicken", items: [
                    MealComboItem(name: "naan", servingSize: 100),
                    MealComboItem(name: "butter chicken", servingSize: 150),
                ]),
                MealCombo(displayName: "Naan + Paneer + Dal", items: [
                    MealComboItem(name: "naan", servingSize: 100),
                    MealComboItem(name: "palak paneer", servingSize: 100),
                    MealComboItem(name: "dal", servingSize: 100),
                ]),
            ]
        case "dal":
            return [
                MealCombo(displayName: "Rice + Dal + Curd", items: [
                    MealComboItem(name: "rice", servingSize: 200),
                    MealComboItem(name: "dal", servingSize: 150),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
            ]
        case "chole", "chole_bhature":
            return [
                MealCombo(displayName: "Chole + Rice", items: [
                    MealComboItem(name: "chole", servingSize: 150),
                    MealComboItem(name: "rice", servingSize: 200),
                ]),
            ]
        case "rajma":
            return [
                MealCombo(displayName: "Rajma + Rice", items: [
                    MealComboItem(name: "rajma", servingSize: 150),
                    MealComboItem(name: "rice", servingSize: 200),
                ]),
            ]
        case "biryani":
            return [
                MealCombo(displayName: "Biryani + Raita", items: [
                    MealComboItem(name: "biryani", servingSize: 250),
                    MealComboItem(name: "raita", servingSize: 80),
                ]),
            ]
        case "palak_paneer", "paneer":
            return [
                MealCombo(displayName: "Paneer + Roti + Dal", items: [
                    MealComboItem(name: "palak paneer", servingSize: 100),
                    MealComboItem(name: "chapati", servingSize: 120),
                    MealComboItem(name: "dal", servingSize: 100),
                ]),
            ]
        case "aloo_paratha":
            return [
                MealCombo(displayName: "Aloo Paratha + Curd + Pickle", items: [
                    MealComboItem(name: "paratha", servingSize: 150),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
            ]

        // Non-veg
        case "chicken_curry", "chicken_chettinad", "chicken_65", "chilli_chicken":
            let name = classLabel.replacingOccurrences(of: "_", with: " ")
            return [
                MealCombo(displayName: "\(name.capitalized) + Rice", items: [
                    MealComboItem(name: name, servingSize: 150),
                    MealComboItem(name: "rice", servingSize: 200),
                ]),
            ]
        case "fish_curry", "fish_fry":
            let name = classLabel.replacingOccurrences(of: "_", with: " ")
            return [
                MealCombo(displayName: "\(name.capitalized) + Rice", items: [
                    MealComboItem(name: name, servingSize: 150),
                    MealComboItem(name: "rice", servingSize: 200),
                ]),
            ]
        case "egg_curry":
            return [
                MealCombo(displayName: "Egg Curry + Rice", items: [
                    MealComboItem(name: "egg curry", servingSize: 150),
                    MealComboItem(name: "rice", servingSize: 200),
                ]),
                MealCombo(displayName: "Egg Curry + Chapati", items: [
                    MealComboItem(name: "egg curry", servingSize: 150),
                    MealComboItem(name: "chapati", servingSize: 120),
                ]),
            ]

        // Snacks
        case "samosa":
            return [
                MealCombo(displayName: "Samosa + Tea", items: [
                    MealComboItem(name: "samosa", servingSize: 100),
                    MealComboItem(name: "tea", servingSize: 150),
                ]),
            ]
        case "pakora":
            return [
                MealCombo(displayName: "Pakora + Tea", items: [
                    MealComboItem(name: "pakora", servingSize: 100),
                    MealComboItem(name: "tea", servingSize: 150),
                ]),
            ]

        // Beverages
        case "tea":
            return [
                MealCombo(displayName: "Tea + Biscuit", items: [
                    MealComboItem(name: "tea", servingSize: 150),
                ]),
            ]

        // Thali — full meal plate
        case "thali":
            return [
                MealCombo(displayName: "South Indian Thali", items: [
                    MealComboItem(name: "rice", servingSize: 200),
                    MealComboItem(name: "sambar", servingSize: 100),
                    MealComboItem(name: "rasam", servingSize: 100),
                    MealComboItem(name: "poriyal", servingSize: 80),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
                MealCombo(displayName: "North Indian Thali", items: [
                    MealComboItem(name: "chapati", servingSize: 120),
                    MealComboItem(name: "dal", servingSize: 100),
                    MealComboItem(name: "poriyal", servingSize: 80),
                    MealComboItem(name: "rice", servingSize: 150),
                    MealComboItem(name: "curd", servingSize: 80),
                ]),
            ]

        default:
            return []
        }
    }
}
