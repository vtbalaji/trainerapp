import Foundation
import SwiftUI

// MARK: - GDQS Food Group (25 groups + other)

enum GDQSCategory {
    case healthy, unhealthyInExcess, unhealthy
}

enum GDQSFoodGroup: String, Codable, CaseIterable {
    // Healthy (16)
    case citrusFruits = "Citrus Fruits"
    case deepOrangeFruits = "Deep Orange Fruits"
    case otherFruits = "Other Fruits"
    case darkGreenLeafy = "Dark Green Leafy Veg"
    case cruciferous = "Cruciferous Veg"
    case deepOrangeVegetables = "Deep Orange Veg"
    case otherVegetables = "Other Vegetables"
    case legumes = "Legumes"
    case deepOrangeTubers = "Deep Orange Tubers"
    case nutsAndSeeds = "Nuts & Seeds"
    case wholeGrains = "Whole Grains"
    case liquidOils = "Liquid Oils"
    case fishShellfish = "Fish & Shellfish"
    case poultryGameMeat = "Poultry"
    case lowFatDairy = "Low-Fat Dairy"
    case eggs = "Eggs"
    // Unhealthy-in-excess (2)
    case redMeat = "Red Meat"
    case highFatDairy = "High-Fat Dairy"
    // Unhealthy (7)
    case processedMeat = "Processed Meat"
    case refinedGrains = "Refined Grains"
    case sweetsIceCream = "Sweets"
    case sugarSweetenedBeverages = "Sugary Beverages"
    case juice = "Juice"
    case whiteRootsTubers = "White Roots & Tubers"
    case purchasedDeepFried = "Deep-Fried Foods"
    // Uncategorized
    case other = "Other"

    var gdqsCategory: GDQSCategory {
        switch self {
        case .citrusFruits, .deepOrangeFruits, .otherFruits,
             .darkGreenLeafy, .cruciferous, .deepOrangeVegetables, .otherVegetables,
             .legumes, .deepOrangeTubers, .nutsAndSeeds, .wholeGrains, .liquidOils,
             .fishShellfish, .poultryGameMeat, .lowFatDairy, .eggs:
            return .healthy
        case .redMeat, .highFatDairy:
            return .unhealthyInExcess
        case .processedMeat, .refinedGrains, .sweetsIceCream,
             .sugarSweetenedBeverages, .juice, .whiteRootsTubers, .purchasedDeepFried:
            return .unhealthy
        case .other:
            return .healthy
        }
    }

    var maxScore: Double {
        switch self {
        case .darkGreenLeafy, .legumes, .nutsAndSeeds: return 4
        case .citrusFruits, .deepOrangeFruits, .otherFruits,
             .wholeGrains, .liquidOils, .fishShellfish, .poultryGameMeat,
             .lowFatDairy, .eggs: return 2
        case .cruciferous, .deepOrangeVegetables, .otherVegetables, .deepOrangeTubers: return 0.5
        case .redMeat, .highFatDairy: return 1
        case .processedMeat, .refinedGrains, .sweetsIceCream,
             .sugarSweetenedBeverages, .juice, .whiteRootsTubers, .purchasedDeepFried: return 2
        case .other: return 0
        }
    }

    var icon: String {
        switch self {
        case .citrusFruits: return "🍊"
        case .deepOrangeFruits: return "🥭"
        case .otherFruits: return "🍎"
        case .darkGreenLeafy: return "🥬"
        case .cruciferous: return "🥦"
        case .deepOrangeVegetables: return "🥕"
        case .otherVegetables: return "🥗"
        case .legumes: return "🫘"
        case .deepOrangeTubers: return "🍠"
        case .nutsAndSeeds: return "🥜"
        case .wholeGrains: return "🌾"
        case .liquidOils: return "🫒"
        case .fishShellfish: return "🐟"
        case .poultryGameMeat: return "🍗"
        case .lowFatDairy: return "🥛"
        case .eggs: return "🥚"
        case .redMeat: return "🥩"
        case .highFatDairy: return "🧀"
        case .processedMeat: return "🌭"
        case .refinedGrains: return "🍚"
        case .sweetsIceCream: return "🍰"
        case .sugarSweetenedBeverages: return "🥤"
        case .juice: return "🧃"
        case .whiteRootsTubers: return "🥔"
        case .purchasedDeepFried: return "🍟"
        case .other: return "🍽️"
        }
    }

    var color: Color {
        switch gdqsCategory {
        case .healthy: return .green
        case .unhealthyInExcess: return .yellow
        case .unhealthy: return .red
        }
    }
}

// MARK: - Legacy FoodCategory (kept for backward-compatible decoding)

enum FoodCategory: String, Codable, CaseIterable {
    case fruits = "Fruits"
    case vegetables = "Vegetables"
    case wholeGrains = "Whole Grains"
    case refinedGrains = "Refined Grains"
    case protein = "Protein"
    case dairy = "Dairy"
    case legumes = "Legumes"
    case nutsSeeds = "Nuts & Seeds"
    case fatsOils = "Fats & Oils"
    case sweets = "Sweets"
    case beverages = "Beverages"
    case other = "Other"

    var toGDQS: GDQSFoodGroup {
        switch self {
        case .fruits: return .otherFruits
        case .vegetables: return .otherVegetables
        case .wholeGrains: return .wholeGrains
        case .refinedGrains: return .refinedGrains
        case .protein: return .poultryGameMeat
        case .dairy: return .highFatDairy
        case .legumes: return .legumes
        case .nutsSeeds: return .nutsAndSeeds
        case .fatsOils: return .liquidOils
        case .sweets: return .sweetsIceCream
        case .beverages: return .sugarSweetenedBeverages
        case .other: return .other
        }
    }
}

// MARK: - Food Entry

struct FoodEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var gdqsFoodGroup: GDQSFoodGroup
    var servingSize: Double // in grams
    var timestamp: Date
    var imageData: Data?
    var nutritionInfo: NutritionInfo
    var confidence: Double

    init(id: UUID = UUID(), name: String, category: GDQSFoodGroup, servingSize: Double = 100, timestamp: Date = Date(), imageData: Data? = nil, nutritionInfo: NutritionInfo = NutritionInfo(), confidence: Double = 0) {
        self.id = id
        self.name = name
        self.gdqsFoodGroup = category
        self.servingSize = servingSize
        self.timestamp = timestamp
        self.imageData = imageData
        self.nutritionInfo = nutritionInfo
        self.confidence = confidence
    }

    // Custom Codable for backward compatibility with old FoodCategory-based entries
    enum CodingKeys: String, CodingKey {
        case id, name, gdqsFoodGroup, servingSize, timestamp, imageData, nutritionInfo, confidence
        case category // legacy key
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        servingSize = try container.decode(Double.self, forKey: .servingSize)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        nutritionInfo = try container.decode(NutritionInfo.self, forKey: .nutritionInfo)
        confidence = try container.decode(Double.self, forKey: .confidence)

        // Try new key first, fall back to legacy FoodCategory
        if let group = try? container.decode(GDQSFoodGroup.self, forKey: .gdqsFoodGroup) {
            gdqsFoodGroup = group
        } else if let legacy = try? container.decode(FoodCategory.self, forKey: .category) {
            gdqsFoodGroup = legacy.toGDQS
        } else {
            gdqsFoodGroup = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(gdqsFoodGroup, forKey: .gdqsFoodGroup)
        try container.encode(servingSize, forKey: .servingSize)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(imageData, forKey: .imageData)
        try container.encode(nutritionInfo, forKey: .nutritionInfo)
        try container.encode(confidence, forKey: .confidence)
    }
}

