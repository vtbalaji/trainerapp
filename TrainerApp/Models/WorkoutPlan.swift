import Foundation

struct WorkoutInterval: Identifiable {
    let id = UUID()
    let name: String
    let durationSeconds: Int
    let powerFraction: Double  // FTP fraction (e.g., 0.90 = 90% FTP)
    let powerFractionEnd: Double?  // For ramps (warmup/cooldown)
    
    var targetWatts: Int {
        Int(powerFraction * Double(UserSettings.shared.ftp))
    }
    
    var targetWattsEnd: Int? {
        powerFractionEnd.map { Int($0 * Double(UserSettings.shared.ftp)) }
    }
    
    var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return secs > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(mins)min"
    }
}

enum WorkoutCategory: String, CaseIterable {
    case recovery = "Recovery"
    case endurance = "Endurance"
    case tempo = "Tempo"
    case threshold = "Threshold"
    case vo2max = "VO2max"
    case sprint = "Sprint"
    case test = "Test"
    
    var icon: String {
        switch self {
        case .recovery: return "leaf.fill"
        case .endurance: return "figure.walk"
        case .tempo: return "gauge.with.needle"
        case .threshold: return "flame.fill"
        case .vo2max: return "bolt.heart.fill"
        case .sprint: return "hare.fill"
        case .test: return "chart.bar.fill"
        }
    }
}

struct WorkoutPlan: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let intervals: [WorkoutInterval]
    let fileName: String
    var category: WorkoutCategory = .endurance
    var shorthand: String = ""
    
    init(name: String, description: String, intervals: [WorkoutInterval], fileName: String) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.intervals = intervals
        self.fileName = fileName
    }
    
    var totalDuration: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var formattedDuration: String {
        let mins = totalDuration / 60
        return "\(mins) min"
    }
    
    /// Estimated TSS if workout is completed as planned
    var estimatedTSS: Int {
        var tss: Double = 0
        for interval in intervals {
            let hours = Double(interval.durationSeconds) / 3600.0
            let intensityFactor = interval.powerFraction
            tss += hours * pow(intensityFactor, 2) * 100
        }
        return Int(round(tss))
    }
    
    /// Average Intensity Factor (weighted by duration)
    var intensityFactor: Double {
        guard totalDuration > 0 else { return 0 }
        var weightedSum: Double = 0
        for interval in intervals {
            weightedSum += interval.powerFraction * Double(interval.durationSeconds)
        }
        return weightedSum / Double(totalDuration)
    }
    
    var formattedIF: String {
        String(format: "%.2f", intensityFactor)
    }
    
    /// Estimated KJ (kilojoules) based on FTP
    func estimatedKJ(ftp: Int) -> Int {
        var kj: Double = 0
        for interval in intervals {
            let watts = Double(ftp) * interval.powerFraction
            let seconds = Double(interval.durationSeconds)
            kj += watts * seconds / 1000.0
        }
        return Int(round(kj))
    }
    
    /// Formatted duration in minutes
    var formattedDurationLong: String {
        let mins = totalDuration / 60
        return "\(mins) min"
    }
    
    /// Generate shorthand from intervals
    var generatedShorthand: String {
        if !shorthand.isEmpty { return shorthand }
        var parts: [String] = []
        var i = 0
        while i < intervals.count {
            let interval = intervals[i]
            let mins = Double(interval.durationSeconds) / 60.0
            let minsStr = mins.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(mins))" : String(format: "%.1f", mins)
            let pct = Int(interval.powerFraction * 100)
            
            if interval.name.lowercased().contains("warmup") {
                parts.append("W\(minsStr)m@\(pct)%")
            } else if interval.name.lowercased().contains("cooldown") {
                parts.append("C\(minsStr)m@\(pct)%")
            } else if interval.name.lowercased().contains("interval") {
                // Check for repeating pattern
                var repeatCount = 1
                let workPct = pct
                let workMins = minsStr
                var recoveryMins = "0"
                var recoveryPct = 50
                
                if i + 1 < intervals.count && intervals[i + 1].name.lowercased().contains("recovery") {
                    let rec = intervals[i + 1]
                    let recMins = Double(rec.durationSeconds) / 60.0
                    recoveryMins = recMins.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(recMins))" : String(format: "%.1f", recMins)
                    recoveryPct = Int(rec.powerFraction * 100)
                    
                    // Count repeats
                    var j = i + 2
                    while j + 1 < intervals.count {
                        let nextWork = intervals[j]
                        let nextRec = intervals[j + 1]
                        if nextWork.durationSeconds == interval.durationSeconds &&
                           Int(nextWork.powerFraction * 100) == workPct &&
                           nextRec.durationSeconds == intervals[i + 1].durationSeconds {
                            repeatCount += 1
                            j += 2
                        } else {
                            break
                        }
                    }
                    i += (repeatCount * 2) - 1
                    parts.append("[I\(workMins)m@\(workPct)%,R\(recoveryMins)m@\(recoveryPct)%]x\(repeatCount)")
                } else {
                    parts.append("I\(minsStr)m@\(pct)%")
                }
            } else if interval.name.lowercased().contains("recovery") {
                parts.append("R\(minsStr)m@\(pct)%")
            } else {
                parts.append("S\(minsStr)m@\(pct)%")
            }
            i += 1
        }
        return parts.joined(separator: ",")
    }
}

