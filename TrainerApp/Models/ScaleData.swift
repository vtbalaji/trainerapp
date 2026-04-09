import Foundation

struct SegmentData {
    var fatPercent: Double = 0    // % relative to ideal (80-120% is normal)
    var musclePercent: Double = 0 // % relative to ideal (80-115% is normal)
}

struct ScaleData {
    var weight: Double = 0           // kg
    var bodyFat: Double = 0          // %
    var muscleMass: Double = 0       // kg
    var boneMass: Double = 0         // kg
    var waterPercentage: Double = 0  // %
    var bmi: Double = 0
    var bmr: Int = 0                 // kcal
    var visceralFat: Int = 0
    var timestamp: Date?
    
    // Additional metrics
    var standardWeight: Double = 0   // ideal weight kg
    var fatFreeWeight: Double = 0    // lean mass kg
    var subcutaneousFat: Double = 0  // %
    var skeletalMuscle: Double = 0   // %
    var proteinRate: Double = 0      // %
    var metabolicAge: Int = 0
    var healthScore: Int = 0         // 0-100
    
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
    
    /// Calculate body composition using BIA formulas
    mutating func calculateBodyComposition(height: Double, age: Int, gender: Gender) {
        guard weight > 0 && height > 0 else { return }
        
        let heightM = height / 100.0
        let heightCm = height
        
        // BMI
        bmi = weight / (heightM * heightM)
        
        // Average impedance typically 400-700 ohms
        let impedance = impedances.isEmpty ? 500.0 : impedances.reduce(0, +) / Double(impedances.count)
        
        // Improved BIA formula calibrated to match typical smart scale results
        // Uses height²/impedance ratio with empirically-tuned coefficients
        let heightSquared = heightCm * heightCm
        var ffm: Double
        
        // Calibrated to match FitDays-style results
        if gender == .male {
            ffm = 0.50 * heightSquared / impedance + 0.14 * weight + 0.10 * heightCm - 0.10 * Double(age) + 6.5
        } else {
            ffm = 0.45 * heightSquared / impedance + 0.14 * weight + 0.10 * heightCm - 0.10 * Double(age) + 2.5
        }
        
        // Clamp FFM to realistic range (65-92% of weight)
        ffm = min(ffm, weight * 0.92)
        ffm = max(ffm, weight * 0.65)
        
        // Body Fat %
        bodyFat = ((weight - ffm) / weight) * 100
        bodyFat = max(5, min(bodyFat, 45))
        
        // Muscle Mass (lean mass minus bone, ~95% of FFM)
        muscleMass = ffm * 0.95
        
        // Body Water % (typically 50-65%, inversely related to body fat)
        waterPercentage = 73.2 - bodyFat * 0.93
        waterPercentage = max(45, min(waterPercentage, 65))
        
        // Bone Mass
        if gender == .male {
            boneMass = weight > 75 ? 3.2 : (weight > 60 ? 2.9 : 2.5)
        } else {
            boneMass = weight > 60 ? 2.5 : (weight > 45 ? 2.2 : 1.8)
        }
        
        // BMR using Mifflin-St Jeor
        if gender == .male {
            bmr = Int(10 * weight + 6.25 * heightCm - 5 * Double(age) + 5)
        } else {
            bmr = Int(10 * weight + 6.25 * heightCm - 5 * Double(age) - 161)
        }
        
        // Visceral Fat (1-30 scale)
        visceralFat = Int(max(1, min(30, bodyFat / 5 + Double(age - 20) / 10)))
        
        // Additional metrics
        fatFreeWeight = ffm
        standardWeight = 22.0 * heightM * heightM  // BMI 22 as ideal
        subcutaneousFat = bodyFat * 0.85  // ~85% of body fat is subcutaneous
        skeletalMuscle = (muscleMass / weight) * 100
        proteinRate = skeletalMuscle * 0.35  // protein ~35% of muscle
        
        // Metabolic Age (based on BMR comparison to age norms)
        let expectedBMR = gender == .male ? (10 * standardWeight + 6.25 * heightCm - 5 * 25 + 5) : (10 * standardWeight + 6.25 * heightCm - 5 * 25 - 161)
        let bmrRatio = Double(bmr) / expectedBMR
        metabolicAge = Int(Double(age) / bmrRatio)
        metabolicAge = max(18, min(metabolicAge, 80))
        
        // Health Score (0-100 based on all metrics)
        var score = 100.0
        if bmi < 18.5 || bmi > 25 { score -= 10 }
        if bodyFat > 25 { score -= Double(bodyFat - 25) }
        if visceralFat > 10 { score -= Double(visceralFat - 10) * 2 }
        healthScore = Int(max(0, min(100, score)))
        
        // Segmental analysis from impedances
        // Order: Right Arm, Left Arm, Trunk, Right Leg, Left Leg, Whole Body
        if impedances.count >= 5 {
            calculateSegmentalData(height: height, age: age, gender: gender)
        }
    }
    
    /// Calculate segmental fat/muscle percentages from impedance values
    mutating func calculateSegmentalData(height: Double, age: Int, gender: Gender) {
        guard impedances.count >= 5 else { return }
        
        let avgImpedance = impedances.reduce(0, +) / Double(impedances.count)
        
        // Segment impedances (Pro-Max order: RA, LA, Trunk, RL, LL)
        let raZ = impedances[0]
        let laZ = impedances[1]
        let trZ = impedances[2]
        let rlZ = impedances[3]
        let llZ = impedances[4]
        
        // Calculate segment fat/muscle % relative to ideal (100% = ideal)
        // Lower impedance = more muscle, higher impedance = more fat
        // Reference: average impedance represents 100%
        
        // Fat % (higher Z = more fat, scale relative to average)
        rightArm.fatPercent = min(160, max(80, 100 * raZ / avgImpedance))
        leftArm.fatPercent = min(160, max(80, 100 * laZ / avgImpedance))
        trunk.fatPercent = min(160, max(80, 100 * trZ / avgImpedance))
        rightLeg.fatPercent = min(160, max(80, 100 * rlZ / avgImpedance))
        leftLeg.fatPercent = min(160, max(80, 100 * llZ / avgImpedance))
        
        // Muscle % (lower Z = more muscle, inverse relationship)
        rightArm.musclePercent = min(115, max(80, 100 * avgImpedance / raZ))
        leftArm.musclePercent = min(115, max(80, 100 * avgImpedance / laZ))
        trunk.musclePercent = min(115, max(80, 100 * avgImpedance / trZ))
        rightLeg.musclePercent = min(115, max(80, 100 * avgImpedance / rlZ))
        leftLeg.musclePercent = min(115, max(80, 100 * avgImpedance / llZ))
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