struct NutritionInfo: Codable {
    var calories: Double = 0
    var protein: Double = 0
    var carbohydrates: Double = 0
    var fiber: Double = 0
    var sugar: Double = 0
    var fat: Double = 0
    var saturatedFat: Double = 0
    var sodium: Double = 0 // mg
}

// MARK: - GDQS Scoring

struct GDQSGroupScore: Identifiable {
    var id: GDQSFoodGroup { foodGroup }
    let foodGroup: GDQSFoodGroup
    let intakeGrams: Double
    let score: Double
}

struct GDQSResult {
    let totalScore: Double      // 0-49
    let gdqsPlus: Double        // healthy subtotal (0-32)
    let gdqsMinus: Double       // unhealthy subtotal (0-17)
    let groupScores: [GDQSGroupScore]

    var riskCategory: String {
        if totalScore >= 23 { return "Low Risk" }
        if totalScore >= 15 { return "Moderate Risk" }
        return "High Risk"
    }

    var riskColor: Color {
        if totalScore >= 23 { return .green }
        if totalScore >= 15 { return .yellow }
        return .red
    }

    static let empty = GDQSResult(totalScore: 0, gdqsPlus: 0, gdqsMinus: 0, groupScores: [])
}

// MARK: - GDQS Threshold Scoring (Bromage et al. 2021)

enum GDQSScoring {
    /// Score a single food group based on daily intake in grams
    static func score(for group: GDQSFoodGroup, grams g: Double) -> Double {
        switch group {
        // Healthy groups (higher = better)
        case .citrusFruits:          return g < 24 ? 0 : g <= 69 ? 1 : 2
        case .deepOrangeFruits:      return g < 25 ? 0 : g <= 123 ? 1 : 2
        case .otherFruits:           return g < 27 ? 0 : g <= 107 ? 1 : 2
        case .darkGreenLeafy:        return g < 13 ? 0 : g <= 37 ? 2 : 4
        case .cruciferous:           return g < 13 ? 0 : g <= 36 ? 0.25 : 0.5
        case .deepOrangeVegetables:  return g < 9 ? 0 : g <= 45 ? 0.25 : 0.5
        case .otherVegetables:       return g < 23 ? 0 : g <= 114 ? 0.25 : 0.5
        case .legumes:               return g < 9 ? 0 : g <= 42 ? 2 : 4
        case .deepOrangeTubers:      return g < 12 ? 0 : g <= 63 ? 0.25 : 0.5
        case .nutsAndSeeds:          return g < 7 ? 0 : g <= 13 ? 2 : 4
        case .wholeGrains:           return g < 8 ? 0 : g <= 13 ? 1 : 2
        case .liquidOils:            return g < 2 ? 0 : g <= 7.5 ? 1 : 2
        case .fishShellfish:         return g < 14 ? 0 : g <= 71 ? 1 : 2
        case .poultryGameMeat:       return g < 16 ? 0 : g <= 44 ? 1 : 2
        case .lowFatDairy:           return g < 33 ? 0 : g <= 132 ? 1 : 2
        case .eggs:                  return g < 6 ? 0 : g <= 32 ? 1 : 2
        // Unhealthy-in-excess (moderate = points, excess = 0)
        case .redMeat:               return g < 9 ? 0 : g <= 46 ? 1 : 0
        case .highFatDairy:          return g < 35 ? 0 : g <= 142 ? 1 : 0
        // Unhealthy (lower = better, reverse scored)
        case .processedMeat:         return g < 9 ? 2 : g <= 30 ? 1 : 0
        case .refinedGrains:         return g < 7 ? 2 : g <= 33 ? 1 : 0
        case .sweetsIceCream:        return g < 13 ? 2 : g <= 37 ? 1 : 0
        case .sugarSweetenedBeverages: return g < 57 ? 2 : g <= 180 ? 1 : 0
        case .juice:                 return g < 36 ? 2 : g <= 144 ? 1 : 0
        case .whiteRootsTubers:      return g < 27 ? 2 : g <= 107 ? 1 : 0
        case .purchasedDeepFried:    return g < 9 ? 2 : g <= 45 ? 1 : 0
        case .other:                 return 0
        }
    }
}

// MARK: - Indian Food Database

struct IndianFoodDatabase {