// MARK: - Shorthand Parser

class ShorthandParser {
    /// Parse shorthand like: W10m@50%,[I1m@110%,R0.5m@50%]x3,C10m@40%
    static func parse(_ shorthand: String) -> [WorkoutInterval]? {
        var intervals: [WorkoutInterval] = []
        let cleaned = shorthand.replacingOccurrences(of: " ", with: "")
        
        var i = cleaned.startIndex
        while i < cleaned.endIndex {
            // Skip commas
            if cleaned[i] == "," {
                i = cleaned.index(after: i)
                continue
            }
            
            // Check for repeat block [...]xN
            if cleaned[i] == "[" {
                guard let closeBracket = cleaned[i...].firstIndex(of: "]") else { return nil }
                let blockContent = String(cleaned[cleaned.index(after: i)..<closeBracket])
                
                // Find repeat count
                var repeatCount = 1
                var afterBracket = cleaned.index(after: closeBracket)
                if afterBracket < cleaned.endIndex && cleaned[afterBracket] == "x" {
                    afterBracket = cleaned.index(after: afterBracket)
                    var numEnd = afterBracket
                    while numEnd < cleaned.endIndex && cleaned[numEnd].isNumber {
                        numEnd = cleaned.index(after: numEnd)
                    }
                    if let count = Int(cleaned[afterBracket..<numEnd]) {
                        repeatCount = count
                    }
                    i = numEnd
                } else {
                    i = afterBracket
                }
                
                // Parse block content
                guard let blockIntervals = parseBlock(blockContent) else { return nil }
                for _ in 0..<repeatCount {
                    intervals.append(contentsOf: blockIntervals)
                }
            } else {
                // Parse single interval
                guard let (interval, nextIndex) = parseSingleInterval(cleaned, from: i) else { return nil }
                intervals.append(interval)
                i = nextIndex
            }
        }
        
        return intervals.isEmpty ? nil : intervals
    }
    
    private static func parseBlock(_ block: String) -> [WorkoutInterval]? {
        var intervals: [WorkoutInterval] = []
        var i = block.startIndex
        var intervalNum = 1
        
        while i < block.endIndex {
            if block[i] == "," {
                i = block.index(after: i)
                continue
            }
            guard let (interval, nextIndex) = parseSingleInterval(block, from: i, intervalNum: &intervalNum) else { return nil }
            intervals.append(interval)
            i = nextIndex
        }
        return intervals
    }
    
    private static func parseSingleInterval(_ str: String, from start: String.Index, intervalNum: inout Int) -> (WorkoutInterval, String.Index)? {
        guard start < str.endIndex else { return nil }
        
        let type = str[start]
        var i = str.index(after: start)
        
        // Parse duration (e.g., "10m" or "0.5m")
        var numStr = ""
        while i < str.endIndex && (str[i].isNumber || str[i] == ".") {
            numStr.append(str[i])
            i = str.index(after: i)
        }
        
        guard let mins = Double(numStr) else { return nil }
        let durationSeconds = Int(mins * 60)
        
        // Skip 'm'
        if i < str.endIndex && str[i] == "m" {
            i = str.index(after: i)
        }
        
        // Parse power (e.g., "@50%")
        guard i < str.endIndex && str[i] == "@" else { return nil }
        i = str.index(after: i)
        
        var pctStr = ""
        while i < str.endIndex && str[i].isNumber {
            pctStr.append(str[i])
            i = str.index(after: i)
        }
        
        guard let pct = Int(pctStr) else { return nil }
        let powerFraction = Double(pct) / 100.0
        
        // Skip '%'
        if i < str.endIndex && str[i] == "%" {
            i = str.index(after: i)
        }
        
        let name: String
        switch type {
        case "W": name = "Warmup"
        case "C": name = "Cooldown"
        case "I":
            name = "Interval \(intervalNum)"
            intervalNum += 1
        case "R": name = "Recovery"
        case "S": name = "Steady"
        default: name = "Interval"
        }
        
        let interval = WorkoutInterval(name: name, durationSeconds: durationSeconds, powerFraction: powerFraction, powerFractionEnd: nil)
        return (interval, i)
    }
    
