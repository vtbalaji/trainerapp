import SwiftUI
import AVFoundation

struct WorkoutExecutionView: View {
    let plan: WorkoutPlan
    @EnvironmentObject var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss

    @State private var isRunning = false
    @State private var isPaused = false
    @State private var currentIntervalIndex = 0
    @State private var intervalTimeRemaining = 0
    @State private var totalElapsedTime = 0
    @State private var timer: Timer?
    @State private var intensityPercent = 100

    // Stats tracking
    @State private var powerReadings: [Int] = []
    @State private var cadenceReadings: [Int] = []
    @State private var hrReadings: [Int] = []
    @State private var maxPower: Int = 0
    @State private var maxHR: Int = 0
    @State private var detailedData: [WorkoutDataPoint] = []

    // Actual power trace for chart overlay (one per second)
    @State private var powerTrace: [Int] = []
    @State private var zeroPowerSeconds = 0


    private var currentInterval: WorkoutInterval? {
        guard currentIntervalIndex < plan.intervals.count else { return nil }
        return plan.intervals[currentIntervalIndex]
    }

    private var targetPower: Int {
        guard let interval = currentInterval else { return 0 }
        return Int(Double(interval.targetWatts) * Double(intensityPercent) / 100.0)
    }

    private var isTrainerConnected: Bool {
        bluetooth.trainerState == .ready
    }

    private var totalWorkoutDuration: Int {
        plan.intervals.reduce(0) { $0 + $1.durationSeconds }
    }