    static let foods: [String: (group: GDQSFoodGroup, nutrition: NutritionInfo)] = [
        // South Indian - Breakfast
        "idli": (.wholeGrains, NutritionInfo(calories: 39, protein: 2, carbohydrates: 8, fiber: 0.5, sugar: 0.5, fat: 0.1, saturatedFat: 0, sodium: 65)),
        "dosa": (.refinedGrains, NutritionInfo(calories: 133, protein: 4, carbohydrates: 19, fiber: 1, sugar: 1, fat: 5, saturatedFat: 1, sodium: 120)),
        "masala dosa": (.refinedGrains, NutritionInfo(calories: 200, protein: 5, carbohydrates: 28, fiber: 2, sugar: 2, fat: 8, saturatedFat: 2, sodium: 250)),
        "rava dosa": (.refinedGrains, NutritionInfo(calories: 150, protein: 3, carbohydrates: 22, fiber: 1, sugar: 1, fat: 6, saturatedFat: 1, sodium: 200)),
        "set dosa": (.refinedGrains, NutritionInfo(calories: 120, protein: 3, carbohydrates: 18, fiber: 0.5, sugar: 1, fat: 4, saturatedFat: 0.5, sodium: 100)),
        "uttapam": (.wholeGrains, NutritionInfo(calories: 140, protein: 4, carbohydrates: 20, fiber: 1.5, sugar: 2, fat: 5, saturatedFat: 1, sodium: 150)),
        "appam": (.refinedGrains, NutritionInfo(calories: 120, protein: 2, carbohydrates: 22, fiber: 0.5, sugar: 2, fat: 3, saturatedFat: 2, sodium: 50)),
        "puttu": (.wholeGrains, NutritionInfo(calories: 160, protein: 3, carbohydrates: 30, fiber: 2, sugar: 1, fat: 4, saturatedFat: 3, sodium: 30)),
        "green gram": (.legumes, NutritionInfo(calories: 105, protein: 7, carbohydrates: 18, fiber: 4, sugar: 1, fat: 0.5, saturatedFat: 0.1, sodium: 5)),
        "pesarattu": (.legumes, NutritionInfo(calories: 110, protein: 6, carbohydrates: 15, fiber: 3, sugar: 1, fat: 3, saturatedFat: 0.5, sodium: 100)),
        "medu vada": (.purchasedDeepFried, NutritionInfo(calories: 97, protein: 4, carbohydrates: 10, fiber: 1.5, sugar: 0.5, fat: 5, saturatedFat: 0.5, sodium: 150)),
        "vada": (.purchasedDeepFried, NutritionInfo(calories: 97, protein: 4, carbohydrates: 10, fiber: 1.5, sugar: 0.5, fat: 5, saturatedFat: 0.5, sodium: 150)),
        "pongal": (.wholeGrains, NutritionInfo(calories: 150, protein: 4, carbohydrates: 22, fiber: 1, sugar: 1, fat: 6, saturatedFat: 3, sodium: 200)),
        "ven pongal": (.wholeGrains, NutritionInfo(calories: 150, protein: 4, carbohydrates: 22, fiber: 1, sugar: 1, fat: 6, saturatedFat: 3, sodium: 200)),
        "sakkarai pongal": (.sweetsIceCream, NutritionInfo(calories: 200, protein: 3, carbohydrates: 35, fiber: 1, sugar: 20, fat: 7, saturatedFat: 4, sodium: 50)),
        "adai": (.legumes, NutritionInfo(calories: 130, protein: 5, carbohydrates: 18, fiber: 3, sugar: 1, fat: 4, saturatedFat: 0.5, sodium: 120)),
        "paniyaram": (.wholeGrains, NutritionInfo(calories: 80, protein: 2, carbohydrates: 12, fiber: 0.5, sugar: 1, fat: 3, saturatedFat: 0.5, sodium: 80)),
        "ragi": (.wholeGrains, NutritionInfo(calories: 328, protein: 7, carbohydrates: 72, fiber: 4, sugar: 2, fat: 1.3, saturatedFat: 0.3, sodium: 11)),
        "ragi dosa": (.wholeGrains, NutritionInfo(calories: 120, protein: 4, carbohydrates: 20, fiber: 2, sugar: 1, fat: 3, saturatedFat: 0.5, sodium: 120)),
        "ragi mudde": (.wholeGrains, NutritionInfo(calories: 110, protein: 3, carbohydrates: 24, fiber: 3, sugar: 1, fat: 0.5, saturatedFat: 0.1, sodium: 5)),
        "ragi porridge": (.wholeGrains, NutritionInfo(calories: 100, protein: 3, carbohydrates: 20, fiber: 2, sugar: 3, fat: 1, saturatedFat: 0.5, sodium: 30)),
        "kambu": (.wholeGrains, NutritionInfo(calories: 361, protein: 12, carbohydrates: 67, fiber: 8, sugar: 2, fat: 5, saturatedFat: 1, sodium: 5)),
        "kambu koozh": (.wholeGrains, NutritionInfo(calories: 90, protein: 3, carbohydrates: 18, fiber: 3, sugar: 1, fat: 1, saturatedFat: 0.2, sodium: 10)),
        "thinai": (.wholeGrains, NutritionInfo(calories: 340, protein: 12, carbohydrates: 60, fiber: 8, sugar: 1, fat: 4, saturatedFat: 0.7, sodium: 5)),
        "thinai rice": (.wholeGrains, NutritionInfo(calories: 130, protein: 4, carbohydrates: 24, fiber: 3, sugar: 1, fat: 2, saturatedFat: 0.3, sodium: 5)),
        "varagu": (.wholeGrains, NutritionInfo(calories: 329, protein: 10, carbohydrates: 66, fiber: 7, sugar: 1, fat: 3, saturatedFat: 0.5, sodium: 5)),
        "varagu rice": (.wholeGrains, NutritionInfo(calories: 125, protein: 3, carbohydrates: 24, fiber: 3, sugar: 1, fat: 1.5, saturatedFat: 0.3, sodium: 5)),
        "samai": (.wholeGrains, NutritionInfo(calories: 330, protein: 10, carbohydrates: 65, fiber: 7, sugar: 1, fat: 3.5, saturatedFat: 0.6, sodium: 5)),
        "samai rice": (.wholeGrains, NutritionInfo(calories: 125, protein: 3, carbohydrates: 24, fiber: 3, sugar: 1, fat: 1.5, saturatedFat: 0.3, sodium: 5)),
        "kuthiraivali": (.wholeGrains, NutritionInfo(calories: 309, protein: 9, carbohydrates: 66, fiber: 9, sugar: 1, fat: 2, saturatedFat: 0.4, sodium: 5)),
        "millet dosa": (.wholeGrains, NutritionInfo(calories: 115, protein: 4, carbohydrates: 18, fiber: 3, sugar: 1, fat: 3, saturatedFat: 0.5, sodium: 120)),
        "millet pongal": (.wholeGrains, NutritionInfo(calories: 140, protein: 4, carbohydrates: 20, fiber: 3, sugar: 1, fat: 5, saturatedFat: 2, sodium: 180)),
        "upma": (.refinedGrains, NutritionInfo(calories: 150, protein: 4, carbohydrates: 22, fiber: 2, sugar: 1, fat: 5, saturatedFat: 1, sodium: 300)),
        "poha": (.refinedGrains, NutritionInfo(calories: 130, protein: 3, carbohydrates: 25, fiber: 2, sugar: 2, fat: 3, saturatedFat: 0.5, sodium: 200)),
        "sevai": (.refinedGrains, NutritionInfo(calories: 140, protein: 3, carbohydrates: 25, fiber: 1, sugar: 1, fat: 4, saturatedFat: 1, sodium: 150)),
        "idiyappam": (.refinedGrains, NutritionInfo(calories: 130, protein: 2, carbohydrates: 25, fiber: 0.5, sugar: 0, fat: 3, saturatedFat: 2, sodium: 40)),
        "kozhukattai": (.wholeGrains, NutritionInfo(calories: 100, protein: 2, carbohydrates: 18, fiber: 1, sugar: 5, fat: 3, saturatedFat: 2, sodium: 30)),

        // South Indian - Curries & Sides
        "sambar": (.legumes, NutritionInfo(calories: 65, protein: 3, carbohydrates: 10, fiber: 3, sugar: 2, fat: 2, saturatedFat: 0.3, sodium: 300)),
        "rasam": (.otherVegetables, NutritionInfo(calories: 30, protein: 1, carbohydrates: 5, fiber: 1, sugar: 1, fat: 1, saturatedFat: 0.2, sodium: 350)),
        "coconut chutney": (.nutsAndSeeds, NutritionInfo(calories: 120, protein: 2, carbohydrates: 6, fiber: 2, sugar: 2, fat: 10, saturatedFat: 8, sodium: 150)),
        "tomato chutney": (.otherVegetables, NutritionInfo(calories: 45, protein: 1, carbohydrates: 7, fiber: 1, sugar: 4, fat: 2, saturatedFat: 0.3, sodium: 200)),
        "peanut chutney": (.nutsAndSeeds, NutritionInfo(calories: 150, protein: 5, carbohydrates: 8, fiber: 2, sugar: 2, fat: 12, saturatedFat: 2, sodium: 180)),
        "almonds": (.nutsAndSeeds, NutritionInfo(calories: 579, protein: 21, carbohydrates: 22, fiber: 12, sugar: 4, fat: 50, saturatedFat: 4, sodium: 1)),
        "cashews": (.nutsAndSeeds, NutritionInfo(calories: 553, protein: 18, carbohydrates: 30, fiber: 3, sugar: 6, fat: 44, saturatedFat: 8, sodium: 12)),
        "walnuts": (.nutsAndSeeds, NutritionInfo(calories: 654, protein: 15, carbohydrates: 14, fiber: 7, sugar: 3, fat: 65, saturatedFat: 6, sodium: 2)),
        "pistachios": (.nutsAndSeeds, NutritionInfo(calories: 560, protein: 20, carbohydrates: 28, fiber: 10, sugar: 8, fat: 45, saturatedFat: 6, sodium: 1)),
        "peanuts": (.nutsAndSeeds, NutritionInfo(calories: 567, protein: 26, carbohydrates: 16, fiber: 9, sugar: 4, fat: 49, saturatedFat: 7, sodium: 18)),
        "flaxseeds": (.nutsAndSeeds, NutritionInfo(calories: 534, protein: 18, carbohydrates: 29, fiber: 27, sugar: 2, fat: 42, saturatedFat: 4, sodium: 30)),
        "sunflower seeds": (.nutsAndSeeds, NutritionInfo(calories: 584, protein: 21, carbohydrates: 20, fiber: 9, sugar: 3, fat: 51, saturatedFat: 4, sodium: 9)),
        "pumpkin seeds": (.nutsAndSeeds, NutritionInfo(calories: 559, protein: 30, carbohydrates: 11, fiber: 6, sugar: 1, fat: 49, saturatedFat: 9, sodium: 7)),
        "mixed nuts": (.nutsAndSeeds, NutritionInfo(calories: 580, protein: 20, carbohydrates: 21, fiber: 7, sugar: 4, fat: 50, saturatedFat: 6, sodium: 5)),
        "kootu": (.legumes, NutritionInfo(calories: 80, protein: 4, carbohydrates: 12, fiber: 3, sugar: 2, fat: 2, saturatedFat: 1, sodium: 250)),
        "palak": (.darkGreenLeafy, NutritionInfo(calories: 45, protein: 3, carbohydrates: 4, fiber: 3, sugar: 1, fat: 2, saturatedFat: 0.3, sodium: 150)),
        "poriyal": (.otherVegetables, NutritionInfo(calories: 60, protein: 2, carbohydrates: 8, fiber: 3, sugar: 2, fat: 3, saturatedFat: 1, sodium: 200)),
        "avial": (.otherVegetables, NutritionInfo(calories: 90, protein: 2, carbohydrates: 8, fiber: 3, sugar: 2, fat: 6, saturatedFat: 4, sodium: 250)),
        "kuzhambu": (.legumes, NutritionInfo(calories: 70, protein: 2, carbohydrates: 8, fiber: 2, sugar: 2, fat: 4, saturatedFat: 1, sodium: 300)),
        "vathal kuzhambu": (.otherVegetables, NutritionInfo(calories: 80, protein: 1, carbohydrates: 10, fiber: 2, sugar: 3, fat: 4, saturatedFat: 0.5, sodium: 350)),
        "mor kuzhambu": (.lowFatDairy, NutritionInfo(calories: 60, protein: 3, carbohydrates: 6, fiber: 1, sugar: 3, fat: 3, saturatedFat: 1, sodium: 280)),
        "payasam": (.sweetsIceCream, NutritionInfo(calories: 180, protein: 4, carbohydrates: 28, fiber: 0.5, sugar: 20, fat: 6, saturatedFat: 4, sodium: 50)),
        "kesari": (.sweetsIceCream, NutritionInfo(calories: 200, protein: 2, carbohydrates: 35, fiber: 0, sugar: 22, fat: 7, saturatedFat: 4, sodium: 30)),
        "halwa": (.sweetsIceCream, NutritionInfo(calories: 200, protein: 2, carbohydrates: 30, fiber: 0.5, sugar: 20, fat: 9, saturatedFat: 5, sodium: 40)),
        "thogayal": (.nutsAndSeeds, NutritionInfo(calories: 70, protein: 2, carbohydrates: 5, fiber: 2, sugar: 1, fat: 5, saturatedFat: 1, sodium: 200)),
        "pachadi": (.otherVegetables, NutritionInfo(calories: 50, protein: 2, carbohydrates: 6, fiber: 1, sugar: 3, fat: 2, saturatedFat: 1, sodium: 180)),
        "thoran": (.otherVegetables, NutritionInfo(calories: 70, protein: 2, carbohydrates: 6, fiber: 3, sugar: 1, fat: 5, saturatedFat: 3, sodium: 200)),
        "olan": (.otherVegetables, NutritionInfo(calories: 80, protein: 2, carbohydrates: 10, fiber: 2, sugar: 2, fat: 4, saturatedFat: 3, sodium: 200)),

        // South Indian - Rice varieties
        "curd rice": (.lowFatDairy, NutritionInfo(calories: 150, protein: 4, carbohydrates: 22, fiber: 0.5, sugar: 2, fat: 5, saturatedFat: 3, sodium: 200)),
        "lemon rice": (.refinedGrains, NutritionInfo(calories: 170, protein: 3, carbohydrates: 28, fiber: 1, sugar: 1, fat: 6, saturatedFat: 1, sodium: 250)),
        "tamarind rice": (.refinedGrains, NutritionInfo(calories: 180, protein: 3, carbohydrates: 30, fiber: 1, sugar: 3, fat: 6, saturatedFat: 1, sodium: 280)),
        "coconut rice": (.refinedGrains, NutritionInfo(calories: 200, protein: 3, carbohydrates: 28, fiber: 2, sugar: 1, fat: 9, saturatedFat: 7, sodium: 180)),
        "tomato rice": (.refinedGrains, NutritionInfo(calories: 165, protein: 3, carbohydrates: 27, fiber: 1, sugar: 3, fat: 5, saturatedFat: 1, sodium: 260)),
        "bisibelebath": (.legumes, NutritionInfo(calories: 180, protein: 5, carbohydrates: 28, fiber: 3, sugar: 2, fat: 6, saturatedFat: 1, sodium: 300)),
        "puliyodharai": (.refinedGrains, NutritionInfo(calories: 180, protein: 3, carbohydrates: 30, fiber: 1, sugar: 3, fat: 6, saturatedFat: 1, sodium: 280)),
        "vangi bath": (.otherVegetables, NutritionInfo(calories: 170, protein: 3, carbohydrates: 26, fiber: 2, sugar: 2, fat: 6, saturatedFat: 1, sodium: 270)),

        // South Indian - Snacks (deep fried)
        "murukku": (.purchasedDeepFried, NutritionInfo(calories: 450, protein: 8, carbohydrates: 55, fiber: 2, sugar: 1, fat: 22, saturatedFat: 3, sodium: 400)),
        "mixture": (.purchasedDeepFried, NutritionInfo(calories: 480, protein: 10, carbohydrates: 50, fiber: 3, sugar: 2, fat: 28, saturatedFat: 4, sodium: 500)),
        "banana chips": (.purchasedDeepFried, NutritionInfo(calories: 520, protein: 2, carbohydrates: 58, fiber: 4, sugar: 5, fat: 33, saturatedFat: 28, sodium: 200)),
        "bonda": (.purchasedDeepFried, NutritionInfo(calories: 170, protein: 3, carbohydrates: 20, fiber: 1, sugar: 1, fat: 9, saturatedFat: 1, sodium: 200)),
        "bajji": (.purchasedDeepFried, NutritionInfo(calories: 150, protein: 3, carbohydrates: 18, fiber: 2, sugar: 1, fat: 8, saturatedFat: 1, sodium: 220)),
        "pakora": (.purchasedDeepFried, NutritionInfo(calories: 150, protein: 4, carbohydrates: 15, fiber: 2, sugar: 1, fat: 9, saturatedFat: 1, sodium: 250)),
        "samosa": (.purchasedDeepFried, NutritionInfo(calories: 260, protein: 4, carbohydrates: 30, fiber: 2, sugar: 2, fat: 14, saturatedFat: 3, sodium: 350)),
        "sundal": (.legumes, NutritionInfo(calories: 120, protein: 7, carbohydrates: 18, fiber: 5, sugar: 1, fat: 3, saturatedFat: 2, sodium: 200)),

        // South Indian - Non-veg
        "chicken chettinad": (.poultryGameMeat, NutritionInfo(calories: 220, protein: 18, carbohydrates: 5, fiber: 1, sugar: 1, fat: 15, saturatedFat: 4, sodium: 480)),
        "fish fry": (.fishShellfish, NutritionInfo(calories: 200, protein: 20, carbohydrates: 8, fiber: 0, sugar: 0, fat: 10, saturatedFat: 2, sodium: 350)),
        "prawn masala": (.fishShellfish, NutritionInfo(calories: 160, protein: 18, carbohydrates: 6, fiber: 1, sugar: 2, fat: 8, saturatedFat: 2, sodium: 400)),
        "mutton curry": (.redMeat, NutritionInfo(calories: 250, protein: 20, carbohydrates: 5, fiber: 1, sugar: 2, fat: 17, saturatedFat: 6, sodium: 450)),
        "egg roast": (.eggs, NutritionInfo(calories: 170, protein: 12, carbohydrates: 5, fiber: 1, sugar: 2, fat: 12, saturatedFat: 3, sodium: 380)),
        "chicken 65": (.poultryGameMeat, NutritionInfo(calories: 250, protein: 16, carbohydrates: 12, fiber: 1, sugar: 2, fat: 16, saturatedFat: 3, sodium: 500)),

        // North Indian
        "dal": (.legumes, NutritionInfo(calories: 104, protein: 7, carbohydrates: 18, fiber: 4, sugar: 1, fat: 0.5, saturatedFat: 0.1, sodium: 5)),
        "chapati": (.wholeGrains, NutritionInfo(calories: 120, protein: 4, carbohydrates: 25, fiber: 3, sugar: 1, fat: 1, saturatedFat: 0.2, sodium: 150)),
        "roti": (.wholeGrains, NutritionInfo(calories: 120, protein: 4, carbohydrates: 25, fiber: 3, sugar: 1, fat: 1, saturatedFat: 0.2, sodium: 150)),
        "rice": (.refinedGrains, NutritionInfo(calories: 130, protein: 2.7, carbohydrates: 28, fiber: 0.4, sugar: 0, fat: 0.3, saturatedFat: 0.1, sodium: 1)),
        "biryani": (.refinedGrains, NutritionInfo(calories: 250, protein: 8, carbohydrates: 35, fiber: 1, sugar: 2, fat: 10, saturatedFat: 3, sodium: 400)),
        "paneer": (.highFatDairy, NutritionInfo(calories: 265, protein: 18, carbohydrates: 4, fiber: 0, sugar: 2, fat: 20, saturatedFat: 13, sodium: 18)),
        "palak paneer": (.highFatDairy, NutritionInfo(calories: 180, protein: 10, carbohydrates: 8, fiber: 3, sugar: 2, fat: 12, saturatedFat: 6, sodium: 350)),
        "chicken curry": (.poultryGameMeat, NutritionInfo(calories: 180, protein: 15, carbohydrates: 6, fiber: 1, sugar: 2, fat: 11, saturatedFat: 3, sodium: 450)),
        "rajma": (.legumes, NutritionInfo(calories: 127, protein: 9, carbohydrates: 23, fiber: 6, sugar: 1, fat: 0.5, saturatedFat: 0.1, sodium: 400)),
        "chole": (.legumes, NutritionInfo(calories: 164, protein: 9, carbohydrates: 27, fiber: 8, sugar: 5, fat: 2.5, saturatedFat: 0.3, sodium: 350)),
        "aloo gobi": (.whiteRootsTubers, NutritionInfo(calories: 85, protein: 2, carbohydrates: 12, fiber: 3, sugar: 3, fat: 4, saturatedFat: 0.5, sodium: 280)),
        "raita": (.lowFatDairy, NutritionInfo(calories: 50, protein: 3, carbohydrates: 5, fiber: 0.5, sugar: 4, fat: 2, saturatedFat: 1, sodium: 150)),
        "lassi": (.lowFatDairy, NutritionInfo(calories: 110, protein: 4, carbohydrates: 18, fiber: 0, sugar: 16, fat: 3, saturatedFat: 2, sodium: 80)),
        "gulab jamun": (.sweetsIceCream, NutritionInfo(calories: 150, protein: 2, carbohydrates: 25, fiber: 0, sugar: 20, fat: 6, saturatedFat: 3, sodium: 50)),
        "jalebi": (.sweetsIceCream, NutritionInfo(calories: 150, protein: 1, carbohydrates: 30, fiber: 0, sugar: 25, fat: 4, saturatedFat: 2, sodium: 30)),
        "dark chocolate": (.other, NutritionInfo(calories: 546, protein: 5, carbohydrates: 60, fiber: 7, sugar: 24, fat: 31, saturatedFat: 19, sodium: 6)),
        "chocolate": (.sweetsIceCream, NutritionInfo(calories: 535, protein: 7, carbohydrates: 60, fiber: 3, sugar: 52, fat: 30, saturatedFat: 18, sodium: 75)),
        "paratha": (.refinedGrains, NutritionInfo(calories: 260, protein: 5, carbohydrates: 32, fiber: 2, sugar: 1, fat: 13, saturatedFat: 3, sodium: 350)),
        "naan": (.refinedGrains, NutritionInfo(calories: 262, protein: 9, carbohydrates: 45, fiber: 2, sugar: 3, fat: 5, saturatedFat: 1, sodium: 400)),
        "butter chicken": (.poultryGameMeat, NutritionInfo(calories: 240, protein: 18, carbohydrates: 8, fiber: 1, sugar: 4, fat: 16, saturatedFat: 8, sodium: 550)),
        "fish curry": (.fishShellfish, NutritionInfo(calories: 150, protein: 18, carbohydrates: 5, fiber: 1, sugar: 2, fat: 7, saturatedFat: 1.5, sodium: 400)),
        "egg curry": (.eggs, NutritionInfo(calories: 180, protein: 12, carbohydrates: 6, fiber: 1, sugar: 3, fat: 12, saturatedFat: 3, sodium: 380)),

        // Common items
        "tea": (.other, NutritionInfo(calories: 50, protein: 1, carbohydrates: 10, fiber: 0, sugar: 8, fat: 1, saturatedFat: 0.5, sodium: 10)),
        "green tea": (.other, NutritionInfo(calories: 2, protein: 0, carbohydrates: 0, fiber: 0, sugar: 0, fat: 0, saturatedFat: 0, sodium: 1)),
        "black tea": (.other, NutritionInfo(calories: 2, protein: 0, carbohydrates: 0.5, fiber: 0, sugar: 0, fat: 0, saturatedFat: 0, sodium: 3)),
        "black coffee": (.other, NutritionInfo(calories: 2, protein: 0.3, carbohydrates: 0, fiber: 0, sugar: 0, fat: 0, saturatedFat: 0, sodium: 2)),
        "coffee": (.other, NutritionInfo(calories: 60, protein: 1, carbohydrates: 10, fiber: 0, sugar: 8, fat: 2, saturatedFat: 1, sodium: 10)),
        "filter coffee": (.other, NutritionInfo(calories: 60, protein: 1, carbohydrates: 10, fiber: 0, sugar: 8, fat: 2, saturatedFat: 1, sodium: 10)),
        "protein shake": (.lowFatDairy, NutritionInfo(calories: 120, protein: 25, carbohydrates: 5, fiber: 1, sugar: 2, fat: 2, saturatedFat: 0.5, sodium: 150)),
        "amla": (.citrusFruits, NutritionInfo(calories: 44, protein: 0.9, carbohydrates: 10, fiber: 4.3, sugar: 4, fat: 0.6, saturatedFat: 0.1, sodium: 1)),
        "buttermilk": (.lowFatDairy, NutritionInfo(calories: 30, protein: 2, carbohydrates: 4, fiber: 0, sugar: 3, fat: 1, saturatedFat: 0.5, sodium: 200)),
        "curd": (.lowFatDairy, NutritionInfo(calories: 60, protein: 4, carbohydrates: 5, fiber: 0, sugar: 4, fat: 3, saturatedFat: 2, sodium: 50)),
        "yogurt": (.lowFatDairy, NutritionInfo(calories: 60, protein: 4, carbohydrates: 5, fiber: 0, sugar: 4, fat: 3, saturatedFat: 2, sodium: 50)),
        "milk": (.lowFatDairy, NutritionInfo(calories: 60, protein: 3, carbohydrates: 5, fiber: 0, sugar: 5, fat: 3, saturatedFat: 2, sodium: 50)),
        "egg": (.eggs, NutritionInfo(calories: 155, protein: 13, carbohydrates: 1, fiber: 0, sugar: 1, fat: 11, saturatedFat: 3.3, sodium: 124)),
        "boiled egg": (.eggs, NutritionInfo(calories: 155, protein: 13, carbohydrates: 1, fiber: 0, sugar: 1, fat: 11, saturatedFat: 3.3, sodium: 124)),
        "omelette": (.eggs, NutritionInfo(calories: 180, protein: 12, carbohydrates: 2, fiber: 0, sugar: 1, fat: 14, saturatedFat: 4, sodium: 300)),

        // Fruits
        "mango": (.deepOrangeFruits, NutritionInfo(calories: 60, protein: 0.8, carbohydrates: 15, fiber: 1.6, sugar: 14, fat: 0.4, saturatedFat: 0.1, sodium: 1)),
        "banana": (.otherFruits, NutritionInfo(calories: 89, protein: 1.1, carbohydrates: 23, fiber: 2.6, sugar: 12, fat: 0.3, saturatedFat: 0.1, sodium: 1)),
        "papaya": (.deepOrangeFruits, NutritionInfo(calories: 43, protein: 0.5, carbohydrates: 11, fiber: 1.7, sugar: 8, fat: 0.3, saturatedFat: 0.1, sodium: 8)),
        "apple": (.otherFruits, NutritionInfo(calories: 52, protein: 0.3, carbohydrates: 14, fiber: 2.4, sugar: 10, fat: 0.2, saturatedFat: 0, sodium: 1)),
        "orange": (.citrusFruits, NutritionInfo(calories: 47, protein: 0.9, carbohydrates: 12, fiber: 2.4, sugar: 9, fat: 0.1, saturatedFat: 0, sodium: 0)),
        "watermelon": (.otherFruits, NutritionInfo(calories: 30, protein: 0.6, carbohydrates: 8, fiber: 0.4, sugar: 6, fat: 0.2, saturatedFat: 0, sodium: 1)),
        "pomegranate": (.otherFruits, NutritionInfo(calories: 83, protein: 1.7, carbohydrates: 19, fiber: 4, sugar: 14, fat: 1.2, saturatedFat: 0.1, sodium: 3)),
        "guava": (.otherFruits, NutritionInfo(calories: 68, protein: 2.6, carbohydrates: 14, fiber: 5.4, sugar: 9, fat: 1, saturatedFat: 0.3, sodium: 2)),
        "coconut": (.nutsAndSeeds, NutritionInfo(calories: 354, protein: 3.3, carbohydrates: 15, fiber: 9, sugar: 6, fat: 33, saturatedFat: 30, sodium: 20)),
        "jackfruit": (.deepOrangeFruits, NutritionInfo(calories: 95, protein: 1.7, carbohydrates: 23, fiber: 1.5, sugar: 19, fat: 0.6, saturatedFat: 0.2, sodium: 2)),
        "grapes": (.otherFruits, NutritionInfo(calories: 69, protein: 0.7, carbohydrates: 18, fiber: 0.9, sugar: 16, fat: 0.2, saturatedFat: 0.1, sodium: 2)),
        "pear": (.otherFruits, NutritionInfo(calories: 57, protein: 0.4, carbohydrates: 15, fiber: 3.1, sugar: 10, fat: 0.1, saturatedFat: 0, sodium: 1)),
        "pineapple": (.otherFruits, NutritionInfo(calories: 50, protein: 0.5, carbohydrates: 13, fiber: 1.4, sugar: 10, fat: 0.1, saturatedFat: 0, sodium: 1)),
        "sapota": (.otherFruits, NutritionInfo(calories: 83, protein: 0.4, carbohydrates: 20, fiber: 5.3, sugar: 14, fat: 1.1, saturatedFat: 0.2, sodium: 12)),
        "custard apple": (.otherFruits, NutritionInfo(calories: 94, protein: 2.1, carbohydrates: 24, fiber: 4.4, sugar: 19, fat: 0.3, saturatedFat: 0, sodium: 4)),
        "lychee": (.otherFruits, NutritionInfo(calories: 66, protein: 0.8, carbohydrates: 17, fiber: 1.3, sugar: 15, fat: 0.4, saturatedFat: 0.1, sodium: 1)),
        "sweet lime": (.citrusFruits, NutritionInfo(calories: 43, protein: 0.7, carbohydrates: 9, fiber: 0.5, sugar: 8, fat: 0.3, saturatedFat: 0, sodium: 1)),
        "lemon": (.citrusFruits, NutritionInfo(calories: 29, protein: 1.1, carbohydrates: 9, fiber: 2.8, sugar: 2.5, fat: 0.3, saturatedFat: 0, sodium: 2)),
        "strawberry": (.otherFruits, NutritionInfo(calories: 32, protein: 0.7, carbohydrates: 8, fiber: 2, sugar: 5, fat: 0.3, saturatedFat: 0, sodium: 1)),
        "blueberry": (.otherFruits, NutritionInfo(calories: 57, protein: 0.7, carbohydrates: 14, fiber: 2.4, sugar: 10, fat: 0.3, saturatedFat: 0, sodium: 1)),

        // Vegetables & Salad items
        "cucumber": (.otherVegetables, NutritionInfo(calories: 15, protein: 0.7, carbohydrates: 3.6, fiber: 0.5, sugar: 1.7, fat: 0.1, saturatedFat: 0, sodium: 2)),
        "carrot": (.deepOrangeVegetables, NutritionInfo(calories: 41, protein: 0.9, carbohydrates: 10, fiber: 2.8, sugar: 5, fat: 0.2, saturatedFat: 0, sodium: 69)),
        "beetroot": (.otherVegetables, NutritionInfo(calories: 43, protein: 1.6, carbohydrates: 10, fiber: 2.8, sugar: 7, fat: 0.2, saturatedFat: 0, sodium: 78)),
        "tomato": (.otherVegetables, NutritionInfo(calories: 18, protein: 0.9, carbohydrates: 3.9, fiber: 1.2, sugar: 2.6, fat: 0.2, saturatedFat: 0, sodium: 5)),
        "onion": (.otherVegetables, NutritionInfo(calories: 40, protein: 1.1, carbohydrates: 9.3, fiber: 1.7, sugar: 4.2, fat: 0.1, saturatedFat: 0, sodium: 4)),
        "cabbage": (.cruciferous, NutritionInfo(calories: 25, protein: 1.3, carbohydrates: 6, fiber: 2.5, sugar: 3.2, fat: 0.1, saturatedFat: 0, sodium: 18)),
        "broccoli": (.cruciferous, NutritionInfo(calories: 34, protein: 2.8, carbohydrates: 7, fiber: 2.6, sugar: 1.7, fat: 0.4, saturatedFat: 0.1, sodium: 33)),
        "cauliflower": (.cruciferous, NutritionInfo(calories: 25, protein: 1.9, carbohydrates: 5, fiber: 2, sugar: 1.9, fat: 0.3, saturatedFat: 0.1, sodium: 30)),
        "beans": (.otherVegetables, NutritionInfo(calories: 31, protein: 1.8, carbohydrates: 7, fiber: 3.4, sugar: 1.4, fat: 0.1, saturatedFat: 0, sodium: 6)),
        "drumstick": (.otherVegetables, NutritionInfo(calories: 37, protein: 2, carbohydrates: 8.5, fiber: 2, sugar: 3, fat: 0.1, saturatedFat: 0, sodium: 42)),
        "sweet potato": (.deepOrangeTubers, NutritionInfo(calories: 86, protein: 1.6, carbohydrates: 20, fiber: 3, sugar: 4.2, fat: 0.1, saturatedFat: 0, sodium: 55)),
        "salad": (.otherVegetables, NutritionInfo(calories: 20, protein: 1, carbohydrates: 4, fiber: 1.5, sugar: 2, fat: 0.2, saturatedFat: 0, sodium: 10)),
    ]

