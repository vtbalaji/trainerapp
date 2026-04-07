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
    let id = UUID()
    let name: String
    let description: String
    let intervals: [WorkoutInterval]
    let fileName: String
    var category: WorkoutCategory = .endurance
    
    var totalDuration: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
    
    var formattedDuration: String {
        let mins = totalDuration / 60
        return "\(mins) min"
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
    
    init() {
        loadBundledWorkouts()
    }
    
    func loadBundledWorkouts() {
        guard let workoutsURL = Bundle.main.url(forResource: "Workouts", withExtension: nil) else {
            // Try loading from individual files
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
            ("ftp_test_20min", .test)
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
}
