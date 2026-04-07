import SwiftUI

struct WorkoutExecutionView: View {
    let plan: WorkoutPlan
    @EnvironmentObject var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isRunning = false
    @State private var currentIntervalIndex = 0
    @State private var intervalTimeRemaining = 0
    @State private var totalElapsedTime = 0
    @State private var timer: Timer?
    
    // Stats tracking
    @State private var powerReadings: [Int] = []
    @State private var cadenceReadings: [Int] = []
    @State private var hrReadings: [Int] = []
    @State private var maxPower: Int = 0
    @State private var maxHR: Int = 0
    @State private var detailedData: [WorkoutDataPoint] = []
    
    private var ftmsService: FTMSTrainerService {
        FTMSTrainerService(bluetooth: bluetooth)
    }
    
    private var tacxService: TacxFECTrainerService {
        TacxFECTrainerService(bluetooth: bluetooth)
    }
    
    private var currentInterval: WorkoutInterval? {
        guard currentIntervalIndex < plan.intervals.count else { return nil }
        return plan.intervals[currentIntervalIndex]
    }
    
    private var targetPower: Int {
        currentInterval?.targetWatts ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button("End") {
                    if totalElapsedTime > 30 {
                        saveWorkout(completed: false)
                    }
                    stopWorkout()
                    dismiss()
                }
                .foregroundStyle(.red)
                
                Spacer()
                
                Text(plan.name)
                    .font(.headline)
                
                Spacer()
                
                Button(isRunning ? "Pause" : "Resume") {
                    if isRunning {
                        pauseWorkout()
                    } else {
                        startWorkout()
                    }
                }
                .foregroundStyle(.orange)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            // Current metrics
            HStack(spacing: 20) {
                MetricBox(title: "Power", value: "\(bluetooth.latestTrainerData.instantaneousPower)", unit: "W", color: .orange)
                MetricBox(title: "Cadence", value: "\(Int(bluetooth.latestTrainerData.instantaneousCadence))", unit: "rpm", color: .blue)
                MetricBox(title: "HR", value: "\(bluetooth.currentHeartRate)", unit: "bpm", color: .red)
            }
            .padding()
            
            // Target and timers
            VStack(spacing: 16) {
                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("TARGET")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(targetPower)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Text("watts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text("INTERVAL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(intervalTimeRemaining))
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                    
                    VStack(spacing: 4) {
                        Text("ELAPSED")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(totalElapsedTime))
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.green)
                    }
                }
                
                if let interval = currentInterval {
                    Text(interval.name)
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            Spacer()
            
            // Workout graph at bottom
            WorkoutProgressGraph(
                intervals: plan.intervals,
                currentIndex: currentIntervalIndex,
                intervalProgress: currentInterval.map { 
                    1.0 - Double(intervalTimeRemaining) / Double($0.durationSeconds)
                } ?? 0
            )
            .frame(height: 120)
            .padding()
        }
        .onAppear {
            if let interval = currentInterval {
                intervalTimeRemaining = interval.durationSeconds
            }
            startWorkout()
            // Keep screen awake
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            stopWorkout()
            // Allow screen to sleep again
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
    }
    
    private func startWorkout() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
        setTargetPower()
    }
    
    private func pauseWorkout() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    private func stopWorkout() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }
    
    private func tick() {
        // Pause timer if power is 0
        let power = Int(bluetooth.latestTrainerData.instantaneousPower)
        guard power > 0 else { return }
        
        // Track stats
        let cadence = Int(bluetooth.latestTrainerData.instantaneousCadence)
        let hr = Int(bluetooth.currentHeartRate)
        
        powerReadings.append(power)
        cadenceReadings.append(cadence)
        if hr > 0 { hrReadings.append(hr) }
        if power > maxPower { maxPower = power }
        if hr > maxHR { maxHR = hr }
        
        // Store detailed data for Strava
        detailedData.append(WorkoutDataPoint(power: power, cadence: cadence, heartRate: hr))
        
        totalElapsedTime += 1
        intervalTimeRemaining -= 1
        
        if intervalTimeRemaining <= 0 {
            nextInterval()
        }
    }
    
    private func nextInterval() {
        currentIntervalIndex += 1
        if currentIntervalIndex >= plan.intervals.count {
            saveWorkout(completed: true)
            stopWorkout()
            dismiss()
            return
        }
        if let interval = currentInterval {
            intervalTimeRemaining = interval.durationSeconds
        }
        setTargetPower()
    }
    
    private func saveWorkout(completed: Bool) {
        let avgPower = powerReadings.isEmpty ? 0 : powerReadings.reduce(0, +) / powerReadings.count
        let avgCadence = cadenceReadings.isEmpty ? 0 : cadenceReadings.reduce(0, +) / cadenceReadings.count
        let avgHR = hrReadings.isEmpty ? 0 : hrReadings.reduce(0, +) / hrReadings.count
        
        let session = WorkoutSession(
            id: UUID(),
            planName: plan.name,
            date: Date(),
            durationSeconds: totalElapsedTime,
            avgPower: avgPower,
            maxPower: maxPower,
            avgCadence: avgCadence,
            avgHeartRate: avgHR,
            maxHeartRate: maxHR,
            completed: completed,
            uploadedToStrava: false,
            detailedData: detailedData
        )
        WorkoutHistoryStore.shared.save(session)
    }
    
    private func setTargetPower() {
        guard let interval = currentInterval else { return }
        let watts = Int16(interval.targetWatts)
        switch bluetooth.detectedProtocol {
        case .tacxFEC:
            tacxService.setTargetPower(watts: watts)
        case .ftms:
            ftmsService.setTargetPower(watts: watts)
        case .unknown:
            break
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct MetricBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutProgressGraph: View {
    let intervals: [WorkoutInterval]
    let currentIndex: Int
    let intervalProgress: Double
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(Array(intervals.enumerated()), id: \.1.id) { index, interval in
                    let width = geo.size.width * CGFloat(interval.durationSeconds) / CGFloat(totalDuration)
                    let height = geo.size.height * CGFloat(interval.powerFraction) / 1.2
                    
                    ZStack(alignment: .leading) {
                        // Background bar
                        Rectangle()
                            .fill(colorForPower(interval.powerFraction).opacity(0.3))
                            .frame(width: max(width, 2), height: height)
                        
                        // Filled progress
                        if index < currentIndex {
                            Rectangle()
                                .fill(colorForPower(interval.powerFraction))
                                .frame(width: max(width, 2), height: height)
                        } else if index == currentIndex {
                            Rectangle()
                                .fill(colorForPower(interval.powerFraction))
                                .frame(width: max(width * intervalProgress, 0), height: height)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
    
    private var totalDuration: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
    
    private func colorForPower(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.55: return .blue
        case 0.55..<0.75: return .green
        case 0.75..<0.90: return .yellow
        case 0.90..<1.05: return .orange
        default: return .red
        }
    }
}
