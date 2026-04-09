import SwiftUI

struct ScaleView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var isScanning = false
    
    var scales: [DiscoveredDevice] {
        bluetooth.discoveredDevices.filter { $0.deviceType == .scale }
    }
    
    var body: some View {
        List {
            // Connection Status
            Section {
                HStack {
                    Image(systemName: statusIcon)
                        .foregroundStyle(statusColor)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(statusText)
                            .font(.headline)
                        Text(statusDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if bluetooth.scaleState == .ready {
                        Button("Disconnect") {
                            bluetooth.disconnectScale()
                        }
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Connection")
            }
            
            // Scale Data
            if bluetooth.scaleData.hasData {
                Section {
                    ScaleDataRow(label: "Weight", value: String(format: "%.1f", bluetooth.scaleData.weight), unit: "kg", icon: "scalemass.fill")
                    ScaleDataRow(label: "BMI", value: String(format: "%.1f", bluetooth.scaleData.bmi), unit: "", icon: "person.fill")
                } header: {
                    Text("Weight")
                }
                
                Section {
                    ScaleDataRow(label: "Body Fat", value: String(format: "%.1f", bluetooth.scaleData.bodyFat), unit: "%", icon: "percent")
                    ScaleDataRow(label: "Fat Free Weight", value: String(format: "%.1f", bluetooth.scaleData.fatFreeWeight), unit: "kg", icon: "figure.walk")
                    ScaleDataRow(label: "Muscle Mass", value: String(format: "%.1f", bluetooth.scaleData.muscleMass), unit: "kg", icon: "figure.strengthtraining.traditional")
                    ScaleDataRow(label: "Skeletal Muscle", value: String(format: "%.1f", bluetooth.scaleData.skeletalMuscle), unit: "%", icon: "figure.arms.open")
                    ScaleDataRow(label: "Body Water", value: String(format: "%.1f", bluetooth.scaleData.waterPercentage), unit: "%", icon: "drop.fill")
                    ScaleDataRow(label: "Bone Mass", value: String(format: "%.1f", bluetooth.scaleData.boneMass), unit: "kg", icon: "figure.stand")
                    ScaleDataRow(label: "Protein Rate", value: String(format: "%.1f", bluetooth.scaleData.proteinRate), unit: "%", icon: "fork.knife")
                    ScaleDataRow(label: "Subcutaneous Fat", value: String(format: "%.1f", bluetooth.scaleData.subcutaneousFat), unit: "%", icon: "circle.dotted")
                } header: {
                    Text("Body Composition")
                }
                
                Section {
                    ScaleDataRow(label: "Standard Weight", value: String(format: "%.1f", bluetooth.scaleData.standardWeight), unit: "kg", icon: "target")
                    ScaleDataRow(label: "Health Score", value: "\(bluetooth.scaleData.healthScore)", unit: "/100", icon: "heart.text.square.fill")
                } header: {
                    Text("Health")
                }
                
                Section {
                    ScaleDataRow(label: "BMR", value: "\(bluetooth.scaleData.bmr)", unit: "kcal", icon: "flame.fill")
                    ScaleDataRow(label: "Metabolic Age", value: "\(bluetooth.scaleData.metabolicAge)", unit: "years", icon: "clock.fill")
                    ScaleDataRow(label: "Visceral Fat", value: "\(bluetooth.scaleData.visceralFat)", unit: "", icon: "heart.fill")
                    
                    if let timestamp = bluetooth.scaleData.timestamp {
                        Text("Last updated: \(timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Metabolism")
                } footer: {
                    Text("Calculated using BIA formulas with your profile settings.")
                        .font(.caption2)
                }
                
                // Segmental Analysis
                if bluetooth.scaleData.hasSegmentalData {
                    Section {
                        SegmentRow(label: "Right Arm", segment: bluetooth.scaleData.rightArm)
                        SegmentRow(label: "Left Arm", segment: bluetooth.scaleData.leftArm)
                        SegmentRow(label: "Trunk", segment: bluetooth.scaleData.trunk)
                        SegmentRow(label: "Right Leg", segment: bluetooth.scaleData.rightLeg)
                        SegmentRow(label: "Left Leg", segment: bluetooth.scaleData.leftLeg)
                    } header: {
                        Text("Segmental Analysis")
                    } footer: {
                        Text("Fat/Muscle % relative to ideal (100%). Normal range: Fat 80-120%, Muscle 90-110%.")
                            .font(.caption2)
                    }
                }
            }
            
            // Available Scales
            Section {
                if scales.isEmpty {
                    if isScanning {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Scanning for scales...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No scales found")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(scales) { device in
                        HStack {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(.purple)
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text("Signal: \(signalStrength(device.rssi))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if bluetooth.scalePeripheralID == device.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            } else {
                                Button("Connect") {
                                    bluetooth.connectScale(device)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
                
                Button {
                    isScanning = true
                    bluetooth.startScanning()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        isScanning = false
                    }
                } label: {
                    Label("Scan for Scales", systemImage: "arrow.clockwise")
                }
            } header: {
                Text("Available Scales")
            }
            
            // Debug Log
            Section {
                ForEach(bluetooth.debugLog.suffix(20).reversed(), id: \.self) { log in
                    Text(log)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Debug Log")
            }
        }
        .navigationTitle("Scale")
        .onAppear {
            // Auto-scan for scale when view appears
            if bluetooth.scaleState == .disconnected {
                bluetooth.startScaleScan()
            }
        }
    }
    
    private var statusIcon: String {
        switch bluetooth.scaleState {
        case .disconnected: return "scalemass"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .connected, .ready: return "scalemass.fill"
        }
    }
    
    private var statusColor: Color {
        switch bluetooth.scaleState {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected, .ready: return .green
        }
    }
    
    private var statusText: String {
        switch bluetooth.scaleState {
        case .disconnected: return "Not Connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .ready: return "Ready"
        }
    }
    
    private var statusDetail: String {
        switch bluetooth.scaleState {
        case .disconnected: return "Tap a scale below to connect"
        case .connecting: return "Please wait..."
        case .connected, .ready: return "Step on scale to measure"
        }
    }
    
    private func signalStrength(_ rssi: Int) -> String {
        switch rssi {
        case -50...0: return "Excellent"
        case -65...(-51): return "Good"
        case -80...(-66): return "Fair"
        default: return "Weak"
        }
    }
}

struct ScaleDataRow: View {
    let label: String
    let value: String
    let unit: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

struct SegmentRow: View {
    let label: String
    let segment: SegmentData
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 80, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Fat")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", segment.fatPercent))
                        .fontWeight(.medium)
                        .foregroundStyle(fatColor(segment.fatPercent))
                }
                HStack(spacing: 4) {
                    Text("Muscle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.0f%%", segment.musclePercent))
                        .fontWeight(.medium)
                        .foregroundStyle(muscleColor(segment.musclePercent))
                }
            }
        }
    }
    
    private func fatColor(_ percent: Double) -> Color {
        if percent < 90 { return .green }
        if percent <= 110 { return .primary }
        return .orange
    }
    
    private func muscleColor(_ percent: Double) -> Color {
        if percent >= 100 { return .green }
        if percent >= 90 { return .primary }
        return .orange
    }
}
