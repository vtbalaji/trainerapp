import SwiftUI
import Charts

struct HistoryView: View {
    @StateObject private var store = WorkoutHistoryStore.shared
    @StateObject private var strava = StravaService.shared
    
    var weeklyTSS: [(week: String, tss: Int)] {
        let calendar = Calendar.current
        var tssPerWeek: [Date: Int] = [:]
        
        for session in store.sessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            tssPerWeek[weekStart, default: 0] += session.tss
        }
        
        let sorted = tssPerWeek.sorted { $0.key < $1.key }.suffix(8)
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        
        return sorted.map { (formatter.string(from: $0.key), $0.value) }
    }
    
    // CTL/ATL/TSB calculation
    var formFitnessData: [(date: Date, ctl: Double, atl: Double, tsb: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Get TSS per day
        var tssPerDay: [Date: Int] = [:]
        for session in store.sessions {
            let day = calendar.startOfDay(for: session.date)
            tssPerDay[day, default: 0] += session.tss
        }
        
        guard let oldest = store.sessions.map({ $0.date }).min() else { return [] }
        let startDate = calendar.startOfDay(for: oldest)
        
        var ctl: Double = 0
        var atl: Double = 0
        let ctlDecay = 1.0 - exp(-1.0 / 42.0)
        let atlDecay = 1.0 - exp(-1.0 / 7.0)
        
        var results: [(Date, Double, Double, Double)] = []
        var current = startDate
        
        while current <= today {
            let tss = Double(tssPerDay[current] ?? 0)
            ctl = ctl + (tss - ctl) * ctlDecay
            atl = atl + (tss - atl) * atlDecay
            let tsb = ctl - atl
            results.append((current, ctl, atl, tsb))
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        // Return last 60 days
        return Array(results.suffix(60))
    }
    
    var currentCTL: Int { Int(formFitnessData.last?.ctl ?? 0) }
    var currentATL: Int { Int(formFitnessData.last?.atl ?? 0) }
    var currentTSB: Int { Int(formFitnessData.last?.tsb ?? 0) }
    
    var body: some View {
        List {
            if store.sessions.isEmpty {
                ContentUnavailableView {
                    Label("No Workouts Yet", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("Completed workouts will appear here.")
                }
            } else {
                // Form/Fitness/Fatigue
                Section {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(currentCTL)")
                                .font(.title2.bold())
                                .foregroundStyle(.blue)
                            Text("Fitness")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(currentATL)")
                                .font(.title2.bold())
                                .foregroundStyle(.pink)
                            Text("Fatigue")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(currentTSB)")
                                .font(.title2.bold())
                                .foregroundStyle(currentTSB >= 0 ? .green : .orange)
                            Text("Form")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if !formFitnessData.isEmpty {
                        Chart {
                            ForEach(formFitnessData, id: \.date) { item in
                                LineMark(
                                    x: .value("Date", item.date),
                                    y: .value("CTL", item.ctl)
                                )
                                .foregroundStyle(.blue)
                                
                                LineMark(
                                    x: .value("Date", item.date),
                                    y: .value("ATL", item.atl)
                                )
                                .foregroundStyle(.pink)
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 120)
                    }
                } header: {
                    Text("Form / Fitness / Fatigue")
                } footer: {
                    Text("Blue = Fitness (CTL), Pink = Fatigue (ATL)")
                        .font(.caption2)
                }
                
                // Weekly TSS Chart
                Section {
                    Chart(weeklyTSS, id: \.week) { item in
                        BarMark(
                            x: .value("Week", item.week),
                            y: .value("TSS", item.tss)
                        )
                        .foregroundStyle(.orange)
                    }
                    .frame(height: 120)
                } header: {
                    Text("Weekly TSS")
                }
                
                Section {
                    ForEach(store.sessions) { session in
                        WorkoutSessionRow(session: session, strava: strava, store: store)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.delete(store.sessions[index])
                        }
                    }
                } header: {
                    Text("Workouts")
                }
            }
        }
    }
}

struct WorkoutSessionRow: View {
    let session: WorkoutSession
    @ObservedObject var strava: StravaService
    @ObservedObject var store: WorkoutHistoryStore
    @State private var isUploading = false
    @State private var showError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.planName)
                    .font(.headline)
                Spacer()
                
                // Strava upload button
                if strava.isConnected {
                    if session.uploadedToStrava {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Button {
                            uploadToStrava()
                        } label: {
                            if isUploading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.up.circle")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isUploading)
                    }
                }
                
                // Completion status
                if session.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("Incomplete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(session.formattedDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                StatItem(icon: "clock", value: session.formattedDuration, label: "Time")
                StatItem(icon: "bolt.fill", value: "\(session.avgPower)W", label: "Avg Power")
                StatItem(icon: "flame.fill", value: "\(session.tss)", label: "TSS")
                if session.avgHeartRate > 0 {
                    StatItem(icon: "heart.fill", value: "\(session.avgHeartRate)", label: "Avg HR")
                }
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
        .alert("Upload Failed", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(strava.lastError ?? "Unknown error")
        }
    }
    
    private func uploadToStrava() {
        isUploading = true
        Task {
            let success = await strava.uploadWorkout(session)
            isUploading = false
            if success {
                store.markUploaded(session)
            } else {
                showError = true
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(value)
                    .fontWeight(.medium)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
