import SwiftUI

/// Live data dashboard showing real-time trainer metrics
struct DashboardView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var showLog = false

    var body: some View {
            VStack(spacing: 12) {
                // Connection bar
                HStack(spacing: 12) {
                    // Trainer badge
                    ConnectionBadge(
                        label: bluetooth.trainerPeripheralName ?? "Trainer",
                        detail: protocolLabel,
                        icon: "bicycle",
                        state: bluetooth.trainerState,
                        color: .blue
                    ) {
                        bluetooth.disconnectTrainer()
                    }

                    // HR badge
                    ConnectionBadge(
                        label: bluetooth.hrDeviceName.isEmpty ? "HR Monitor" : bluetooth.hrDeviceName,
                        detail: bluetooth.currentHeartRate > 0 ? "\(bluetooth.currentHeartRate) bpm" : nil,
                        icon: "heart.fill",
                        state: bluetooth.hrState,
                        color: .red
                    ) {
                        bluetooth.disconnectHR()
                    }
                }
                .padding(.horizontal)

                if bluetooth.trainerState == .ready {
                    let data = bluetooth.latestTrainerData

                    // Metrics grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        MetricCard(title: "Power", value: "\(data.instantaneousPower)", unit: "W",
                                   icon: "bolt.fill", color: .orange)
                        MetricCard(title: "Cadence", value: String(format: "%.0f", data.instantaneousCadence), unit: "RPM",
                                   icon: "arrow.trianglehead.2.counterclockwise", color: .blue)
                        MetricCard(title: "Speed", value: String(format: "%.1f", data.instantaneousSpeed), unit: "km/h",
                                   icon: "speedometer", color: .green)
                        MetricCard(title: "Heart Rate",
                                   value: bluetooth.currentHeartRate > 0 || data.heartRate > 0
                                       ? "\(max(bluetooth.currentHeartRate, data.heartRate))" : "--",
                                   unit: "BPM", icon: "heart.fill", color: .red)
                        MetricCard(title: "Distance", value: String(format: "%.2f", Double(data.totalDistance) / 1000.0), unit: "km",
                                   icon: "map.fill", color: .purple)
                        MetricCard(title: "Resistance", value: "\(data.resistanceLevel)", unit: "level",
                                   icon: "dial.low.fill", color: .gray)
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Elapsed time
                    let minutes = data.elapsedTime / 60
                    let seconds = data.elapsedTime % 60
                    Text(String(format: "%02d:%02d", minutes, seconds))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Debug log toggle
                    if showLog && !bluetooth.debugLog.isEmpty {
                        Divider()
                        DebugLogView(log: bluetooth.debugLog)
                            .frame(maxHeight: 180)
                    }
                } else {
                    Spacer()
                    ContentUnavailableView {
                        Label("No Trainer Connected", systemImage: "antenna.radiowaves.left.and.right.slash")
                    } description: {
                        Text("Connect to a trainer from the Devices tab.\nHR monitor can be connected independently.")
                    }
                    Spacer()
                }
            }
    }

    private var protocolLabel: String? {
        switch bluetooth.detectedProtocol {
        case .ftms: "FTMS"
        case .tacxFEC: "FE-C"
        case .unknown: nil
        }
    }
}

/// Badge showing connection state for a device
struct ConnectionBadge: View {
    let label: String
    let detail: String?
    let icon: String
    let state: ConnectionState
    let color: Color
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .lineLimit(1)
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Circle()
                .fill(stateColor)
                .frame(width: 6, height: 6)
            if state == .ready {
                Button {
                    onDisconnect()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var stateColor: Color {
        switch state {
        case .disconnected: .red
        case .connecting: .orange
        case .connected: .yellow
        case .ready: .green
        }
    }
}

/// A card displaying a single metric
struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