    private static func parseSingleInterval(_ str: String, from start: String.Index) -> (WorkoutInterval, String.Index)? {
        var num = 1
        return parseSingleInterval(str, from: start, intervalNum: &num)
    }
}

class ZWOParser: NSObject, XMLParserDelegate {
    private var workoutName = ""
    private var workoutDescription = ""
    private var intervals: [WorkoutInterval] = []
    private var currentElement = ""
    private var currentText = ""
    
    func parse(data: Data, fileName: String) -> WorkoutPlan? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { return nil }
        return WorkoutPlan(
            name: workoutName.isEmpty ? fileName : workoutName,
            description: workoutDescription,
            intervals: intervals,
            fileName: fileName
        )
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String : String] = [:]) {
        currentElement = elementName
        currentText = ""
        
        switch elementName {
        case "Warmup":
            let duration = Int(attributes["Duration"] ?? "0") ?? 0
            let powerLow = Double(attributes["PowerLow"] ?? "0.4") ?? 0.4
            let powerHigh = Double(attributes["PowerHigh"] ?? "0.6") ?? 0.6
            intervals.append(WorkoutInterval(name: "Warmup", durationSeconds: duration, powerFraction: powerLow, powerFractionEnd: powerHigh))
            
        case "Cooldown":
            let duration = Int(attributes["Duration"] ?? "0") ?? 0
            let powerLow = Double(attributes["PowerLow"] ?? "0.5") ?? 0.5
            let powerHigh = Double(attributes["PowerHigh"] ?? "0.4") ?? 0.4
            intervals.append(WorkoutInterval(name: "Cooldown", durationSeconds: duration, powerFraction: powerLow, powerFractionEnd: powerHigh))
            
        case "SteadyState":
            let duration = Int(attributes["Duration"] ?? "0") ?? 0
            let power = Double(attributes["Power"] ?? "0.5") ?? 0.5
            intervals.append(WorkoutInterval(name: "Steady", durationSeconds: duration, powerFraction: power, powerFractionEnd: nil))
            
        case "IntervalsT":
            let repeat_ = Int(attributes["Repeat"] ?? "1") ?? 1
            let onDuration = Int(attributes["OnDuration"] ?? "0") ?? 0
            let onPower = Double(attributes["OnPower"] ?? "0.9") ?? 0.9
            let offDuration = Int(attributes["OffDuration"] ?? "0") ?? 0
            let offPower = Double(attributes["OffPower"] ?? "0.5") ?? 0.5
            
            for i in 1...repeat_ {
                intervals.append(WorkoutInterval(name: "Interval \(i)", durationSeconds: onDuration, powerFraction: onPower, powerFractionEnd: nil))
                if i < repeat_ || offDuration > 0 {
                    intervals.append(WorkoutInterval(name: "Recovery", durationSeconds: offDuration, powerFraction: offPower, powerFractionEnd: nil))
                }
            }
            
        case "Ramp":
            let duration = Int(attributes["Duration"] ?? "0") ?? 0
            let powerLow = Double(attributes["PowerLow"] ?? "0.4") ?? 0.4
            let powerHigh = Double(attributes["PowerHigh"] ?? "0.6") ?? 0.6
            intervals.append(WorkoutInterval(name: "Ramp", durationSeconds: duration, powerFraction: powerLow, powerFractionEnd: powerHigh))
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        switch elementName {
        case "name":
            workoutName = currentText
        case "description":
            workoutDescription = currentText
        default:
            break
        }
    }
}

class WorkoutStore: ObservableObject {
    static let shared = WorkoutStore()
    @Published var plans: [WorkoutPlan] = []
    @Published var favoriteIDs: Set<String> = []
    
    private let customPlansKey = "customWorkoutPlans"
    private let favoritesKey = "favoriteWorkouts"
    
    init() {
        loadBundledWorkouts()
        loadCustomPlans()
        loadFavorites()
    }
    
    func isFavorite(_ plan: WorkoutPlan) -> Bool {
        favoriteIDs.contains(plan.fileName)
    }
    
    func toggleFavorite(_ plan: WorkoutPlan) {
        if favoriteIDs.contains(plan.fileName) {
            favoriteIDs.remove(plan.fileName)
        } else {
            favoriteIDs.insert(plan.fileName)
        }
        saveFavorites()
    }
    
