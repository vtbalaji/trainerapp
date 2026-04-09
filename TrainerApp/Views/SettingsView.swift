import SwiftUI

/// Settings screen for managing saved devices and app configuration
struct SettingsView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @EnvironmentObject var store: SavedTrainerStore
    @State private var editingDevice: SavedDevice?
    @State private var editName: String = ""

    @State private var showDevices = false
    @StateObject private var userSettings = UserSettings.shared
    @StateObject private var strava = StravaService.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Scan for devices
                Section {
                    NavigationLink {
                        ScanView()
                    } label: {
                        HStack {
                            Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if bluetooth.trainerState == .ready {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Label("Connections", systemImage: "wifi")
                }
                
                // Saved trainers
                Section {
                    if store.savedTrainers.isEmpty {
                        Text("No saved trainers yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.savedTrainers) { device in
                            SavedDeviceRow(
                                device: device,
                                isConnected: bluetooth.trainerPeripheralID == device.id && bluetooth.trainerState == .ready,
                                onConnect: {
                                    bluetooth.reconnectTrainer(to: device.id, name: device.displayName)
                                },
                                onRename: { startRename(device) }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.remove(store.savedTrainers[index])
                            }
                        }
                    }
                } header: {
                    Label("Trainers", systemImage: "bicycle")
                }

                // Saved HR monitors
                Section {
                    if store.savedHRMonitors.isEmpty {
                        Text("No saved HR monitors yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.savedHRMonitors) { device in
                            SavedDeviceRow(
                                device: device,
                                isConnected: bluetooth.hrPeripheralID == device.id && bluetooth.hrState == .ready,
                                onConnect: {
                                    bluetooth.reconnectHR(to: device.id, name: device.displayName)
                                },
                                onRename: { startRename(device) }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.remove(store.savedHRMonitors[index])
                            }
                        }
                    }
                } header: {
                    Label("Heart Rate Monitors", systemImage: "heart.fill")
                }

                // Active connections
                if bluetooth.trainerState == .ready || bluetooth.hrState == .ready {
                    Section("Active Connections") {
                        if bluetooth.trainerState == .ready {
                            HStack {
                                Label(bluetooth.trainerPeripheralName ?? "Trainer", systemImage: "bicycle")
                                Spacer()
                                Text(protocolLabel).font(.caption).foregroundStyle(.secondary)
                                Button("Disconnect") { bluetooth.disconnectTrainer() }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        if bluetooth.hrState == .ready {
                            HStack {
                                Label("\(bluetooth.hrDeviceName) — \(bluetooth.currentHeartRate)bpm", systemImage: "heart.fill")
                                    .foregroundStyle(.red)
                                Spacer()
                                Button("Disconnect") { bluetooth.disconnectHR() }
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }

                // User Settings
                Section {
                    HStack {
                        Text("FTP")
                        Spacer()
                        TextField("FTP", value: $userSettings.ftp, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("W")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $userSettings.weight, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $userSettings.height, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Age")
                        Spacer()
                        TextField("Age", value: $userSettings.age, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("years")
                            .foregroundStyle(.secondary)
                    }
                    Picker("Gender", selection: $userSettings.gender) {
                        ForEach(Gender.allCases, id: \.self) { g in
                            Text(g.rawValue).tag(g)
                        }
                    }
                    if userSettings.vo2max > 0 {
                        HStack {
                            Text("VO2max")
                            Spacer()
                            Text(String(format: "%.1f", userSettings.vo2max))
                                .foregroundStyle(.orange)
                            Text("ml/kg/min")
                                .foregroundStyle(.secondary)
                        }
                        if let date = userSettings.vo2maxDate {
                            Text("From ramp test on \(date.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Profile", systemImage: "person.fill")
                }
                
                // Power Zones
                Section {
                    PowerZoneRow(zone: "Z1 Recovery", range: "0-55%", watts: "0-\(Int(Double(userSettings.ftp) * 0.55))W", color: .gray)
                    PowerZoneRow(zone: "Z2 Endurance", range: "55-75%", watts: "\(Int(Double(userSettings.ftp) * 0.55))-\(Int(Double(userSettings.ftp) * 0.75))W", color: .blue)
                    PowerZoneRow(zone: "Z3 Tempo", range: "75-90%", watts: "\(Int(Double(userSettings.ftp) * 0.75))-\(Int(Double(userSettings.ftp) * 0.90))W", color: .green)
                    PowerZoneRow(zone: "Z4 Threshold", range: "90-105%", watts: "\(Int(Double(userSettings.ftp) * 0.90))-\(Int(Double(userSettings.ftp) * 1.05))W", color: .yellow)
                    PowerZoneRow(zone: "Z5 VO2max", range: "105-120%", watts: "\(Int(Double(userSettings.ftp) * 1.05))-\(Int(Double(userSettings.ftp) * 1.20))W", color: .orange)
                    PowerZoneRow(zone: "Z6 Anaerobic", range: "120-150%", watts: "\(Int(Double(userSettings.ftp) * 1.20))-\(Int(Double(userSettings.ftp) * 1.50))W", color: .red)
                    PowerZoneRow(zone: "Z7 Neuromuscular", range: ">150%", watts: ">\(Int(Double(userSettings.ftp) * 1.50))W", color: .purple)
                } header: {
                    Label("Power Zones", systemImage: "bolt.fill")
                }
                
                // Strava
                Section {
                    if strava.isConnected {
                        HStack {
                            Image(systemName: "figure.run")
                                .foregroundStyle(.orange)
                            Text(strava.athleteName)
                            Spacer()
                            Button("Disconnect") {
                                strava.disconnect()
                            }
                            .foregroundStyle(.red)
                            .font(.caption)
                        }
                    } else {
                        Button {
                            strava.connect()
                        } label: {
                            HStack {
                                Image(systemName: "link")
                                Text("Connect to Strava")
                            }
                        }
                    }
                    if let error = strava.lastError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Label("Strava", systemImage: "arrow.up.circle")
                }
                
                // About
                Section("About") {
                    LabeledContent("Version", value: "1.0")
                    LabeledContent("Protocols", value: "FTMS, Tacx FE-C, BLE HR")
                }
            }
            .sheet(isPresented: $strava.showAuthSheet) {
                StravaAuthView(strava: strava)
                    .frame(minWidth: 400, minHeight: 500)
            }
            .sheet(item: $editingDevice) { device in
                RenameSheet(
                    trainerName: device.displayName,
                    editName: $editName,
                    onSave: {
                        store.rename(device, to: editName)
                        editingDevice = nil
                    },
                    onCancel: { editingDevice = nil }
                )
            }
        }
    }

    private var protocolLabel: String {
        switch bluetooth.detectedProtocol {
        case .ftms: "FTMS"
        case .tacxFEC: "Tacx FE-C"
        case .unknown: "Unknown"
        }
    }

    private func startRename(_ device: SavedDevice) {
        editName = device.displayName
        editingDevice = device
    }
}

struct SavedDeviceRow: View {
    let device: SavedDevice
    let isConnected: Bool
    let onConnect: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(device.displayName)
                        .font(.headline)
                    if device.customName != nil {
                        Text("(\(device.name))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Text("Last: \(device.lastConnected.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Menu {
                    Button("Connect", action: onConnect)
                    Button("Rename", action: onRename)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct PowerZoneRow: View {
    let zone: String
    let range: String
    let watts: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(zone)
            Spacer()
            Text(watts)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct RenameSheet: View {
    let trainerName: String
    @Binding var editName: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Device Name", text: $editName)
            }
            .navigationTitle("Rename")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 150)
    }
}
