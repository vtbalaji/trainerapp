import SwiftUI

/// Device discovery and connection screen — supports trainer + HR connections
struct ScanView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var showDebugLog = false
    @State private var showOtherDevices = false

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            StatusBar(bluetooth: bluetooth)

            // Connection summary
            ConnectionSummary(bluetooth: bluetooth)

            // Options
            HStack {
                Toggle("Scan all devices", isOn: $bluetooth.scanAllDevices)
                    .font(.caption)
                Spacer()
                Button(showDebugLog ? "Hide Log" : "Show Log") {
                    showDebugLog.toggle()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)

            if showDebugLog && !bluetooth.debugLog.isEmpty {
                DebugLogView(log: bluetooth.debugLog)
            }

            if bluetooth.discoveredDevices.isEmpty && !bluetooth.isScanning {
                ContentUnavailableView {
                    Label("No Devices Found", systemImage: "bicycle")
                } description: {
                    Text("Make sure your trainer and HR monitor are powered on and not connected to another app.")
                } actions: {
                    Button("Scan for Devices") {
                        bluetooth.startScanning()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    let trainers = bluetooth.discoveredDevices.filter { $0.deviceType == .trainer }
                    if !trainers.isEmpty {
                        Section("Trainers") {
                            ForEach(trainers) { device in
                                DeviceRow(device: device, bluetooth: bluetooth)
                            }
                        }
                    }

                    let hrDevices = bluetooth.discoveredDevices.filter { $0.deviceType == .heartRate }
                    if !hrDevices.isEmpty {
                        Section("Heart Rate Monitors") {
                            ForEach(hrDevices) { device in
                                DeviceRow(device: device, bluetooth: bluetooth)
                            }
                        }
                    }
                    
                    let others = bluetooth.discoveredDevices.filter { $0.deviceType == .unknown }
                    if !others.isEmpty {
                        Section {
                            if showOtherDevices {
                                ForEach(others) { device in
                                    DeviceRow(device: device, bluetooth: bluetooth)
                                }
                            }
                        } header: {
                            Button {
                                withAnimation {
                                    showOtherDevices.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("Other Devices (\(others.count))")
                                    Spacer()
                                    Image(systemName: showOtherDevices ? "chevron.up" : "chevron.down")
                                }
                            }
                        }
                    }
                }
                .refreshable {
                    bluetooth.startScanning()
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                }
                #if os(iOS)
                .listStyle(.insetGrouped)
                #endif
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if bluetooth.isScanning {
                        bluetooth.stopScanning()
                    } else {
                        bluetooth.startScanning()
                    }
                } label: {
                    if bluetooth.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            bluetooth.startScanning()
        }
    }
}

// MARK: - Subviews

struct StatusBar: View {
    @ObservedObject var bluetooth: BluetoothManager

    var body: some View {
        HStack(spacing: 12) {
            // Trainer status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(stateColor(bluetooth.trainerState))
                    .frame(width: 8, height: 8)
                Text("Trainer")
                    .font(.caption2)
            }
            // HR status dot
            HStack(spacing: 4) {
                Circle()
                    .fill(stateColor(bluetooth.hrState))
                    .frame(width: 8, height: 8)
                Text("HR")
                    .font(.caption2)
            }
            Spacer()
            Text(bluetooth.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func stateColor(_ state: ConnectionState) -> Color {
        switch state {
        case .disconnected: .red
        case .connecting: .orange
        case .connected: .yellow
        case .ready: .green
        }
    }
}

struct ConnectionSummary: View {
    @ObservedObject var bluetooth: BluetoothManager

    var body: some View {
        if bluetooth.trainerState == .ready || bluetooth.hrState == .ready {
            HStack(spacing: 16) {
                if bluetooth.trainerState == .ready {
                    Label(bluetooth.trainerPeripheralName ?? "Trainer", systemImage: "bicycle")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.15), in: Capsule())
                }
                if bluetooth.hrState == .ready {
                    Label("\(bluetooth.hrDeviceName) \(bluetooth.currentHeartRate > 0 ? "\(bluetooth.currentHeartRate)bpm" : "")",
                          systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.red.opacity(0.1), in: Capsule())
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}

struct DeviceRow: View {
    let device: DiscoveredDevice
    @ObservedObject var bluetooth: BluetoothManager

    private var isTrainerConnected: Bool {
        bluetooth.trainerPeripheralID == device.id && bluetooth.trainerState == .ready
    }
    private var isHRConnected: Bool {
        bluetooth.hrPeripheralID == device.id && bluetooth.hrState == .ready
    }

    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .foregroundStyle(deviceColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                Text("Signal: \(signalStrength) | \(device.deviceType.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            if isTrainerConnected || isHRConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                // Show connect buttons based on device type
                Menu {
                    Button {
                        bluetooth.connectTrainer(to: device)
                    } label: {
                        Label("Connect as Trainer", systemImage: "bicycle")
                    }
                    Button {
                        bluetooth.connectHR(to: device)
                    } label: {
                        Label("Connect as HR Monitor", systemImage: "heart.fill")
                    }
                } label: {
                    Text("Connect")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 2)
    }

    private var deviceIcon: String {
        switch device.deviceType {
        case .trainer: "bicycle"
        case .heartRate: "heart.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var deviceColor: Color {
        switch device.deviceType {
        case .trainer: .blue
        case .heartRate: .red
        case .unknown: .gray
        }
    }

    private var signalStrength: String {
        switch device.rssi {
        case -50...0: "Excellent"
        case -65...(-51): "Good"
        case -80...(-66): "Fair"
        default: "Weak"
        }
    }
}

struct DebugLogView: View {
    let log: [String]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.enumerated()), id: \.offset) { idx, entry in
                        Text(entry)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .id(idx)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 150)
            .background(Color.black.opacity(0.1))
            .onChange(of: log.count) {
                if let last = log.indices.last {
                    proxy.scrollTo(last, anchor: .bottom)
                }
            }
        }
    }
}