    var favorites: [WorkoutPlan] {
        plans.filter { favoriteIDs.contains($0.fileName) }
    }
    
    private func loadFavorites() {
        if let data = UserDefaults.standard.array(forKey: favoritesKey) as? [String] {
            favoriteIDs = Set(data)
        }
    }
    
    private func saveFavorites() {
        UserDefaults.standard.set(Array(favoriteIDs), forKey: favoritesKey)
    }
    
    func loadBundledWorkouts() {
        guard let workoutsURL = Bundle.main.url(forResource: "Workouts", withExtension: nil) else {
            loadIndividualWorkouts()
            return
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: workoutsURL, includingPropertiesForKeys: nil)
            let zwoFiles = files.filter { $0.pathExtension == "zwo" }
            
            for file in zwoFiles {
                if let data = try? Data(contentsOf: file),
                   let plan = ZWOParser().parse(data: data, fileName: file.deletingPathExtension().lastPathComponent) {
                    plans.append(plan)
                }
            }
        } catch {
            print("Error loading workouts: \(error)")
        }
    }
    
    private func loadIndividualWorkouts() {
        let workoutFiles: [(String, WorkoutCategory)] = [
            ("recovery_30min", .recovery),
            ("endurance_1hr", .endurance),
            ("endurance_90min", .endurance),
            ("tempo_45min", .tempo),
            ("sweet_spot_3x10", .threshold),
            ("sweetspot_2x30", .threshold),
            ("threshold_2x20", .threshold),
            ("over_unders_3x12", .threshold),
            ("pyramid_intervals", .threshold),
            ("vo2max_5x3", .vo2max),
            ("tabata_intervals", .vo2max),
            ("microbursts_15x15", .vo2max),
            ("sprint_power_6x30", .sprint),
            ("race_simulation", .threshold),
            ("ftp_test_20min", .test),
            ("ramp_test", .test)
        ]
        
        for (name, category) in workoutFiles {
            if let url = Bundle.main.url(forResource: name, withExtension: "zwo"),
               let data = try? Data(contentsOf: url),
               var plan = ZWOParser().parse(data: data, fileName: name) {
                plan.category = category
                plans.append(plan)
            }
        }
    }
    
    func workouts(for category: WorkoutCategory) -> [WorkoutPlan] {
        plans.filter { $0.category == category }
    }
    
    // MARK: - Custom Plans
    
    func addCustomPlan(_ plan: WorkoutPlan) {
        plans.append(plan)
        saveCustomPlans()
    }
    
    func deleteCustomPlan(_ plan: WorkoutPlan) {
        // Only delete custom plans (those with "custom_" prefix)
        guard plan.fileName.hasPrefix("custom_") else { return }
        plans.removeAll { $0.id == plan.id }
        saveCustomPlans()
    }
    
    func updateCustomPlan(_ plan: WorkoutPlan, name: String, description: String, shorthand: String, category: WorkoutCategory, intervals: [WorkoutInterval]) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        
        var updated = WorkoutPlan(
            name: name,
            description: description,
            intervals: intervals,
            fileName: plan.fileName
        )
        updated.category = category
        updated.shorthand = shorthand
        
        plans[index] = updated
        saveCustomPlans()
    }
    
    private func loadCustomPlans() {
        guard let data = UserDefaults.standard.data(forKey: customPlansKey),
              let saved = try? JSONDecoder().decode([SavedWorkoutPlan].self, from: data) else {
            return
        }
        
        for saved in saved {
            if let intervals = ShorthandParser.parse(saved.shorthand) {
                var plan = WorkoutPlan(
                    name: saved.name,
                    description: saved.description,
                    intervals: intervals,
                    fileName: saved.fileName
                )
                plan.category = WorkoutCategory(rawValue: saved.category) ?? .threshold
                plan.shorthand = saved.shorthand
                plans.append(plan)
            }
        }
    }
    
    private func saveCustomPlans() {
        let customPlans = plans.filter { $0.fileName.hasPrefix("custom_") }
        let saved = customPlans.map { plan in
            SavedWorkoutPlan(
                name: plan.name,
                description: plan.description,
                shorthand: plan.shorthand.isEmpty ? plan.generatedShorthand : plan.shorthand,
                category: plan.category.rawValue,
                fileName: plan.fileName
            )
        }
        
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: customPlansKey)
        }
    }
}

struct SavedWorkoutPlan: Codable {
    let name: String
    let description: String
    let shorthand: String
    let category: String
    let fileName: String
}