    // Alternate spellings → canonical name
    private static let aliases: [String: String] = [
        "idly": "idli", "iddly": "idli", "iddli": "idli",
        "dosai": "dosa", "thosai": "dosa",
        "vadai": "vada", "wada": "vada", "medu wada": "medu vada",
        "chappati": "chapati", "chapathi": "chapati",
        "curry leaves": "poriyal",
        "sambhar": "sambar", "sambhaar": "sambar",
        "chettinad chicken": "chicken chettinad",
        "filter kaapi": "filter coffee", "kaapi": "filter coffee",
        "thayir sadam": "curd rice", "thayir saadam": "curd rice",
        "puliyogare": "puliyodharai",
        "bisi bele bath": "bisibelebath", "bisi bele bhath": "bisibelebath",
        "kozhukkattai": "kozhukattai", "kolukattai": "kozhukattai", "modak": "kozhukattai",
        "muruku": "murukku", "chakli": "murukku",
        "paruppu": "dal", "paruppu usili": "dal",
        "thuvayal": "thogayal",
        "bajiya": "bajji", "bhaji": "bajji",
        "pakoda": "pakora",
        "dahi": "curd", "thayir": "curd",
        "mor": "buttermilk", "neer mor": "buttermilk", "chaas": "buttermilk",
        "chai": "tea",
        "chana": "chole", "chickpea": "chole", "channa": "chole",
        "kidney bean": "rajma",
        "gobhi": "aloo gobi",
        "moong": "green gram", "moong dal": "green gram", "mung": "green gram", "mung dal": "green gram",
        "moong bean": "green gram", "pachai payaru": "green gram", "cherupayar": "green gram",
        "pesarattu dosa": "pesarattu",
        "spinach": "palak", "keerai": "palak", "pasalai keerai": "palak",
        "badam": "almonds", "almond": "almonds",
        "cashew": "cashews", "kaju": "cashews", "mundiri": "cashews",
        "walnut": "walnuts", "akhrot": "walnuts",
        "pista": "pistachios", "pistachio": "pistachios",
        "peanut": "peanuts", "groundnut": "peanuts", "verkadalai": "peanuts",
        "flaxseed": "flaxseeds", "alsi": "flaxseeds",
        "nuts": "mixed nuts", "dry fruits": "mixed nuts",
        "finger millet": "ragi", "nachni": "ragi", "kelvaragu": "ragi", "ragi ball": "ragi mudde",
        "pearl millet": "kambu", "bajra": "kambu", "sajje": "kambu", "kambu kool": "kambu koozh",
        "foxtail millet": "thinai", "kangni": "thinai", "navane": "thinai",
        "kodo millet": "varagu", "arikelu": "varagu",
        "little millet": "samai", "kutki": "samai", "same": "samai",
        "barnyard millet": "kuthiraivali", "sanwa": "kuthiraivali", "udalu": "kuthiraivali",
        "millet": "thinai",
        "chikku": "sapota", "sapodilla": "sapota",
        "mosambi": "sweet lime", "mousambi": "sweet lime",
        "sitaphal": "custard apple", "seetha pazham": "custard apple",
        "litchi": "lychee",
        "vellarikkai": "cucumber", "kheera": "cucumber", "kakdi": "cucumber",
        "indian gooseberry": "amla", "nellikai": "amla", "usiri": "amla",
        "gajar": "carrot",
        "beet": "beetroot", "beets": "beetroot",
        "green beans": "beans", "french beans": "beans",
        "murungakkai": "drumstick", "moringa": "drumstick",
        "shakarkandi": "sweet potato",
        "gobi": "cauliflower",
        "black chocolate": "dark chocolate",
    ]

