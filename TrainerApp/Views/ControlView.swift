import SwiftUI

/// Control modes for the trainer
enum ControlMode: String, CaseIterable {
    case erg = "ERG"
    case simulation = "SIM"
    case resistance = "RES"

    var description: String {
        switch self {
        case .erg: "Target Power (watts)"
        case .simulation: "Road Simulation (grade)"
        case .resistance: "Manual Resistance (%)"
        }
    }

    var icon: String {
        switch self {
        case .erg: "bolt.fill"
        case .simulation: "mountain.2.fill"
        case .resistance: "dial.low.fill"
        }
    }
}

/// Phase 2: Resistance control view
struct ControlView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var mode: ControlMode = .erg
    @State private var targetPower: Double = 100
    @State private var grade: Double = 0
    @State private var resistance: Double = 50
    @State private var isActive = false


    var body: some View {
        VStack(spacing: 16) {
            if bluetooth.trainerState != .ready {
                Spacer()
                ContentUnavailableView {
                    Label("No Trainer Connected", systemImage: "bicycle")
                } description: {
                    Text("Connect a trainer from the Devices tab to control resistance.")
                }
                Spacer()
            } else {
                // Live metrics bar
                LiveMetricsBar(data: bluetooth.latestTrainerData, hr: bluetooth.currentHeartRate)

                // Mode selector
                HStack(spacing: 8) {
                    ForEach(ControlMode.allCases, id: \.self) { m in
                        Button {
                            mode = m
                            isActive = false
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: m.icon)
                                    .font(.system(size: 16))
                                Text(m.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(mode == m ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                mode == m ? Color.orange : Color.clear,
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // Mode-specific control
                switch mode {
                case .erg:
                    ERGControl(targetPower: $targetPower, isActive: $isActive) {
                        sendERG()
                    }
                case .simulation:
                    SimControl(grade: $grade, isActive: $isActive) {
                        sendSimulation()
                    }
                case .resistance:
                    ResistanceControl(resistance: $resistance, isActive: $isActive) {
                        sendResistance()
                    }
                }

                Spacer()

                // Stop button
                if isActive {
                    Button {
                        stopTrainer()
                    } label: {
                        Label("STOP", systemImage: "stop.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.red, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Commands

    private func sendERG() {
        let watts = Int16(targetPower)
        bluetooth.trainerService?.setTargetPower(watts: watts)
        isActive = true
    }

    private func sendSimulation() {
        bluetooth.trainerService?.setSimulationParameters(grade: grade, windSpeed: 0, rollingResistance: 0.004, windResistance: 0.51)
        isActive = true
    }

    private func sendResistance() {
        bluetooth.trainerService?.setResistanceLevel(percent: resistance)
        isActive = true
    }

    private func stopTrainer() {
        bluetooth.trainerService?.setTargetPower(watts: 0)
        isActive = false
    }
}

// MARK: - Live Metrics Bar

struct LiveMetricsBar: View {
    let data: TrainerData
    let hr: UInt8

    var body: some View {
        HStack(spacing: 20) {
            MetricPill(value: "\(data.instantaneousPower)", unit: "W", icon: "bolt.fill", color: .orange)
            MetricPill(value: String(format: "%.0f", data.instantaneousCadence), unit: "rpm", icon: "arrow.trianglehead.2.counterclockwise", color: .blue)
            MetricPill(value: String(format: "%.1f", data.instantaneousSpeed), unit: "km/h", icon: "speedometer", color: .green)
            if hr > 0 || data.heartRate > 0 {
                MetricPill(value: "\(max(hr, data.heartRate))", unit: "bpm", icon: "heart.fill", color: .red)
            }
        }
        .padding(.horizontal)
    }
}

struct MetricPill: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ERG Mode

struct ERGControl: View {
    @Binding var targetPower: Double
    @Binding var isActive: Bool
    let onApply: () -> Void

    let presets: [Int] = [50, 100, 125, 150, 175, 200, 250, 300, 350, 400]

    var body: some View {
        VStack(spacing: 16) {
            // Big power display
            Text("\(Int(targetPower))")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? .orange : .primary)
            Text("watts")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Slider
            VStack(spacing: 4) {
                Slider(value: $targetPower, in: 0...500, step: 5)
                    .tint(.orange)
                HStack {
                    Text("0W")
                    Spacer()
                    Text("500W")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            // Quick +/- buttons
            HStack(spacing: 12) {
                StepButton(label: "-25", color: .blue) { targetPower = max(0, targetPower - 25); onApply() }
                StepButton(label: "-10", color: .blue) { targetPower = max(0, targetPower - 10); onApply() }
                StepButton(label: "-5", color: .blue) { targetPower = max(0, targetPower - 5); onApply() }
                StepButton(label: "+5", color: .orange) { targetPower = min(500, targetPower + 5); onApply() }
                StepButton(label: "+10", color: .orange) { targetPower = min(500, targetPower + 10); onApply() }
                StepButton(label: "+25", color: .orange) { targetPower = min(500, targetPower + 25); onApply() }
            }
            .padding(.horizontal)

            // Presets
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(presets, id: \.self) { watts in
                    Button {
                        targetPower = Double(watts)
                        onApply()
                    } label: {
                        Text("\(watts)")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                Int(targetPower) == watts ? Color.orange : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(Int(targetPower) == watts ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            // Apply button
            Button {
                onApply()
            } label: {
                Text(isActive ? "UPDATE" : "SET POWER")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.orange, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Simulation Mode

struct SimControl: View {
    @Binding var grade: Double
    @Binding var isActive: Bool
    let onApply: () -> Void

    let gradePresets: [Double] = [-5, -2, 0, 2, 4, 6, 8, 10, 12, 15]

    var body: some View {
        VStack(spacing: 16) {
            // Big grade display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.1f", grade))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .green : .primary)
                Text("%")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            Text(gradeDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Slider
            VStack(spacing: 4) {
                Slider(value: $grade, in: -10...20, step: 0.5)
                    .tint(.green)
                HStack {
                    Text("-10%")
                    Spacer()
                    Text("20%")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            // Quick +/- buttons
            HStack(spacing: 12) {
                StepButton(label: "-2%", color: .blue) { grade = max(-10, grade - 2); onApply() }
                StepButton(label: "-1%", color: .blue) { grade = max(-10, grade - 1); onApply() }
                StepButton(label: "-0.5", color: .blue) { grade = max(-10, grade - 0.5); onApply() }
                StepButton(label: "+0.5", color: .green) { grade = min(20, grade + 0.5); onApply() }
                StepButton(label: "+1%", color: .green) { grade = min(20, grade + 1); onApply() }
                StepButton(label: "+2%", color: .green) { grade = min(20, grade + 2); onApply() }
            }
            .padding(.horizontal)

            // Presets
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(gradePresets, id: \.self) { g in
                    Button {
                        grade = g
                        onApply()
                    } label: {
                        Text(String(format: "%.0f%%", g))
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                grade == g ? Color.green : Color.clear,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(grade == g ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)

            Button {
                onApply()
            } label: {
                Text(isActive ? "UPDATE" : "SET GRADE")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }

    private var gradeDescription: String {
        switch grade {
        case ..<(-2): "Steep downhill"
        case -2..<0: "Gentle downhill"
        case 0: "Flat road"
        case 0..<4: "Gentle climb"
        case 4..<8: "Moderate climb"
        case 8..<12: "Steep climb"
        default: "Very steep climb"
        }
    }
}

// MARK: - Manual Resistance

struct ResistanceControl: View {
    @Binding var resistance: Double
    @Binding var isActive: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Big resistance display
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(Int(resistance))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? .purple : .primary)
                Text("%")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
            Text("resistance")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Slider
            VStack(spacing: 4) {
                Slider(value: $resistance, in: 0...100, step: 1)
                    .tint(.purple)
                HStack {
                    Text("0%")
                    Spacer()
                    Text("100%")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)

            // Quick +/- buttons
            HStack(spacing: 12) {
                StepButton(label: "-10", color: .blue) { resistance = max(0, resistance - 10); onApply() }
                StepButton(label: "-5", color: .blue) { resistance = max(0, resistance - 5); onApply() }
                StepButton(label: "-1", color: .blue) { resistance = max(0, resistance - 1); onApply() }
                StepButton(label: "+1", color: .purple) { resistance = min(100, resistance + 1); onApply() }
                StepButton(label: "+5", color: .purple) { resistance = min(100, resistance + 5); onApply() }
                StepButton(label: "+10", color: .purple) { resistance = min(100, resistance + 10); onApply() }
            }
            .padding(.horizontal)

            Button {
                onApply()
            } label: {
                Text(isActive ? "UPDATE" : "SET RESISTANCE")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.purple, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Shared Components

struct StepButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(color)
        }
        .buttonStyle(.plain)
    }
}
