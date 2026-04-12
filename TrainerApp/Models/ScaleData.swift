import Foundation

struct SegmentData {
    var fatPercent: Double = 0    // % relative to ideal (80-120% is normal)
    var fatMass: Double = 0       // kg
    var musclePercent: Double = 0 // % relative to ideal (80-115% is normal)
    var muscleMass: Double = 0    // kg
    var rating: String = "Standard"
}

struct ScaleData {
    var weight: Double = 0           // kg
    var bodyFat: Double = 0          // %
    var fatMass: Double = 0          // kg
    var muscleMass: Double = 0       // kg
    var muscleRate: Double = 0       // %
    var boneMass: Double = 0         // kg
    var waterPercentage: Double = 0  // %
    var waterWeight: Double = 0      // kg
    var proteinMass: Double = 0      // kg
    var proteinRate: Double = 0      // %
    var bmi: Double = 0
    var bmr: Int = 0                 // kcal
    var visceralFat: Double = 0
    var timestamp: Date?

    // Additional metrics
    var idealBodyWeight: Double = 0  // kg
    var fatFreeWeight: Double = 0    // lean mass kg
    var subcutaneousFat: Double = 0  // %
    var skeletalMuscle: Double = 0   // %
    var bodyAge: Int = 0
    var whr: Double = 0              // waist-hip ratio (estimated)
    var healthScore: Int = 0         // 0-100

    // Weight control targets
    var weightControl: Double = 0    // kg delta to ideal
    var fatControl: Double = 0       // kg fat to lose
    var muscleControl: Double = 0    // kg muscle to gain

    // Raw impedance values from scale (6 segments)
    var impedances: [Double] = []

    // Segmental analysis
    var rightArm = SegmentData()
    var leftArm = SegmentData()
    var trunk = SegmentData()
    var rightLeg = SegmentData()
    var leftLeg = SegmentData()

    var hasData: Bool {
        weight > 0
    }

    var hasSegmentalData: Bool {
        impedances.count >= 5
    }

    /// Rating string based on standard ranges
    static func rating(for value: Double, low: Double, high: Double) -> String {
        if value < low { return "Low" }
        if value > high { return "High" }
        return "Standard"
    }

    static func bmiRating(_ bmi: Double) -> String {
        if bmi < 18.5 { return "Underweight" }
        if bmi < 25 { return "Standard" }
        if bmi < 30 { return "Overweight" }
        return "Obese"
    }

    static func bodyFatRating(_ bf: Double, gender: Gender) -> String {
        let (low, high) = gender == .male ? (10.0, 20.0) : (18.0, 28.0)
        if bf < low { return "Low" }
        if bf > high { return "High" }
        return "Standard"
    }

    static func visceralFatRating(_ vf: Double) -> String {
        if vf <= 9 { return "Standard" }
        if vf <= 14 { return "High" }
        return "Very High"
    }

    static func bodyAgeRating(_ bodyAge: Int, actualAge: Int) -> String {
        if bodyAge < actualAge - 5 { return "Excellent" }
        if bodyAge <= actualAge + 2 { return "Standard" }
        return "Above Average"
    }
    