    static func lookup(_ name: String) -> (group: GDQSFoodGroup, nutrition: NutritionInfo)? {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespaces)
        if let result = foods[normalized] { return result }
        if let canonical = aliases[normalized], let result = foods[canonical] { return result }
        return nil
    }

    static func search(_ query: String) -> [(name: String, group: GDQSFoodGroup, nutrition: NutritionInfo)] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }

        var results: [(name: String, group: GDQSFoodGroup, nutrition: NutritionInfo)] = []
        var seen = Set<String>()

        for (alias, canonical) in aliases {
            if alias.hasPrefix(q) || alias.contains(q), let entry = foods[canonical], !seen.contains(canonical) {
                results.append((name: canonical, group: entry.0, nutrition: entry.1))
                seen.insert(canonical)
            }
        }

        for (name, entry) in foods {
            if (name.hasPrefix(q) || name.contains(q)) && !seen.contains(name) {
                results.append((name: name, group: entry.0, nutrition: entry.1))
                seen.insert(name)
            }
        }

        return results.sorted { $0.name < $1.name }
    }
}

// MARK: - Meal Presets

struct MealPresetItem {
    let name: String
    let servingSize: Double
}

enum MealPresetCategory: String, CaseIterable {
    case beverages = "Beverages"
    case breakfast = "Breakfast"
    case meals = "Meals"
    case dinner = "Dinner"
}

