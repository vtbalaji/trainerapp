import Foundation
import UIKit
import Vision

class FoodRecognitionService {
    static let shared = FoodRecognitionService()

    func recognizeFood(image: UIImage, completion: @escaping (Result<[RecognizedFood], Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(FoodRecognitionError.invalidImage))
            return
        }

        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async { completion(.success([])) }
                return
            }

            // Filter for food-related labels with reasonable confidence
            let foodLabels = observations
                .filter { $0.confidence > 0.05 && Self.isFoodRelated($0.identifier) }
                .prefix(10)
                .map { RecognizedFood(name: Self.cleanLabel($0.identifier), confidence: Double($0.confidence)) }

            // Also try to match against our Indian food database
            let dbMatches = Self.matchFoodDatabase(observations: observations)

            // Combine: database matches first, then Vision labels
            var combined: [RecognizedFood] = []
            for match in dbMatches where !combined.contains(where: { $0.name.lowercased() == match.name.lowercased() }) {
                combined.append(match)
            }
            for food in foodLabels where !combined.contains(where: { $0.name.lowercased() == food.name.lowercased() }) {
                combined.append(food)
            }

            DispatchQueue.main.async { completion(.success(Array(combined.prefix(8)))) }
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

    // Food-related Vision classifier labels
    private static let foodKeywords: Set<String> = [
        "food", "fruit", "vegetable", "meat", "bread", "rice", "pasta", "pizza",
        "sandwich", "salad", "soup", "cake", "cookie", "pie", "ice cream",
        "chocolate", "candy", "cheese", "egg", "fish", "chicken", "beef",
        "pork", "sushi", "burrito", "taco", "hot dog", "hamburger", "fries",
        "potato", "tomato", "carrot", "broccoli", "corn", "banana", "apple",
        "orange", "grape", "strawberry", "watermelon", "mango", "pineapple",
        "lemon", "coconut", "avocado", "onion", "pepper", "mushroom",
        "noodle", "dumpling", "curry", "stew", "roast", "grill", "fry",
        "bake", "breakfast", "lunch", "dinner", "meal", "dish", "plate",
        "bowl", "cup", "drink", "beverage", "juice", "milk", "coffee", "tea",
        "wine", "beer", "water", "smoothie", "yogurt", "cereal", "oatmeal",
        "pancake", "waffle", "donut", "muffin", "bagel", "pretzel",
        "cracker", "chip", "nut", "seed", "bean", "lentil", "tofu",
        "butter", "cream", "sauce", "dressing", "condiment", "spice",
        "herb", "garlic", "ginger", "cinnamon", "honey", "sugar", "salt",
        "flour", "dough", "batter", "confectionery", "produce", "grocery",
        "snack", "dessert", "appetizer", "entree", "side dish",
        // Indian food terms that Vision might recognize
        "flatbread", "naan", "wrap", "stir fry", "fried rice", "biryani",
        "dal", "paneer", "tikka", "masala", "samosa", "pakora", "chutney",
        "raita", "lassi", "chai", "roti", "chapati", "dosa", "idli",
        "guacamole", "hummus", "falafel", "kebab",
    ]

    private static func isFoodRelated(_ identifier: String) -> Bool {
        let lower = identifier.lowercased().replacingOccurrences(of: "_", with: " ")
        // Check if any food keyword appears in the identifier
        for keyword in foodKeywords {
            if lower.contains(keyword) { return true }
        }
        return false
    }

    private static func cleanLabel(_ identifier: String) -> String {
        identifier
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    // Map Vision labels to our Indian food database entries
    private static let visionToFoodDB: [String: [String]] = [
        "rice": ["rice", "biryani"],
        "bread": ["chapati", "roti", "naan", "paratha"],
        "flatbread": ["chapati", "roti", "naan", "paratha"],
        "naan": ["naan"],
        "curry": ["chicken curry", "dal", "sambar", "rajma", "chole"],
        "chicken": ["chicken curry", "butter chicken"],
        "fish": ["fish curry"],
        "egg": ["egg curry"],
        "cheese": ["paneer", "palak paneer"],
        "yogurt": ["raita", "lassi"],
        "milk": ["lassi"],
        "banana": ["banana"],
        "mango": ["mango"],
        "pancake": ["dosa"],
        "dumpling": ["idli"],
        "stew": ["sambar", "dal"],
        "soup": ["sambar"],
        "fried rice": ["biryani", "poha"],
        "dessert": ["gulab jamun", "jalebi"],
        "confectionery": ["gulab jamun", "jalebi"],
        "candy": ["jalebi"],
        "donut": ["gulab jamun"],
        "fruit": ["mango", "banana", "papaya"],
        "salad": ["raita"],
        "bean": ["rajma", "chole", "dal"],
        "lentil": ["dal", "sambar"],
    ]

    private static func matchFoodDatabase(observations: [VNClassificationObservation]) -> [RecognizedFood] {
        var matches: [RecognizedFood] = []
        let seen = NSMutableSet()

        for obs in observations where obs.confidence > 0.03 {
            let label = obs.identifier.lowercased().replacingOccurrences(of: "_", with: " ")
            // Check direct database match
            if IndianFoodDatabase.lookup(label) != nil && !seen.contains(label) {
                matches.append(RecognizedFood(name: label.capitalized, confidence: Double(obs.confidence)))
                seen.add(label)
            }
            // Check mapped matches
            for (keyword, dbNames) in visionToFoodDB {
                if label.contains(keyword) {
                    for name in dbNames where !seen.contains(name) {
                        matches.append(RecognizedFood(name: name.capitalized, confidence: Double(obs.confidence) * 0.8))
                        seen.add(name)
                    }
                }
            }
        }

        return matches.sorted { $0.confidence > $1.confidence }
    }

    static func hasApiKey() -> Bool { true } // No API key needed for on-device Vision
}

struct RecognizedFood {
    let name: String
    let confidence: Double
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