    /// Calculate body composition using BIA formulas
    mutating func calculateBodyComposition(height: Double, age: Int, gender: Gender, calibrationOffset: Double = 0) {
        guard weight > 0 && height > 0 else { return }

        let heightM = height / 100.0
        let heightCm = height

        // BMI
        bmi = weight / (heightM * heightM)

        // Average impedance typically 400-700 ohms
        let impedance = impedances.isEmpty ? 500.0 : impedances.reduce(0, +) / Double(impedances.count)

        // ── Fat-Free Mass (Kyle et al. 2004, published BIA equation) ──
        // Kyle UG et al. "Bioelectrical impedance analysis" Nutrition 2004;20:781-90
        // Male:   FFM = -10.68 + 0.65 × height²/Z + 0.26 × weight + 0.02 × Z
        // Female: FFM = -9.53  + 0.69 × height²/Z + 0.17 × weight + 0.02 × Z
        // calibrationOffset adjusts based on DEXA/Navy reference measurement
        let heightSquared = heightCm * heightCm
        var ffm: Double

        if gender == .male {
            ffm = -10.68 + 0.65 * heightSquared / impedance + 0.26 * weight + 0.02 * impedance + calibrationOffset
        } else {
            ffm = -9.53 + 0.69 * heightSquared / impedance + 0.17 * weight + 0.02 * impedance + calibrationOffset
        }

        // Clamp FFM to realistic range
        ffm = min(ffm, weight * 0.95)
        ffm = max(ffm, weight * 0.58)

        // ── Body Fat ──
        bodyFat = ((weight - ffm) / weight) * 100
        bodyFat = max(5, min(bodyFat, 45))
        fatMass = weight * bodyFat / 100.0

        // ── Fat Free Weight ──
        fatFreeWeight = ffm

        // ── Muscle Mass & Rate ──
        // Fitdays: muscle mass ≈ FFM - bone mass (not FFM * 0.95)
        // Bone first (need it for muscle calc)
        // Bone mineral content (Heymsfield SB et al.)
        // Bone mass ≈ 4-5% of FFM for males, 3-4% for females
        if gender == .male {
            boneMass = ffm * 0.05
            boneMass = max(2.0, min(boneMass, 4.0))
        } else {
            boneMass = ffm * 0.04
            boneMass = max(1.5, min(boneMass, 3.2))
        }

        muscleMass = ffm - boneMass
        muscleRate = (muscleMass / weight) * 100

        // ── Skeletal Muscle % ──
        // Janssen et al. 2000: skeletal muscle mass ≈ 40-45% of body weight in healthy males
        // Skeletal muscle is ~75% of total muscle mass (smooth + cardiac = ~25%)
        let skeletalMass = muscleMass * 0.75
        skeletalMuscle = (skeletalMass / weight) * 100

        // ── Body Water ──
        // Standard: FFM hydration is 73.2% (Wang et al. 1999, five-level body composition model)
        waterWeight = ffm * 0.732
        waterPercentage = (waterWeight / weight) * 100
        waterPercentage = max(40, min(waterPercentage, 75))
        waterWeight = weight * waterPercentage / 100.0

        // ── Protein ──
        // Standard: protein = FFM - water - bone mineral (Wang et al. 1999)
        // Protein mass ≈ FFM × 0.194 (remainder after water 73.2% and mineral 5.3%)
        proteinMass = ffm * 0.194
        proteinRate = (proteinMass / weight) * 100

        // ── Subcutaneous Fat ──
        // Standard: subcutaneous fat ≈ 80% of total body fat (Frayn KN, 2003)
        // Remainder is visceral + intramuscular fat
        subcutaneousFat = bodyFat * 0.80

        // ── Visceral Fat Rating (1-30 scale) ──
        // Omron/Tanita standard: VF correlates with waist circumference, BMI, age
        // Approximation from BMI and age (Nagai et al. 2010):
        // VF ≈ (BMI - 10) × 0.5 + (age - 20) × 0.1 for males
        if gender == .male {
            visceralFat = max(1, (bmi - 10) * 0.5 + (Double(age) - 20) * 0.1 - 2.0)
        } else {
            visceralFat = max(1, (bmi - 10) * 0.4 + (Double(age) - 20) * 0.08 - 2.0)
        }
        visceralFat = min(visceralFat, 30)
        visceralFat = (visceralFat * 10).rounded() / 10

        // ── BMR (Mifflin-St Jeor) ──
        // Fitdays: 1445 for 60.47kg, 170cm, male
        if gender == .male {
            bmr = Int(10 * weight + 6.25 * heightCm - 5 * Double(age) + 5)
        } else {
            bmr = Int(10 * weight + 6.25 * heightCm - 5 * Double(age) - 161)
        }

        // ── Ideal Body Weight (BMI 22) ──
        idealBodyWeight = 22.0 * heightM * heightM

        // ── Body Age ──
        // Tanita standard: metabolic age based on BMR comparison to age-group averages
        // Compare actual BMR to expected BMR for age, shift accordingly
        // Expected BMR decreases ~7kcal/year for males, ~4kcal/year for females
        let expectedBMR = gender == .male
            ? 10 * idealBodyWeight + 6.25 * heightCm - 5 * Double(age) + 5
            : 10 * idealBodyWeight + 6.25 * heightCm - 5 * Double(age) - 161
        let bmrDiff = expectedBMR - Double(bmr)  // positive = actual BMR is lower than ideal
        let yearShift = gender == .male ? bmrDiff / 7.0 : bmrDiff / 4.0
        bodyAge = Int(round(Double(age) + yearShift))
        bodyAge = max(18, min(bodyAge, 80))

        // ── WHR (estimated from body fat% and BMI) ──
        // Ashwell & Gibson 2009: WHR correlates with central adiposity
        // Approximation from BF% since we don't have waist measurement
        if gender == .male {
            whr = 0.70 + bodyFat * 0.007
        } else {
            whr = 0.64 + bodyFat * 0.008
        }
        whr = min(max(whr, 0.60), 1.10)

        // ── Weight Control targets ──
        // Positive = need to gain, Negative = need to lose
        // Ideal weight based on BMI 22 (WHO healthy midpoint)
        weightControl = idealBodyWeight - weight
        // Ideal body fat: 15% male, 23% female (ACE fitness standard)
        let idealFatPercent = gender == .male ? 15.0 : 23.0
        let idealFatMass = idealBodyWeight * idealFatPercent / 100.0
        fatControl = idealFatMass - fatMass
        // Ideal muscle: FFM × (1 - bone fraction) at ideal weight
        // Standard: muscle should be ~80% of ideal body weight for males (ACSM)
        let idealMuscleFraction = gender == .male ? 0.80 : 0.65
        let idealMuscleMass = idealBodyWeight * idealMuscleFraction
        muscleControl = idealMuscleMass - muscleMass

        // ── Health Score (0-100) ──
        var score = 100.0
        if bmi < 18.5 || bmi > 25 { score -= 10 }
        let bfThreshold = gender == .male ? 20.0 : 28.0
        if bodyFat > bfThreshold {
            score -= (bodyFat - bfThreshold)
        }
        if visceralFat > 9 { score -= (visceralFat - 9) * 2 }
        healthScore = Int(max(0, min(100, score)))

        // Segmental analysis from impedances
        if impedances.count >= 5 {
            calculateSegmentalData(height: height, age: age, gender: gender)
        }
    }
    