struct MealPreset: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let category: MealPresetCategory
    let items: [MealPresetItem]
}

enum MealPresets {
    static let all: [MealPreset] = [
        // Beverages
        MealPreset(name: "Coffee", icon: "cup.and.saucer", category: .beverages, items: [
            MealPresetItem(name: "coffee", servingSize: 150),
        ]),
        MealPreset(name: "Black Coffee", icon: "cup.and.saucer", category: .beverages, items: [
            MealPresetItem(name: "black coffee", servingSize: 150),
        ]),
        MealPreset(name: "Tea", icon: "cup.and.saucer", category: .beverages, items: [
            MealPresetItem(name: "tea", servingSize: 150),
        ]),
        MealPreset(name: "Protein Shake", icon: "cup.and.saucer", category: .beverages, items: [
            MealPresetItem(name: "protein shake", servingSize: 300),
        ]),
        MealPreset(name: "Cucumber + Amla", icon: "leaf", category: .beverages, items: [
            MealPresetItem(name: "cucumber", servingSize: 100),
            MealPresetItem(name: "amla", servingSize: 50),
        ]),

        // Breakfast
        MealPreset(name: "Idli + Chutney + Sambar", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "idli", servingSize: 120),
            MealPresetItem(name: "coconut chutney", servingSize: 30),
            MealPresetItem(name: "sambar", servingSize: 100),
        ]),
        MealPreset(name: "Dosa + Chutney + Sambar", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "dosa", servingSize: 100),
            MealPresetItem(name: "coconut chutney", servingSize: 30),
            MealPresetItem(name: "sambar", servingSize: 100),
        ]),
        MealPreset(name: "Pongal + Chutney", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "pongal", servingSize: 150),
            MealPresetItem(name: "coconut chutney", servingSize: 30),
        ]),
        MealPreset(name: "Ragi Dosa + Chutney + Sambar", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "ragi dosa", servingSize: 100),
            MealPresetItem(name: "coconut chutney", servingSize: 30),
            MealPresetItem(name: "sambar", servingSize: 100),
        ]),
        MealPreset(name: "Millet Pongal + Chutney", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "millet pongal", servingSize: 150),
            MealPresetItem(name: "coconut chutney", servingSize: 30),
        ]),
        MealPreset(name: "Ragi Porridge", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "ragi porridge", servingSize: 200),
        ]),
        MealPreset(name: "Upma + Banana", icon: "sunrise", category: .breakfast, items: [
            MealPresetItem(name: "upma", servingSize: 150),
            MealPresetItem(name: "banana", servingSize: 100),
        ]),

        // Meals (Lunch)
        MealPreset(name: "Thinai Rice + Sambar + Poriyal", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "thinai rice", servingSize: 200),
            MealPresetItem(name: "sambar", servingSize: 150),
            MealPresetItem(name: "poriyal", servingSize: 100),
        ]),
        MealPreset(name: "Varagu Rice + Dal + Curd", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "varagu rice", servingSize: 200),
            MealPresetItem(name: "dal", servingSize: 100),
            MealPresetItem(name: "curd", servingSize: 80),
        ]),
        MealPreset(name: "Kambu Koozh", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "kambu koozh", servingSize: 250),
        ]),
        MealPreset(name: "Rice + Sambar + Poriyal", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "sambar", servingSize: 150),
            MealPresetItem(name: "poriyal", servingSize: 100),
        ]),
        MealPreset(name: "Rice + Rasam + Curd", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "rasam", servingSize: 150),
            MealPresetItem(name: "curd", servingSize: 100),
        ]),
        MealPreset(name: "Rice + Dal + Poriyal + Curd", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "dal", servingSize: 100),
            MealPresetItem(name: "poriyal", servingSize: 100),
            MealPresetItem(name: "curd", servingSize: 80),
        ]),
        MealPreset(name: "Rice + Palak + Dal", icon: "sun.max", category: .meals, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "palak", servingSize: 100),
            MealPresetItem(name: "dal", servingSize: 100),
        ]),

        // Dinner
        MealPreset(name: "Chapati + Dal + Curd", icon: "moon", category: .dinner, items: [
            MealPresetItem(name: "chapati", servingSize: 120),
            MealPresetItem(name: "dal", servingSize: 150),
            MealPresetItem(name: "curd", servingSize: 80),
        ]),
        MealPreset(name: "Rice + Fish Curry", icon: "moon", category: .dinner, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "fish curry", servingSize: 150),
        ]),
        MealPreset(name: "Rice + Chicken Curry + Raita", icon: "moon", category: .dinner, items: [
            MealPresetItem(name: "rice", servingSize: 200),
            MealPresetItem(name: "chicken curry", servingSize: 150),
            MealPresetItem(name: "raita", servingSize: 80),
        ]),
        MealPreset(name: "Curd Rice", icon: "moon", category: .dinner, items: [
            MealPresetItem(name: "curd rice", servingSize: 250),
        ]),
    ]
}