    private var estimatedEndTime: String {
        let remaining = totalWorkoutDuration - totalElapsedTime
        let end = Date().addingTimeInterval(Double(remaining))
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: end)
    }

    // Seconds into the workout where current interval starts
    private var currentIntervalStartTime: Int {
        plan.intervals.prefix(currentIntervalIndex).reduce(0) { $0 + $1.durationSeconds }
    }

    private var intervalProgress: Double {
        guard let interval = currentInterval, interval.durationSeconds > 0 else { return 0 }
        return 1.0 - Double(intervalTimeRemaining) / Double(interval.durationSeconds)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isTrainerConnected || isRunning {
                VStack(spacing: 0) {
                    // ── Header: Workout name + pause/menu ──
                    headerBar

                    // ── Primary metrics: Power | Interval Time | Heart Rate ──
                    primaryMetrics

                    // ── Interval progress bar ──
                    intervalProgressBar

                    // ── Secondary metrics: Target | Total Time | Cadence ──
                    secondaryMetrics

                    // ── End time ──
                    Text("END TIME: \(estimatedEndTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Spacer()

                    // ── Zoomed interval chart ──
                    zoomedChart
                        .frame(height: 140)
                        .padding(.horizontal, 4)

                    // ── Full workout chart with power trace ──
                    fullWorkoutChart
                        .frame(height: 140)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)

                    // ── Bottom bar: Intensity + Devices ──
                    bottomBar
                }
            }

            // Paused overlay
            if isPaused {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.orange)
                    Text("PAUSED")
                        .font(.title.bold())
                        .foregroundStyle(.white)
                    Text("Pedal to resume")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        endWorkout()
                    } label: {
                        Text("End Workout")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(.red)
                            .cornerRadius(10)
                    }
                }
            }

            // Not connected overlay
            if !isTrainerConnected && !isRunning {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                    Text("Trainer Not Connected")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Button {
                        bluetooth.autoReconnectSavedDevices()
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text("Connect")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(.orange)
                        .cornerRadius(10)
                    }
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.gray)
                        .padding(.top, 10)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarHidden(true)
        .onAppear {
            if let interval = currentInterval {
                intervalTimeRemaining = interval.durationSeconds
            }
            startWorkout()
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
        }
        .onDisappear {
            stopTimer()
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
        }
        .onChange(of: isRunning) { _, running in
            #if os(iOS)
            UIApplication.shared.isIdleTimerDisabled = running
            #endif
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        VStack(spacing: 2) {
            HStack {
                Button {
                    endWorkout()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Button {
                    if isRunning {
                        pauseWorkout()
                    }
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
            }
            Text(plan.name)
                .font(.title3.bold())
                .foregroundStyle(.white)
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Primary Metrics

    private var primaryMetrics: some View {
        HStack(spacing: 0) {
            ExecutionMetric(
                label: "POWER",
                value: "\(bluetooth.latestTrainerData.instantaneousPower)",
                color: .white
            )
            ExecutionMetric(
                label: "INTERVAL TIME",
                value: formatTimeMMSS(intervalTimeRemaining),
                color: .white
            )
            ExecutionMetric(
                label: "HEART RATE",
                value: bluetooth.currentHeartRate > 0 ? "\(bluetooth.currentHeartRate)" : "---",
                color: .white
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Interval Progress Bar

    private var intervalProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                Rectangle()
                    .fill(Color.green)
                    .frame(width: geo.size.width * intervalProgress)
            }
        }
        .frame(height: 6)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }

    // MARK: - Secondary Metrics

    private var secondaryMetrics: some View {
        HStack(spacing: 0) {
            ExecutionMetric(
                label: "TARGET",
                value: "\(targetPower)",
                color: .white
            )
            ExecutionMetric(
                label: "TOTAL TIME",
                value: formatTimeHMMSS(totalElapsedTime),
                color: .white
            )
            ExecutionMetric(
                label: "CADENCE",
                value: "\(Int(bluetooth.latestTrainerData.instantaneousCadence))",
                color: .white
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Zoomed Interval Chart

    private var zoomedChart: some View {
        GeometryReader { geo in
            let ftp = UserSettings.shared.ftp
            let maxWatts = max(300, Int(Double(ftp) * 1.5))
            let intervalStart = currentIntervalStartTime
            let intervalDuration = currentInterval?.durationSeconds ?? 1

            // Show a window around the current interval (±30s context)
            let windowStart = max(0, intervalStart - 30)
            let windowEnd = min(totalWorkoutDuration, intervalStart + intervalDuration + 30)
            let windowDuration = max(1, windowEnd - windowStart)

            ZStack(alignment: .topLeading) {
                // Background
                Color.black

                // Power blocks for this window
                drawIntervalBlocks(geo: geo, maxWatts: maxWatts,
                                   windowStart: windowStart, windowDuration: windowDuration)

                // FTP line
                ftpLine(geo: geo, maxWatts: maxWatts, ftp: ftp)

                // Current position marker (yellow vertical line)
                let elapsed = Double(totalElapsedTime - windowStart)
                let xPos = geo.size.width * elapsed / Double(windowDuration)
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 2)
                    .offset(x: max(0, min(xPos, geo.size.width)))

                // Actual power trace overlay (yellow line)
                powerTracePath(geo: geo, maxWatts: maxWatts,
                               windowStart: windowStart, windowDuration: windowDuration)

                // Y-axis labels
                yAxisLabels(geo: geo, maxWatts: maxWatts)

                // Time axis
                timeAxis(geo: geo, windowStart: windowStart, windowDuration: windowDuration)
            }
            .clipShape(Rectangle())
        }
    }

    // MARK: - Full Workout Chart

    private var fullWorkoutChart: some View {
        GeometryReader { geo in
            let ftp = UserSettings.shared.ftp
            let maxWatts = max(300, Int(Double(ftp) * 1.5))

            ZStack(alignment: .topLeading) {
                Color.black

                // All interval blocks
                drawIntervalBlocks(geo: geo, maxWatts: maxWatts,
                                   windowStart: 0, windowDuration: totalWorkoutDuration)

                // FTP line
                ftpLine(geo: geo, maxWatts: maxWatts, ftp: ftp)

                // Actual power trace overlay
                powerTracePath(geo: geo, maxWatts: maxWatts,
                               windowStart: 0, windowDuration: totalWorkoutDuration)

                // Y-axis labels
                yAxisLabels(geo: geo, maxWatts: maxWatts)

                // Time axis
                fullTimeAxis(geo: geo)
            }
            .clipShape(Rectangle())
        }
    }

    // MARK: - Chart Helpers

    private func drawIntervalBlocks(geo: GeometryProxy, maxWatts: Int,
                                     windowStart: Int, windowDuration: Int) -> some View {
        let blocks = computeIntervalBlocks(geoWidth: geo.size.width, geoHeight: geo.size.height,
                                           maxWatts: maxWatts, windowStart: windowStart, windowDuration: windowDuration)
        return ZStack(alignment: .topLeading) {
            ForEach(blocks) { block in
                Rectangle()
                    .fill(block.color)
                    .frame(width: block.width, height: block.height)
                    .position(x: block.x + block.width / 2, y: geo.size.height - block.height / 2)
            }
        }
        .frame(width: geo.size.width, height: geo.size.height)
    }

    private struct IntervalBlock: Identifiable {
        let id: Int
        let x: Double
        let width: Double
        let height: Double
        let color: Color
    }

    private func computeIntervalBlocks(geoWidth: Double, geoHeight: Double,
                                        maxWatts: Int, windowStart: Int, windowDuration: Int) -> [IntervalBlock] {
        var blocks: [IntervalBlock] = []
        var runningStart = 0
        for (index, interval) in plan.intervals.enumerated() {
            let intStart = runningStart
            let intEnd = intStart + interval.durationSeconds
            runningStart = intEnd

            let visStart = max(intStart, windowStart)
            let visEnd = min(intEnd, windowStart + windowDuration)
            guard visEnd > visStart else { continue }

            let x = geoWidth * Double(visStart - windowStart) / Double(windowDuration)
            let w = geoWidth * Double(visEnd - visStart) / Double(windowDuration)
            let watts = Double(interval.targetWatts)
            let h = geoHeight * watts / Double(maxWatts)
            let opacity: Double = index == currentIntervalIndex ? 0.8 : 0.5
            let color = colorForPower(interval.powerFraction).opacity(opacity)

            blocks.append(IntervalBlock(id: index, x: x, width: max(w, 1), height: max(h, 1), color: color))
        }
        return blocks
    }

    private func ftpLine(geo: GeometryProxy, maxWatts: Int, ftp: Int) -> some View {
        let y = geo.size.height * (1.0 - Double(ftp) / Double(maxWatts))
        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: geo.size.width, y: y))
            }
            .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

            Text("FTP \(ftp)")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
                .position(x: geo.size.width - 25, y: y - 8)
        }
    }

    private func powerTracePath(geo: GeometryProxy, maxWatts: Int,
                                 windowStart: Int, windowDuration: Int) -> some View {
        // 5-second rolling average for smooth power line (like TrainerRoad)
        let smoothed = smoothedPowerTrace(window: 5)
        return Path { path in
            var started = false
            for (i, power) in smoothed.enumerated() {
                if i < windowStart || i >= windowStart + windowDuration { continue }
                let x = geo.size.width * Double(i - windowStart) / Double(windowDuration)
                let y = geo.size.height * (1.0 - power / Double(maxWatts))
                let pt = CGPoint(x: x, y: max(0, min(geo.size.height, y)))
                if !started {
                    path.move(to: pt)
                    started = true
                } else {
                    path.addLine(to: pt)
                }
            }
        }
        .stroke(Color.yellow, lineWidth: 1.5)
    }

    private func smoothedPowerTrace(window: Int) -> [Double] {
        guard !powerTrace.isEmpty else { return [] }
        var result = [Double](repeating: 0, count: powerTrace.count)
        var sum = 0.0
        for i in 0..<powerTrace.count {
            sum += Double(powerTrace[i])
            if i >= window { sum -= Double(powerTrace[i - window]) }
            let count = min(i + 1, window)
            result[i] = sum / Double(count)
        }
        return result
    }

    private func yAxisLabels(geo: GeometryProxy, maxWatts: Int) -> some View {
        let steps = [100, 200, 300, 400].filter { $0 < maxWatts }
        return ForEach(steps, id: \.self) { watts in
            let y = geo.size.height * (1.0 - Double(watts) / Double(maxWatts))
            Text("\(watts)")
                .font(.system(size: 9))
                .foregroundStyle(.gray)
                .position(x: 16, y: y)
        }
    }

    private func timeAxis(geo: GeometryProxy, windowStart: Int, windowDuration: Int) -> some View {
        let stepSec = max(15, windowDuration / 5)
        let steps = stride(from: 0, through: windowDuration, by: stepSec)
        return ForEach(Array(steps), id: \.self) { sec in
            let x = geo.size.width * Double(sec) / Double(windowDuration)
            Text(formatTimeHMMSS(windowStart + sec))
                .font(.system(size: 8))
                .foregroundStyle(.gray)
                .position(x: x, y: geo.size.height - 6)
        }
    }

    private func fullTimeAxis(geo: GeometryProxy) -> some View {
        let dur = totalWorkoutDuration
        let stepSec = max(60, dur / 5)
        let steps = stride(from: 0, through: dur, by: stepSec)
        return ForEach(Array(steps), id: \.self) { sec in
            let x = geo.size.width * Double(sec) / Double(dur)
            Text(formatTimeHMMSS(sec))
                .font(.system(size: 8))
                .foregroundStyle(.gray)
                .position(x: x, y: geo.size.height - 6)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Text("INTENSITY")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(intensityPercent)%")
                .font(.title3.bold())
                .foregroundStyle(.white)
            Spacer()
            Text("DEVICES")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isTrainerConnected ? "1 Paired" : "0 Paired")
                .font(.subheadline.bold())
                .foregroundStyle(isTrainerConnected ? .green : .red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black)
    }

    // MARK: - Workout Control

    private func startWorkout() {
        isRunning = true
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
        setTargetPowerOnTrainer()
    }

    private func pauseWorkout() {
        isRunning = false
        isPaused = true
        timer?.invalidate()
        timer = nil
    }

    private func resumeWorkout() {
        isPaused = false
        isRunning = true
        zeroPowerSeconds = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
        setTargetPowerOnTrainer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func endWorkout() {
        if totalElapsedTime > 30 {
            saveWorkout(completed: false)
        }
        stopTimer()
        dismiss()
    }

    private func tick() {
        let power = Int(bluetooth.latestTrainerData.instantaneousPower)

        // Auto-resume when pedaling after pause
        if isPaused && power > 0 {
            resumeWorkout()
            return
        }

        // Auto-pause after 5 seconds of zero power (stopped pedaling)
        if power == 0 {
            zeroPowerSeconds += 1
            if zeroPowerSeconds >= 5 {
                isPaused = true
                powerTrace.append(0)
                return
            }
        } else {
            zeroPowerSeconds = 0
        }

        // Track stats
        let cadence = Int(bluetooth.latestTrainerData.instantaneousCadence)
        let hr = Int(bluetooth.currentHeartRate)

        powerTrace.append(power)

        if power > 0 {
            powerReadings.append(power)
            cadenceReadings.append(cadence)
            if hr > 0 { hrReadings.append(hr) }
            if power > maxPower { maxPower = power }
            if hr > maxHR { maxHR = hr }
            detailedData.append(WorkoutDataPoint(power: power, cadence: cadence, heartRate: hr))
        }

        totalElapsedTime += 1
        intervalTimeRemaining -= 1

        if intervalTimeRemaining <= 0 {
            nextInterval()
        }
    }

    private func nextInterval() {
        currentIntervalIndex += 1
        playIntervalBeep()
        if currentIntervalIndex >= plan.intervals.count {
            saveWorkout(completed: true)
            if plan.fileName.contains("ramp") {
                calculateVO2maxFromRampTest()
            }
            stopTimer()
            dismiss()
            return
        }
        if let interval = currentInterval {
            intervalTimeRemaining = interval.durationSeconds
        }
        setTargetPowerOnTrainer()
    }

    private func playIntervalBeep() {
        AudioServicesPlaySystemSound(1007)
    }

    private func calculateVO2maxFromRampTest() {
        guard detailedData.count >= 60 else { return }
        var maxOneMinPower = 0
        for i in 0...(detailedData.count - 60) {
            let oneMinSlice = detailedData[i..<(i + 60)]
            let avgPower = oneMinSlice.reduce(0) { $0 + $1.power } / 60
            maxOneMinPower = max(maxOneMinPower, avgPower)
        }
        if maxOneMinPower > 0 {
            UserSettings.shared.updateVO2max(from: maxOneMinPower)
        }
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

    private func setTargetPowerOnTrainer() {
        guard let interval = currentInterval else { return }
        let watts = Int16(Double(interval.targetWatts) * Double(intensityPercent) / 100.0)
        bluetooth.trainerService?.setTargetPower(watts: watts)
    }

    // MARK: - Formatting

    private func formatTimeMMSS(_ seconds: Int) -> String {
        let m = abs(seconds) / 60
        let s = abs(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func formatTimeHMMSS(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        return String(format: "%d:%02d:%02d", h, m, s)
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

// MARK: - Execution Metric

struct ExecutionMetric: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
