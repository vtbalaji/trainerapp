import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

struct ScaleView: View {
    @EnvironmentObject var bluetooth: BluetoothManager
    @State private var isScanning = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var showCalibration = false

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
                let d = bluetooth.scaleData
                let gender = UserSettings.shared.gender
                let age = UserSettings.shared.age

                // Header card
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 2) {
                            Text(String(format: "%.2f", d.weight))
                                .font(.system(size: 32, weight: .bold))
                            Text("kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", d.bmi))
                                .font(.system(size: 32, weight: .bold))
                            Text("BMI")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(spacing: 2) {
                            Text(String(format: "%.1f", d.bodyFat))
                                .font(.system(size: 32, weight: .bold))
                            Text("Body Fat %")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // All metrics table (matching Fitdays order)
                Section {
                    ScaleMetricRow(label: "Weight", value: String(format: "%.2fkg", d.weight), rating: ScaleData.rating(for: d.weight, low: d.idealBodyWeight * 0.85, high: d.idealBodyWeight * 1.1), metricKey: .double(\.weight), unit: "kg")
                    ScaleMetricRow(label: "BMI", value: String(format: "%.1f", d.bmi), rating: ScaleData.bmiRating(d.bmi), metricKey: .double(\.bmi), unit: "")
                    ScaleMetricRow(label: "Body Fat", value: String(format: "%.1f%%", d.bodyFat), rating: ScaleData.bodyFatRating(d.bodyFat, gender: gender), metricKey: .double(\.bodyFat), unit: "%")
                    ScaleMetricRow(label: "Fat Mass", value: String(format: "%.1fkg", d.fatMass), rating: ScaleData.bodyFatRating(d.bodyFat, gender: gender), metricKey: .double(\.fatMass), unit: "kg")
                    ScaleMetricRow(label: "Fat-free Body Weight", value: String(format: "%.1fkg", d.fatFreeWeight), rating: "Standard", metricKey: .double(\.fatFreeWeight), unit: "kg")
                    ScaleMetricRow(label: "Muscle Mass", value: String(format: "%.1fkg", d.muscleMass), rating: ScaleData.rating(for: d.muscleRate, low: 70, high: 85), metricKey: .double(\.muscleMass), unit: "kg")
                    ScaleMetricRow(label: "Muscle Rate", value: String(format: "%.1f%%", d.muscleRate), rating: ScaleData.rating(for: d.muscleRate, low: 70, high: 85), metricKey: .double(\.muscleRate), unit: "%")
                    ScaleMetricRow(label: "Skeletal Muscle", value: String(format: "%.1f%%", d.skeletalMuscle), rating: ScaleData.rating(for: d.skeletalMuscle, low: 30, high: 55), metricKey: .double(\.skeletalMuscle), unit: "%")
                    ScaleMetricRow(label: "Bone Mass", value: String(format: "%.1fkg", d.boneMass), rating: "Standard", metricKey: .double(\.boneMass), unit: "kg")
                    ScaleMetricRow(label: "Protein Mass", value: String(format: "%.1fkg", d.proteinMass), rating: "Standard", metricKey: .double(\.proteinMass), unit: "kg")
                    ScaleMetricRow(label: "Protein", value: String(format: "%.1f%%", d.proteinRate), rating: ScaleData.rating(for: d.proteinRate, low: 10, high: 20), metricKey: .double(\.proteinRate), unit: "%")
                    ScaleMetricRow(label: "Water Weight", value: String(format: "%.1fkg", d.waterWeight), rating: "Standard", metricKey: .double(\.waterWeight), unit: "kg")
                    ScaleMetricRow(label: "Body Water", value: String(format: "%.1f%%", d.waterPercentage), rating: ScaleData.rating(for: d.waterPercentage, low: 50, high: 65), metricKey: .double(\.waterPercentage), unit: "%")
                    ScaleMetricRow(label: "Subcutaneous Fat", value: String(format: "%.1f%%", d.subcutaneousFat), rating: ScaleData.rating(for: d.subcutaneousFat, low: 5, high: 20), metricKey: .double(\.subcutaneousFat), unit: "%")
                    ScaleMetricRow(label: "Visceral Fat", value: String(format: "%.1f", d.visceralFat), rating: ScaleData.visceralFatRating(d.visceralFat), metricKey: .double(\.visceralFat), unit: "")
                    ScaleMetricRow(label: "BMR", value: "\(d.bmr)kcal", rating: "", metricKey: .int(\.bmr), unit: "kcal")
                    ScaleMetricRow(label: "Body Age", value: "\(d.bodyAge)", rating: ScaleData.bodyAgeRating(d.bodyAge, actualAge: age), metricKey: .int(\.bodyAge), unit: "")
                    ScaleMetricRow(label: "WHR", value: String(format: "%.2f", d.whr), rating: d.whr < 0.90 ? "Excellent" : "Standard", metricKey: .double(\.whr), unit: "")
                    ScaleMetricRow(label: "Ideal Body Weight", value: String(format: "%.1fkg", d.idealBodyWeight), rating: "", metricKey: .double(\.idealBodyWeight), unit: "kg")
                } header: {
                    HStack {
                        Text("Index")
                        Spacer()
                        Text("Value")
                            .frame(width: 80, alignment: .trailing)
                        Text("Standard")
                            .frame(width: 70, alignment: .trailing)
                    }
                    .font(.caption.bold())
                }

                // Weight Control
                Section {
                    HStack {
                        Text("Recommended Target")
                        Spacer()
                        Text(String(format: "%.1fkg", d.idealBodyWeight))
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("Weight Control")
                        Spacer()
                        Text(String(format: "%+.1fkg", d.weightControl))
                            .fontWeight(.medium)
                            .foregroundStyle(abs(d.weightControl) < 1 ? .green : .orange)
                    }
                    HStack {
                        Text("Fat Control")
                        Spacer()
                        Text(String(format: "%+.1fkg", d.fatControl))
                            .fontWeight(.medium)
                            .foregroundStyle(d.fatControl < 0 ? .orange : .green)
                    }
                    HStack {
                        Text("Muscle Control")
                        Spacer()
                        Text(String(format: "%+.1fkg", d.muscleControl))
                            .fontWeight(.medium)
                            .foregroundStyle(d.muscleControl > 0 ? .green : .orange)
                    }
                } header: {
                    Text("Weight Control")
                }

                // Segmental Analysis
                if d.hasSegmentalData {
                    Section {
                        SegmentRow(label: "Right Arm", segment: d.rightArm)
                        SegmentRow(label: "Left Arm", segment: d.leftArm)
                        SegmentRow(label: "Trunk", segment: d.trunk)
                        SegmentRow(label: "Right Leg", segment: d.rightLeg)
                        SegmentRow(label: "Left Leg", segment: d.leftLeg)
                    } header: {
                        Text("Segmental Fat Analysis")
                    } footer: {
                        Text("Standard range: 80%-160%. Shows fat mass (kg), % of ideal, and rating per segment.")
                            .font(.caption2)
                    }

                    Section {
                        SegmentMuscleRow(label: "Right Arm", segment: d.rightArm)
                        SegmentMuscleRow(label: "Left Arm", segment: d.leftArm)
                        SegmentMuscleRow(label: "Trunk", segment: d.trunk)
                        SegmentMuscleRow(label: "Right Leg", segment: d.rightLeg)
                        SegmentMuscleRow(label: "Left Leg", segment: d.leftLeg)
                    } header: {
                        Text("Muscle Balance")
                    } footer: {
                        Text("Standard range: Arms 80-115%, Trunk/Legs 90-110%.")
                            .font(.caption2)
                    }
                }

                // Share & Calibrate buttons
                Section {
                    Button {
                        shareBodyComposition()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Body Composition")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .listRowBackground(Color.purple)

                    Button {
                        showCalibration = true
                    } label: {
                        HStack {
                            Image(systemName: "scope")
                            Text("Calibrate Scale")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .listRowBackground(Color.blue)

                    if let timestamp = d.timestamp {
                        Text("Last updated: \(timestamp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            
        }
        .navigationTitle("Scale")
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .sheet(isPresented: $showCalibration) {
            ScaleCalibrationView(currentBodyFat: bluetooth.scaleData.bodyFat,
                                 currentWeight: bluetooth.scaleData.weight)
        }
        .onAppear {
            if bluetooth.scaleState == .disconnected {
                bluetooth.startScaleScan()
            }
        }
    }

    @MainActor
    private func shareBodyComposition() {
        let d = bluetooth.scaleData
        let settings = UserSettings.shared
        let renderer = ImageRenderer(content: ScaleShareCard(data: d, gender: settings.gender, age: settings.age))
        renderer.scale = 3.0  // Retina
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
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

// MARK: - Metric Key

enum ScaleMetricKey {
    case double(KeyPath<ScaleData, Double>)
    case int(KeyPath<ScaleData, Int>)

    func values(for period: ScaleHistoryPeriod, store: ScaleHistoryStore) -> [(date: Date, value: Double)] {
        switch self {
        case .double(let kp): return store.metricValues(period, keyPath: kp)
        case .int(let kp): return store.metricValuesInt(period, keyPath: kp)
        }
    }
}

// MARK: - Metric Row (Fitdays-style table)

struct ScaleMetricRow: View {
    let label: String
    let value: String
    let rating: String
    var metricKey: ScaleMetricKey? = nil
    var unit: String = ""
    @State private var showHistory = false

    var body: some View {
        Button {
            if metricKey != nil {
                showHistory = true
            }
        } label: {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 80, alignment: .trailing)
                Text(rating)
                    .font(.caption)
                    .foregroundStyle(ratingColor)
                    .frame(width: 70, alignment: .trailing)
                if metricKey != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            if let key = metricKey {
                ScaleMetricHistoryView(metricLabel: label, metricKey: key, unit: unit)
            }
        }
    }

    private var ratingColor: Color {
        switch rating {
        case "Standard": return .green
        case "Excellent": return .green
        case "Low", "High", "Overweight", "Above Average": return .orange
        case "Obese", "Very High", "Underweight": return .red
        default: return .secondary
        }
    }
}

// MARK: - Metric History View

struct ScaleMetricHistoryView: View {
    let metricLabel: String
    let metricKey: ScaleMetricKey
    let unit: String
    @StateObject private var store = ScaleHistoryStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: ScaleHistoryPeriod = .monthly

    private var dataPoints: [(date: Date, value: Double)] {
        metricKey.values(for: selectedPeriod, store: store)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Period filter
                HStack(spacing: 4) {
                    ForEach(ScaleHistoryPeriod.allCases, id: \.self) { period in
                        Button {
                            selectedPeriod = period
                        } label: {
                            Text(period.rawValue)
                                .font(.system(size: 13, weight: selectedPeriod == period ? .bold : .medium))
                                .foregroundColor(selectedPeriod == period ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedPeriod == period ? Color.purple : Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)

                if dataPoints.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No data for this period")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    // Chart
                    Chart {
                        ForEach(dataPoints, id: \.date) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value(metricLabel, point.value)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.purple)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value(metricLabel, point.value)
                            )
                            .foregroundStyle(Color.purple)
                            .annotation(position: .top, spacing: 4) {
                                Text(formatValue(point.value))
                                    .font(.caption2.bold())
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 220)
                    .padding(.horizontal)

                    // Entry list
                    List {
                        ForEach(dataPoints.reversed(), id: \.date) { point in
                            HStack {
                                Text(point.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                Spacer()
                                Text("\(formatValue(point.value))\(unit.isEmpty ? "" : " \(unit)")")
                                    .font(.subheadline.bold())
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(metricLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func formatValue(_ v: Double) -> String {
        if v == v.rounded() && v < 1000 {
            return String(format: "%.0f", v)
        }
        return String(format: "%.1f", v)
    }
}

// MARK: - Segmental Fat Row

struct SegmentRow: View {
    let label: String
    let segment: SegmentData

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fkg", segment.fatMass))
                    .fontWeight(.medium)
                Text(String(format: "%.1f%%", segment.fatPercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(segment.rating)
                    .font(.caption2)
                    .foregroundStyle(segment.rating == "Standard" ? .green : .orange)
            }
        }
    }
}

// MARK: - Segmental Muscle Row

struct SegmentMuscleRow: View {
    let label: String
    let segment: SegmentData

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1fkg", segment.muscleMass))
                    .fontWeight(.medium)
                Text(String(format: "%.1f%%", segment.musclePercent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(segment.rating)
                    .font(.caption2)
                    .foregroundStyle(segment.rating == "Standard" ? .green : .orange)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shareable Card (rendered to image)

struct ScaleShareCard: View {
    let data: ScaleData
    let gender: Gender
    let age: Int

    private let cardWidth: CGFloat = 390

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("TrainerApp")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))
                Text(data.timestamp?.formatted(date: .abbreviated, time: .shortened) ?? "")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", data.weight))
                            .font(.system(size: 28, weight: .bold))
                        Text("kg")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", data.bmi))
                            .font(.system(size: 28, weight: .bold))
                        Text("BMI")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f %%", data.bodyFat))
                            .font(.system(size: 28, weight: .bold))
                        Text("Body Fat")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .foregroundStyle(.white)
            .background(
                LinearGradient(colors: [Color.purple, Color.purple.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            // Metrics table
            VStack(spacing: 0) {
                // Table header
                shareTableHeader

                shareRow("Weight", String(format: "%.2fkg", data.weight), ScaleData.rating(for: data.weight, low: data.idealBodyWeight * 0.85, high: data.idealBodyWeight * 1.1))
                shareRow("BMI", String(format: "%.1f", data.bmi), ScaleData.bmiRating(data.bmi))
                shareRow("Body Fat", String(format: "%.1f%%", data.bodyFat), ScaleData.bodyFatRating(data.bodyFat, gender: gender))
                shareRow("Fat Mass", String(format: "%.1fkg", data.fatMass), ScaleData.bodyFatRating(data.bodyFat, gender: gender))
                shareRow("Fat-free Body Weight", String(format: "%.1fkg", data.fatFreeWeight), "Standard")
                shareRow("Muscle Mass", String(format: "%.1fkg", data.muscleMass), ScaleData.rating(for: data.muscleRate, low: 70, high: 85))
                shareRow("Muscle Rate", String(format: "%.1f%%", data.muscleRate), ScaleData.rating(for: data.muscleRate, low: 70, high: 85))
                shareRow("Skeletal Muscle", String(format: "%.1f%%", data.skeletalMuscle), ScaleData.rating(for: data.skeletalMuscle, low: 30, high: 55))
                shareRow("Bone Mass", String(format: "%.1fkg", data.boneMass), "Standard")
                shareRow("Protein Mass", String(format: "%.1fkg", data.proteinMass), "Standard")
                shareRow("Protein", String(format: "%.1f%%", data.proteinRate), ScaleData.rating(for: data.proteinRate, low: 10, high: 20))
                shareRow("Water Weight", String(format: "%.1fkg", data.waterWeight), "Standard")
                shareRow("Body Water", String(format: "%.1f%%", data.waterPercentage), ScaleData.rating(for: data.waterPercentage, low: 50, high: 65))
                shareRow("Subcutaneous Fat", String(format: "%.1f%%", data.subcutaneousFat), ScaleData.rating(for: data.subcutaneousFat, low: 5, high: 20))
                shareRow("Visceral Fat", String(format: "%.1f", data.visceralFat), ScaleData.visceralFatRating(data.visceralFat))
                shareRow("BMR", "\(data.bmr)kcal", "")
                shareRow("Body Age", "\(data.bodyAge)", ScaleData.bodyAgeRating(data.bodyAge, actualAge: age))
                shareRow("WHR", String(format: "%.2f", data.whr), data.whr < 0.90 ? "Excellent" : "Standard")
                shareRow("Ideal Body Weight", String(format: "%.1fkg", data.idealBodyWeight), "")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Weight Control
            VStack(spacing: 0) {
                Text("Weight Control")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 8)

                shareControlRow("Recommended Target", String(format: "%.1fkg", data.idealBodyWeight))
                shareControlRow("Weight Control", String(format: "%+.1fkg", data.weightControl))
                shareControlRow("Fat Control", String(format: "%+.1fkg", data.fatControl))
                shareControlRow("Muscle Control", String(format: "%+.1fkg", data.muscleControl))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Footer
            HStack {
                Text("TrainerApp")
                    .font(.caption.bold())
                    .foregroundStyle(.purple)
                Spacer()
                Text("Body Composition Report")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .frame(width: cardWidth)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var shareTableHeader: some View {
        HStack {
            Text("Index")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Spacer()
            Text("Value")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text("Standard")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func shareRow(_ label: String, _ value: String, _ rating: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 80, alignment: .trailing)
            Text(rating)
                .font(.system(size: 12))
                .foregroundStyle(shareRatingColor(rating))
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func shareControlRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
        }
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.5)
        }
    }

    private func shareRatingColor(_ rating: String) -> Color {
        switch rating {
        case "Standard", "Excellent": return .green
        case "Low", "High", "Overweight", "Above Average": return .orange
        case "Obese", "Very High", "Underweight": return .red
        default: return .secondary
        }
    }
}

// MARK: - Scale Calibration View

struct ScaleCalibrationView: View {
    let currentBodyFat: Double
    let currentWeight: Double
    @StateObject private var settings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var calibrationMethod = 0  // 0=Navy, 1=DEXA/Known
    @State private var neckCm: Double = 38
    @State private var waistCm: Double = 82
    @State private var hipCm: Double = 95  // for female
    @State private var knownBodyFat: Double = 18.0
    @State private var calibrated = false

    private var navyBodyFat: Double {
        let heightCm = settings.height
        guard heightCm > 0, waistCm > neckCm else { return 0 }
        if settings.gender == .male {
            // Male: 86.010 × log10(waist - neck) - 70.041 × log10(height) + 36.76
            return 86.010 * log10(waistCm - neckCm) - 70.041 * log10(heightCm) + 36.76
        } else {
            // Female: 163.205 × log10(waist + hip - neck) - 97.684 × log10(height) - 78.387
            return 163.205 * log10(waistCm + hipCm - neckCm) - 97.684 * log10(heightCm) - 78.387
        }
    }

    private var targetBodyFat: Double {
        calibrationMethod == 0 ? navyBodyFat : knownBodyFat
    }

    /// Calculate the FFM offset needed to match target body fat %
    private var requiredOffset: Double {
        guard currentWeight > 0, targetBodyFat > 0, targetBodyFat < 50 else { return 0 }
        // Target FFM = weight × (1 - targetBF/100)
        let targetFFM = currentWeight * (1.0 - targetBodyFat / 100.0)
        // Current FFM = weight × (1 - currentBF/100)
        let currentFFM = currentWeight * (1.0 - currentBodyFat / 100.0)
        // Offset = how much to add to FFM formula
        return targetFFM - currentFFM + settings.scaleCalibrationOffset
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Method", selection: $calibrationMethod) {
                        Text("Navy Method").tag(0)
                        Text("DEXA / Known BF%").tag(1)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Calibration Method")
                } footer: {
                    Text(calibrationMethod == 0
                         ? "Uses neck and waist measurements to calculate reference body fat %."
                         : "Enter a known body fat % from DEXA scan, calipers, or hydrostatic weighing.")
                }

                if calibrationMethod == 0 {
                    // Navy Method inputs
                    Section("Measurements") {
                        HStack {
                            Text("Neck")
                            Spacer()
                            TextField("cm", value: $neckCm, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("cm")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("Waist (at navel)")
                            Spacer()
                            TextField("cm", value: $waistCm, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("cm")
                                .foregroundStyle(.secondary)
                        }
                        if settings.gender == .female {
                            HStack {
                                Text("Hip (widest)")
                                Spacer()
                                TextField("cm", value: $hipCm, format: .number)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 60)
                                Text("cm")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section("Navy Method Result") {
                        HStack {
                            Text("Calculated Body Fat")
                            Spacer()
                            Text(String(format: "%.1f%%", navyBodyFat))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    // DEXA / Known input
                    Section("Reference Body Fat %") {
                        HStack {
                            Text("Known Body Fat")
                            Spacer()
                            TextField("%", value: $knownBodyFat, format: .number)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Comparison
                Section("Comparison") {
                    HStack {
                        Text("Current Scale Reading")
                        Spacer()
                        Text(String(format: "%.1f%%", currentBodyFat))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Reference Value")
                        Spacer()
                        Text(String(format: "%.1f%%", targetBodyFat))
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                    HStack {
                        Text("Difference")
                        Spacer()
                        let diff = currentBodyFat - targetBodyFat
                        Text(String(format: "%+.1f%%", diff))
                            .fontWeight(.bold)
                            .foregroundStyle(abs(diff) < 1 ? .green : .orange)
                    }
                }

                // Calibrate button
                Section {
                    Button {
                        settings.scaleCalibrationOffset = requiredOffset
                        calibrated = true
                    } label: {
                        HStack {
                            Image(systemName: "scope")
                            Text("Apply Calibration")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                    }
                    .listRowBackground(Color.blue)

                    if calibrated {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Calibration applied! Step on the scale again to see updated readings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if settings.scaleCalibrationOffset != 0 {
                        Button {
                            settings.scaleCalibrationOffset = 0
                            calibrated = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Reset Calibration")
                            }
                            .foregroundStyle(.red)
                        }
                    }
                } footer: {
                    Text("Calibration adjusts the lean mass estimate so body fat % matches your reference. All derived metrics (muscle, protein, water) update automatically.")
                }
            }
            .navigationTitle("Calibrate Scale")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