// MARK: - Store

class DietQualityStore: ObservableObject {
    @Published var entries: [FoodEntry] = []

    private let entriesKey = "diet_quality_entries"

    init() {
        loadEntries()
    }

    func addEntry(_ entry: FoodEntry) {
        entries.append(entry)
        saveEntries()
    }

    func adjustServing(_ entry: FoodEntry, delta: Double) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        let oldServing = entries[idx].servingSize
        guard oldServing > 0 else { return }
        let newServing = max(50, oldServing + delta)
        let ratio = newServing / oldServing
        entries[idx].servingSize = newServing
        let old = entries[idx].nutritionInfo
        entries[idx].nutritionInfo = NutritionInfo(
            calories: old.calories * ratio,
            protein: old.protein * ratio,
            carbohydrates: old.carbohydrates * ratio,
            fiber: old.fiber * ratio,
            sugar: old.sugar * ratio,
            fat: old.fat * ratio,
            saturatedFat: old.saturatedFat * ratio,
            sodium: old.sodium * ratio
        )
        saveEntries()
    }

    func addMealPreset(_ preset: MealPreset, date: Date) {
        for item in preset.items {
            let lookup = IndianFoodDatabase.lookup(item.name)
            let group = lookup?.group ?? .other
            let per100 = lookup?.nutrition ?? NutritionInfo()
            let scale = item.servingSize / 100.0
            let scaled = NutritionInfo(
                calories: per100.calories * scale,
                protein: per100.protein * scale,
                carbohydrates: per100.carbohydrates * scale,
                fiber: per100.fiber * scale,
                sugar: per100.sugar * scale,
                fat: per100.fat * scale,
                saturatedFat: per100.saturatedFat * scale,
                sodium: per100.sodium * scale
            )
            let entry = FoodEntry(
                name: item.name.capitalized,
                category: group,
                servingSize: item.servingSize,
                timestamp: date,
                nutritionInfo: scaled
            )
            entries.append(entry)
        }
        saveEntries()
    }

    func deleteEntry(_ entry: FoodEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func entriesForDate(_ date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.timestamp, inSameDayAs: date) }
    }

    func calculateGDQS(for entries: [FoodEntry]) -> GDQSResult {
        guard !entries.isEmpty else { return .empty }

        // Aggregate grams per GDQS food group
        var gramsPerGroup: [GDQSFoodGroup: Double] = [:]
        for entry in entries {
            gramsPerGroup[entry.gdqsFoodGroup, default: 0] += entry.servingSize
        }

        // Score each group
        var groupScores: [GDQSGroupScore] = []
        var total = 0.0
        var plus = 0.0
        var minus = 0.0

        for group in GDQSFoodGroup.allCases where group != .other {
            let grams = gramsPerGroup[group] ?? 0
            let score = GDQSScoring.score(for: group, grams: grams)
            groupScores.append(GDQSGroupScore(foodGroup: group, intakeGrams: grams, score: score))
            total += score

            switch group.gdqsCategory {
            case .healthy:
                plus += score
            case .unhealthyInExcess:
                plus += score
            case .unhealthy:
                minus += score
            }
        }

        return GDQSResult(totalScore: total, gdqsPlus: plus, gdqsMinus: minus, groupScores: groupScores)
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           var loaded = try? JSONDecoder().decode([FoodEntry].self, from: data) {
            // Backfill nutrition for entries saved before scaling fix
            var needsSave = false
            for i in loaded.indices where loaded[i].nutritionInfo.calories == 0 {
                if let (_, per100) = IndianFoodDatabase.lookup(loaded[i].name) {
                    let scale = loaded[i].servingSize / 100.0
                    loaded[i].nutritionInfo = NutritionInfo(
                        calories: per100.calories * scale,
                        protein: per100.protein * scale,
                        carbohydrates: per100.carbohydrates * scale,
                        fiber: per100.fiber * scale,
                        sugar: per100.sugar * scale,
                        fat: per100.fat * scale,
                        saturatedFat: per100.saturatedFat * scale,
                        sodium: per100.sodium * scale
                    )
                    needsSave = true
                }
            }
            entries = loaded
            if needsSave { saveEntries() }
        }
    }
}
