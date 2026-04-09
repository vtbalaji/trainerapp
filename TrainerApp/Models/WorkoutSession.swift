import Foundation

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let planName: String
    let date: Date
    let durationSeconds: Int
    let avgPower: Int
    let maxPower: Int
    let avgCadence: Int
    let avgHeartRate: Int
    let maxHeartRate: Int
    let completed: Bool
    var uploadedToStrava: Bool = false
    var detailedData: [WorkoutDataPoint]? = nil
    
    var formattedDuration: String {
        let mins = durationSeconds / 60
        let secs = durationSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Calculate TSS from actual workout data
    var tss: Int {
        guard durationSeconds > 0 && avgPower > 0 else { return 0 }
        let ftp = UserSettings.shared.ftp
        guard ftp > 0 else { return 0 }
        
        // Calculate Normalized Power (NP) - for simplicity using avg power
        // In reality NP requires 30-sec rolling averages of power^4
        let np = Double(avgPower)
        let intensityFactor = np / Double(ftp)
        let hours = Double(durationSeconds) / 3600.0
        
        return Int(round(hours * pow(intensityFactor, 2) * 100))
    }
}

class WorkoutHistoryStore: ObservableObject {
    static let shared = WorkoutHistoryStore()
    
    @Published var sessions: [WorkoutSession] = []
    
    private let key = "workoutHistory"
    
    init() {
        load()
    }
    
    func save(_ session: WorkoutSession) {
        sessions.insert(session, at: 0)
        persist()
    }
    
    func delete(_ session: WorkoutSession) {
        sessions.removeAll { $0.id == session.id }
        persist()
    }
    
    func markUploaded(_ session: WorkoutSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index].uploadedToStrava = true
            persist()
        }
    }
    
    func clearAll() {
        sessions.removeAll()
        persist()
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WorkoutSession].self, from: data) else {
            return
        }
        sessions = decoded
    }
    
    private func persist() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