    /// Calculate segmental fat/muscle from impedance values
    /// Produces both % relative to ideal and actual kg per segment
    mutating func calculateSegmentalData(height: Double, age: Int, gender: Gender) {
        guard impedances.count >= 5 else { return }

        let avgImpedance = impedances.reduce(0, +) / Double(impedances.count)

        // Segment impedances (RA, LA, Trunk, RL, LL)
        let segZ = [impedances[0], impedances[1], impedances[2], impedances[3], impedances[4]]

        // Approximate mass distribution: arms ~5% each, trunk ~45%, legs ~17.5% each
        let massRatios = [0.05, 0.05, 0.45, 0.175, 0.175]

        func calcSegment(z: Double, massRatio: Double) -> SegmentData {
            let segWeight = weight * massRatio
            let fatPct = min(160, max(80, 100 * z / avgImpedance))
            let musclePct = min(115, max(80, 100 * avgImpedance / z))
            let segFatRate = bodyFat / 100.0 * (z / avgImpedance)
            let fat = segWeight * segFatRate
            let muscle = segWeight * (1 - segFatRate) * 0.95
            let rating: String
            if fatPct < 90 { rating = "Low" }
            else if fatPct > 120 { rating = "High" }
            else { rating = "Standard" }
            return SegmentData(fatPercent: fatPct, fatMass: fat, musclePercent: musclePct, muscleMass: muscle, rating: rating)
        }

        rightArm = calcSegment(z: segZ[0], massRatio: massRatios[0])
        leftArm = calcSegment(z: segZ[1], massRatio: massRatios[1])
        trunk = calcSegment(z: segZ[2], massRatio: massRatios[2])
        rightLeg = calcSegment(z: segZ[3], massRatio: massRatios[3])
        leftLeg = calcSegment(z: segZ[4], massRatio: massRatios[4])
    }
    
    /// Parse standard BLE Body Composition Measurement (0x2A9C)
    static func parseBodyComposition(from data: Data) -> ScaleData {
        var result = ScaleData()
        guard data.count >= 2 else { return result }
        
        let flags: UInt16 = data[0...1].withUnsafeBytes { $0.load(as: UInt16.self) }
        var offset = 2
        
        // Bit 0: Measurement Units (0 = SI kg, 1 = Imperial lb)
        let isImperial = (flags & 0x0001) != 0
        
        // Bit 1: Time Stamp present
        if flags & 0x0002 != 0 {
            offset += 7
        }
        
        // Bit 2: User ID present
        if flags & 0x0004 != 0 {
            offset += 1
        }
        
        // Bit 3: Basal Metabolism present
        if flags & 0x0008 != 0 && offset + 2 <= data.count {
            let bmr: UInt16 = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.bmr = Int(bmr)
            offset += 2
        }
        
        // Bit 4: Muscle Percentage present
        if flags & 0x0010 != 0 && offset + 2 <= data.count {
            let muscle: UInt16 = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.muscleMass = Double(muscle) / 10.0
            offset += 2
        }
        
        // Bit 5: Muscle Mass present
        if flags & 0x0020 != 0 && offset + 2 <= data.count {
            let mass: UInt16 = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.muscleMass = Double(mass) * (isImperial ? 0.01 : 0.005)
            offset += 2
        }
        
        // Bit 6: Fat Free Mass present
        if flags & 0x0040 != 0 {
            offset += 2
        }
        
        // Bit 7: Soft Lean Mass present
        if flags & 0x0080 != 0 {
            offset += 2
        }
        
        // Bit 8: Body Water Mass present
        if flags & 0x0100 != 0 && offset + 2 <= data.count {
            let water: UInt16 = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.waterPercentage = Double(water) * (isImperial ? 0.01 : 0.005)
            offset += 2
        }
        
        // Bit 10: Body Fat Percentage present (at fixed position)
        // Body fat is usually in the measurement
        
        result.timestamp = Date()
        return result
    }
    
    /// Parse standard BLE Weight Measurement (0x2A9D)
    static func parseWeight(from data: Data) -> Double {
        guard data.count >= 3 else { return 0 }
        
        let flags: UInt8 = data[0]
        let isImperial = (flags & 0x01) != 0
        
        let weightRaw: UInt16 = data[1..<3].withUnsafeBytes { $0.load(as: UInt16.self) }
        
        // Resolution: 0.005 kg (SI) or 0.01 lb (Imperial)
        if isImperial {
            return Double(weightRaw) * 0.01 * 0.453592 // Convert lb to kg
        } else {
            return Double(weightRaw) * 0.005
        }
    }
    
    /// Parse Actofit proprietary format (may need adjustment)
    static func parseActofit(from data: Data) -> ScaleData {
        var result = ScaleData()
        
        // Actofit may use custom format - this is a starting point
        // We'll need to analyze actual data to refine
        if data.count >= 2 {
            // Try weight at different positions
            let weightRaw: UInt16 = data[0..<2].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.weight = Double(weightRaw) / 100.0
        }
        
        if data.count >= 4 {
            let fatRaw: UInt16 = data[2..<4].withUnsafeBytes { $0.load(as: UInt16.self) }
            result.bodyFat = Double(fatRaw) / 10.0
        }
        
        result.timestamp = Date()
        return result
    }
}
