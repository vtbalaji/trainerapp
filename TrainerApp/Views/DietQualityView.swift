import SwiftUI
import PhotosUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct DietQualityView: View {
    @StateObject private var store = DietQualityStore()
    enum SheetType: Identifiable {
        case addFood, mealPresets
        var id: Self { self }
    }

    @State private var showCamera = false
    @State private var activeSheet: SheetType? = nil
    @State private var selectedDate = Date()
    @State private var capturedImage: UIImage?
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNoCameraAlert = false

    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            return selectedDate.formatted(.dateTime.day().month(.abbreviated))
        }
    }

    var gdqsResult: GDQSResult {
        store.calculateGDQS(for: store.entriesForDate(selectedDate))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 7-day GDQS strip — pinned below title
                WeeklyGDQSStrip(store: store, selectedDate: $selectedDate)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Button {
                            if CameraView.isAvailable {
                                AVCaptureDevice.requestAccess(for: .video) { granted in
                                    DispatchQueue.main.async {
                                        if granted { showCamera = true }
                                        else { showNoCameraAlert = true }
                                    }
                                }
                            } else { showNoCameraAlert = true }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "camera.fill")
                                Text("Camera")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                        }

                        Divider().frame(height: 28)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            VStack(spacing: 3) {
                                Image(systemName: "photo.fill")
                                Text("Photos")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                        }

                        Divider().frame(height: 28)

                        Button {
                            capturedImage = nil
                            activeSheet = .addFood
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                        }

                        Divider().frame(height: 28)

                        Button {
                            activeSheet = .mealPresets
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: "fork.knife")
                                Text("Meals")
                                    .font(.system(size: 9))
                            }
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6), in: Capsule())
                    .padding(.horizontal, 12)

                        // Daily Macro Summary
                        DailyMacroBar(entries: store.entriesForDate(selectedDate))

                        // Fasting Status
                        FastingCard(store: store, selectedDate: selectedDate)

                        // GDQS Score Card
                        GDQSScoreCard(result: gdqsResult)

                    // Today's Food Log
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Food Log")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.bottom, 8)

                        let dayEntries = store.entriesForDate(selectedDate)
                        if dayEntries.isEmpty {
                            Text("No food logged for this day")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                        } else {
                            ForEach(dayEntries) { entry in
                                FoodEntryRow(entry: entry, store: store)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            } // end outer VStack
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                if capturedImage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        activeSheet = .addFood
                    }
                }
            }) {
                CameraView(image: $capturedImage)
            }
            .alert("Camera Not Available", isPresented: $showNoCameraAlert) {
                Button("OK") {}
            } message: {
                Text("Camera access is not available. Please check Settings > Privacy > Camera.")
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addFood:
                    AddFoodEntryView(store: store, capturedImage: capturedImage, selectedDate: selectedDate)
                case .mealPresets:
                    MealPresetView(store: store, selectedDate: selectedDate)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        activeSheet = .addFood
                    }
                }
            }
        }
    }
}

// MARK: - Weekly GDQS Strip

struct WeeklyGDQSStrip: View {
    @ObservedObject var store: DietQualityStore
    @Binding var selectedDate: Date

    private let dayCount = 7

    private var days: [(date: Date, label: String)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<dayCount).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let label: String
            if offset == 0 {
                label = "Today"
            } else {
                label = date.formatted(.dateTime.weekday(.abbreviated))
            }
            return (date, label)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.date) { day in
                let entries = store.entriesForDate(day.date)
                let result = store.calculateGDQS(for: entries)
                let isSelected = Calendar.current.isDate(day.date, inSameDayAs: selectedDate)

                Button {
                    selectedDate = day.date
                } label: {
                    VStack(spacing: 4) {
                        Text(day.label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)

                        Text("\(Int(result.totalScore))")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(entries.isEmpty ? .secondary : scoreColor(result.totalScore))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(entries.isEmpty ? Color(.systemGray5) : scoreColor(result.totalScore).opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 23 { return .green }
        if score >= 15 { return .yellow }
        return .red
    }
}

// MARK: - GDQS Score Card

struct GDQSScoreCard: View {
    let result: GDQSResult

    var body: some View {
        VStack(spacing: 12) {
            // Score circle + risk/subtotals side by side
            HStack(spacing: 32) {
                // Score Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: result.totalScore / 49.0)
                        .stroke(result.riskColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: result.totalScore)

                    VStack(spacing: 1) {
                        Text("\(Int(result.totalScore))")
                            .font(.system(size: 36, weight: .bold))
                        Text("/ 49")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 110, height: 110)

                // Risk + Subtotals
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.riskCategory)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(result.riskColor)
                        .cornerRadius(12)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%g", result.gdqsPlus))
                                .font(.title3.weight(.bold))
                                .foregroundColor(result.gdqsPlus > 10 ? .green : .secondary)
                            Text("GDQS+")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%g", result.gdqsMinus))
                                .font(.title3.weight(.bold))
                                .foregroundColor(result.gdqsMinus >= 10 ? .green : .red)
                            Text("GDQS−")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)

            // Component Breakdown — only show groups with intake
            VStack(spacing: 0) {
                let eaten = result.groupScores.filter { $0.intakeGrams > 0 }
                let healthyEaten = eaten.filter { $0.foodGroup.gdqsCategory == .healthy }
                let moderateEaten = eaten.filter { $0.foodGroup.gdqsCategory == .unhealthyInExcess }
                let unhealthyEaten = eaten.filter { $0.foodGroup.gdqsCategory == .unhealthy }

                // Bonus from not eating unhealthy
                let unhealthySkipped = result.groupScores.filter { $0.foodGroup.gdqsCategory == .unhealthy && $0.intakeGrams == 0 }
                let skippedBonus = unhealthySkipped.reduce(0.0) { $0 + $1.score }
                if skippedBonus > 0 {
                    HStack {
                        Text("Bonus from avoided unhealthy foods")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("+\(String(format: "%g", skippedBonus))")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                }

                if !healthyEaten.isEmpty {
                    GDQSSectionHeader(title: "Healthy", color: .green)
                    ForEach(healthyEaten) { gs in
                        GDQSComponentRow(groupScore: gs)
                    }
                }

                if !moderateEaten.isEmpty {
                    GDQSSectionHeader(title: "Moderate", color: .yellow)
                    ForEach(moderateEaten) { gs in
                        GDQSComponentRow(groupScore: gs)
                    }
                }

                if !unhealthyEaten.isEmpty {
                    GDQSSectionHeader(title: "Limit", color: .red)
                    ForEach(unhealthyEaten) { gs in
                        GDQSComponentRow(groupScore: gs)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding(.horizontal, 8)
    }
}

// MARK: - Daily Macro Bar

struct DailyMacroBar: View {
    let entries: [FoodEntry]

    private var totals: (cal: Double, protein: Double, carbs: Double, fat: Double) {
        entries.reduce((0, 0, 0, 0)) { acc, e in
            (acc.0 + e.nutritionInfo.calories,
             acc.1 + e.nutritionInfo.protein,
             acc.2 + e.nutritionInfo.carbohydrates,
             acc.3 + e.nutritionInfo.fat)
        }
    }

    var body: some View {
        let t = totals
        HStack(spacing: 0) {
            MacroCell(value: t.cal, unit: "kcal", label: "Calories", color: .orange)
            Divider().frame(height: 32)
            MacroCell(value: t.protein, unit: "g", label: "Protein", color: .red)
            Divider().frame(height: 32)
            MacroCell(value: t.carbs, unit: "g", label: "Carbs", color: .blue)
            Divider().frame(height: 32)
            MacroCell(value: t.fat, unit: "g", label: "Fat", color: .yellow)
        }
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 8)
    }
}

private struct MacroCell: View {
    let value: Double
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value >= 1000 ? "\(Int(value / 1000)).\(Int(value.truncatingRemainder(dividingBy: 1000) / 100))k" : "\(Int(value))")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct GDQSSectionHeader: View {
    let title: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(color)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

struct GDQSComponentRow: View {
    let groupScore: GDQSGroupScore

    var body: some View {
        HStack(spacing: 6) {
            Text(groupScore.foodGroup.icon)
                .font(.caption2)
            Text(groupScore.foodGroup.rawValue)
                .font(.caption2)
                .lineLimit(1)
            Spacer()
            if groupScore.intakeGrams > 0 {
                Text("\(Int(groupScore.intakeGrams))g")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: groupScore.score, total: max(0.01, groupScore.foodGroup.maxScore))
                .frame(width: 50)
            Text(String(format: "%g", groupScore.score))
                .font(.caption2.monospacedDigit())
                .frame(width: 24, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}

// MARK: - Meal Preset View

struct MealPresetView: View {
    @ObservedObject var store: DietQualityStore
    let selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    @State private var added = false
    @State private var selectedCategory: MealPresetCategory? = nil

    private var filteredPresets: [MealPreset] {
        guard let category = selectedCategory else { return MealPresets.all }
        return MealPresets.all.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category filter
                HStack(spacing: 4) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("All")
                            .font(.system(size: 13, weight: selectedCategory == nil ? .bold : .medium))
                            .foregroundColor(selectedCategory == nil ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selectedCategory == nil ? Color.orange : Color(.systemGray5))
                            .cornerRadius(8)
                    }
                    ForEach(MealPresetCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            Text(category.rawValue)
                                .font(.system(size: 13, weight: selectedCategory == category ? .bold : .medium))
                                .foregroundColor(selectedCategory == category ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Color.orange : Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                List {
                    ForEach(filteredPresets) { preset in
                        Button {
                            store.addMealPreset(preset, date: selectedDate)
                            added = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Image(systemName: preset.icon)
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                    Text(preset.items.map { "\($0.name.capitalized) \(Int($0.servingSize))g" }.joined(separator: " + "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } // end VStack
            .navigationTitle("Meal Presets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if added {
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.green)
                        Text("Added!")
                            .font(.headline)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }
}

// MARK: - Fasting Card

struct FastingCard: View {
    @ObservedObject var store: DietQualityStore
    let selectedDate: Date

    private struct FastingInfo {
        let overnightFastHours: Double?   // last meal yesterday → first meal today
        let eatingWindowHours: Double?    // first meal → last meal today
        let firstMealToday: Date?
        let lastMealToday: Date?
        let lastMealYesterday: Date?
        let isFastingNow: Bool            // today only: no meals yet, timer running
        let liveFastHours: Double?        // if fasting now: hours since last meal
    }

    private var info: FastingInfo {
        let calendar = Calendar.current
        let todayEntries = store.entriesForDate(selectedDate)
            .sorted { $0.timestamp < $1.timestamp }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate)!
        let yesterdayEntries = store.entriesForDate(yesterday)
            .sorted { $0.timestamp < $1.timestamp }

        let firstToday = todayEntries.first?.timestamp
        let lastToday = todayEntries.last?.timestamp
        let lastYesterday = yesterdayEntries.last?.timestamp

        // Overnight fast: last meal yesterday → first meal today
        var overnightFast: Double? = nil
        if let ly = lastYesterday, let ft = firstToday {
            overnightFast = ft.timeIntervalSince(ly) / 3600.0
        }

        // Eating window: first → last meal today
        var eatingWindow: Double? = nil
        if let ft = firstToday, let lt = lastToday, todayEntries.count > 1 {
            eatingWindow = lt.timeIntervalSince(ft) / 3600.0
        }

        // Live fasting: today with no meals yet, counting from last known meal
        let isToday = calendar.isDateInToday(selectedDate)
        var isFasting = false
        var liveHours: Double? = nil
        if isToday && todayEntries.isEmpty, let ly = lastYesterday {
            isFasting = true
            liveHours = Date().timeIntervalSince(ly) / 3600.0
        }

        return FastingInfo(
            overnightFastHours: overnightFast,
            eatingWindowHours: eatingWindow,
            firstMealToday: firstToday,
            lastMealToday: lastToday,
            lastMealYesterday: lastYesterday,
            isFastingNow: isFasting,
            liveFastHours: liveHours
        )
    }

    private func zoneColor(_ hours: Double) -> Color {
        if hours >= 24 { return .blue }
        if hours >= 16 { return .green }
        if hours >= 12 { return .yellow }
        return .gray
    }

    private func zoneLabel(_ hours: Double) -> String {
        if hours >= 24 { return "Autophagy" }
        if hours >= 16 { return "Fat Burning" }
        if hours >= 12 { return "Fasting" }
        if hours >= 4 { return "Early Fast" }
        return "Fed"
    }

    private func formatHM(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    var body: some View {
        let f = info
        // Show card if: we have an overnight fast, or currently fasting, or have meals today
        let fastHours = f.liveFastHours ?? f.overnightFastHours
        let hasSomething = fastHours != nil || f.firstMealToday != nil

        if hasSomething {
            HStack(spacing: 12) {
                // Fasting circle
                if let hours = fastHours {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: min(1.0, hours / 24.0))
                            .stroke(zoneColor(hours), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(Int(hours))")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                            Text("hrs")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 44, height: 44)
                }

                VStack(alignment: .leading, spacing: 3) {
                    // Top line: zone label + context
                    if f.isFastingNow, let hours = f.liveFastHours {
                        HStack(spacing: 6) {
                            Text(zoneLabel(hours))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(zoneColor(hours))
                            if hours < 16 {
                                Text("fat burn in \(formatHM(16 - hours))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else if hours < 24 {
                                Text("autophagy in \(formatHM(24 - hours))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else if let hours = f.overnightFastHours {
                        HStack(spacing: 6) {
                            Text("Overnight Fast")
                                .font(.subheadline.weight(.semibold))
                            Text(formatHM(hours))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(zoneColor(hours))
                        }
                    }

                    // Meal times
                    HStack(spacing: 8) {
                        if let ly = f.lastMealYesterday {
                            HStack(spacing: 2) {
                                Image(systemName: "moon")
                                    .font(.system(size: 9))
                                Text(ly, format: .dateTime.hour().minute())
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        if let ft = f.firstMealToday {
                            HStack(spacing: 2) {
                                Image(systemName: "sunrise")
                                    .font(.system(size: 9))
                                Text(ft, format: .dateTime.hour().minute())
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    // Eating window on its own line
                    if let ew = f.eatingWindowHours {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text("Eating Window \(formatHM(ew))")
                                .font(.caption2)
                        }
                        .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

// MARK: - Food Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry
    @ObservedObject var store: DietQualityStore

    var body: some View {
        HStack(spacing: 12) {
            if let imageData = entry.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(entry.gdqsFoodGroup.icon)
                    .font(.title)
                    .frame(width: 50, height: 50)
                    .background(entry.gdqsFoodGroup.color.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(entry.gdqsFoodGroup.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(entry.gdqsFoodGroup.color.opacity(0.2))
                    .cornerRadius(4)
                HStack(spacing: 6) {
                    Text("\(Int(entry.servingSize))g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(entry.nutritionInfo.calories)) cal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.timestamp, format: .dateTime.hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // +/- serving adjustment
            VStack(spacing: 0) {
                Button {
                    store.adjustServing(entry, delta: 50)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 24)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)

                Button {
                    store.adjustServing(entry, delta: -50)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 28, height: 24)
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(6)
        }
        .padding(.leading)
        .padding(.vertical, 10)
        .padding(.trailing, 6)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .padding(.horizontal, 8)
        .contextMenu {
            Button(role: .destructive) {
                store.deleteEntry(entry)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Add Food Entry

struct AddFoodEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: DietQualityStore
    let capturedImage: UIImage?
    let selectedDate: Date

    @State private var foodName = ""
    @State private var pickedName = ""
    @State private var selectedGroup: GDQSFoodGroup = .other
    @State private var servingSize = "100"
    @State private var mealTime = Date()
    @State private var recognizedFoods: [RecognizedFood] = []
    @State private var isRecognizing = false
    @State private var expandedComboIndex: Int? = nil
    @State private var comboServingSizes: [Int: [Double]] = [:]  // comboIndex -> serving sizes per item

    var searchSuggestions: [(name: String, group: GDQSFoodGroup, nutrition: NutritionInfo)] {
        IndianFoodDatabase.search(foodName)
    }

    var nutrition: NutritionInfo {
        if let (_, nutrition) = IndianFoodDatabase.lookup(foodName) {
            return nutrition
        }
        return NutritionInfo()
    }

    var body: some View {
        NavigationStack {
            Form {
                if let image = capturedImage {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    }

                    if isRecognizing {
                        Section {
                            HStack {
                                ProgressView()
                                Text("Recognizing food...")
                            }
                        }
                    } else if !recognizedFoods.isEmpty {
                        // Combo meals
                        let combos = recognizedFoods.enumerated().filter { $0.element.isCombo }
                        if !combos.isEmpty {
                            Section("Meal Combos") {
                                ForEach(combos, id: \.offset) { idx, food in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Button {
                                            withAnimation {
                                                if expandedComboIndex == idx {
                                                    expandedComboIndex = nil
                                                } else {
                                                    expandedComboIndex = idx
                                                    if comboServingSizes[idx] == nil {
                                                        comboServingSizes[idx] = food.comboItems!.map { $0.servingSize }
                                                    }
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Image(systemName: "fork.knife.circle.fill")
                                                    .foregroundColor(.orange)
                                                Text(food.name)
                                                    .fontWeight(.medium)
                                                Spacer()
                                                Image(systemName: expandedComboIndex == idx ? "chevron.up" : "chevron.down")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .foregroundColor(.primary)

                                        if expandedComboIndex == idx, let items = food.comboItems {
                                            ForEach(Array(items.enumerated()), id: \.offset) { itemIdx, item in
                                                HStack {
                                                    Text(item.name.capitalized)
                                                        .font(.subheadline)
                                                    Spacer()
                                                    Button {
                                                        adjustComboServing(comboIdx: idx, itemIdx: itemIdx, delta: -50)
                                                    } label: {
                                                        Image(systemName: "minus.circle.fill")
                                                            .foregroundColor(.orange.opacity(0.8))
                                                    }
                                                    .buttonStyle(.plain)

                                                    Text("\(Int(comboServingSizes[idx]?[itemIdx] ?? item.servingSize))g")
                                                        .font(.subheadline.monospacedDigit())
                                                        .frame(width: 50, alignment: .center)

                                                    Button {
                                                        adjustComboServing(comboIdx: idx, itemIdx: itemIdx, delta: 50)
                                                    } label: {
                                                        Image(systemName: "plus.circle.fill")
                                                            .foregroundColor(.orange)
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                                .padding(.leading, 8)
                                            }

                                            Button {
                                                addComboWithAdjustedSizes(food, comboIdx: idx)
                                            } label: {
                                                Text("Add All Items")
                                                    .font(.subheadline.weight(.semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 8)
                                                    .background(Color.orange)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(8)
                                            }
                                            .padding(.top, 4)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        // Single items
                        let singles = recognizedFoods.enumerated().filter { !$0.element.isCombo }
                        if !singles.isEmpty {
                            Section("Individual Items") {
                                ForEach(singles, id: \.offset) { _, food in
                                    Button {
                                        foodName = food.name.capitalized
                                        if let (group, _) = IndianFoodDatabase.lookup(food.name) {
                                            selectedGroup = group
                                        }
                                    } label: {
                                        HStack {
                                            Text(food.name.capitalized)
                                            Spacer()
                                            Text("\(Int(food.confidence * 100))%")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if foodName.lowercased() == food.name.lowercased() {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                    }
                                    .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }

                Section("Food Details") {
                    TextField("Food Name", text: $foodName)
                        .autocapitalization(.words)
                        .autocorrectionDisabled()

                    if !foodName.isEmpty && !searchSuggestions.isEmpty && foodName != pickedName {
                        ForEach(searchSuggestions.prefix(6), id: \.name) { item in
                            Button {
                                foodName = item.name.capitalized
                                pickedName = foodName
                                selectedGroup = item.group
                            } label: {
                                HStack {
                                    Text(item.group.icon)
                                    Text(item.name.capitalized)
                                    Spacer()
                                    Text("\(Int(item.nutrition.calories)) cal")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }

                    Picker("Category", selection: $selectedGroup) {
                        // Healthy
                        Section("Healthy") {
                            ForEach(GDQSFoodGroup.allCases.filter { $0.gdqsCategory == .healthy }, id: \.self) { g in
                                Text("\(g.icon) \(g.rawValue)").tag(g)
                            }
                        }
                        // Moderate
                        Section("Moderate") {
                            ForEach(GDQSFoodGroup.allCases.filter { $0.gdqsCategory == .unhealthyInExcess }, id: \.self) { g in
                                Text("\(g.icon) \(g.rawValue)").tag(g)
                            }
                        }
                        // Unhealthy
                        Section("Limit") {
                            ForEach(GDQSFoodGroup.allCases.filter { $0.gdqsCategory == .unhealthy }, id: \.self) { g in
                                Text("\(g.icon) \(g.rawValue)").tag(g)
                            }
                        }
                        // Other
                        Text("\(GDQSFoodGroup.other.icon) \(GDQSFoodGroup.other.rawValue)").tag(GDQSFoodGroup.other)
                    }

                    HStack {
                        Text("Serving Size")
                        Spacer()
                        TextField("100", text: $servingSize)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("g")
                    }

                    DatePicker("Meal Time", selection: $mealTime, displayedComponents: .hourAndMinute)
                }

                Section("Nutrition (per 100g)") {
                    NutritionRow(label: "Calories", value: nutrition.calories, unit: "kcal")
                    NutritionRow(label: "Protein", value: nutrition.protein, unit: "g")
                    NutritionRow(label: "Carbs", value: nutrition.carbohydrates, unit: "g")
                    NutritionRow(label: "Fiber", value: nutrition.fiber, unit: "g")
                    NutritionRow(label: "Sugar", value: nutrition.sugar, unit: "g")
                    NutritionRow(label: "Fat", value: nutrition.fat, unit: "g")
                    NutritionRow(label: "Sodium", value: nutrition.sodium, unit: "mg")
                }
            }
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(foodName.isEmpty)
                }
            }
            .onAppear {
                // Default meal time: now if today, else noon for past dates
                let calendar = Calendar.current
                if calendar.isDateInToday(selectedDate) {
                    mealTime = Date()
                } else {
                    mealTime = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: selectedDate) ?? selectedDate
                }
                if capturedImage != nil {
                    simulateFoodRecognition()
                }
            }
            .onChange(of: foodName) { oldValue, newValue in
                if let (group, _) = IndianFoodDatabase.lookup(newValue) {
                    selectedGroup = group
                }
            }
        }
    }

    private func simulateFoodRecognition() {
        guard let image = capturedImage else { return }
        isRecognizing = true

        FoodRecognitionService.shared.recognizeFood(image: image) { result in
            isRecognizing = false
            switch result {
            case .success(let foods):
                if foods.isEmpty {
                    recognizedFoods = [RecognizedFood(name: "Could not identify food — enter manually", confidence: 0, comboItems: nil)]
                } else {
                    recognizedFoods = foods
                }
            case .failure(let error):
                print("Recognition error: \(error.localizedDescription)")
                recognizedFoods = [RecognizedFood(name: "Recognition failed — enter manually", confidence: 0, comboItems: nil)]
            }
        }
    }

    /// Combine selectedDate (day) with mealTime (hour/minute)
    private var entryTimestamp: Date {
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: mealTime)
        return calendar.date(bySettingHour: timeComponents.hour ?? 12,
                             minute: timeComponents.minute ?? 0,
                             second: 0,
                             of: selectedDate) ?? selectedDate
    }

    private func adjustComboServing(comboIdx: Int, itemIdx: Int, delta: Double) {
        guard var sizes = comboServingSizes[comboIdx] else { return }
        sizes[itemIdx] = max(50, sizes[itemIdx] + delta)
        comboServingSizes[comboIdx] = sizes
    }

    private func addComboWithAdjustedSizes(_ food: RecognizedFood, comboIdx: Int) {
        guard let items = food.comboItems else { return }
        let sizes = comboServingSizes[comboIdx] ?? items.map { $0.servingSize }
        for (i, item) in items.enumerated() {
            let serving = sizes[i]
            let lookup = IndianFoodDatabase.lookup(item.name)
            let group = lookup?.group ?? .other
            let per100 = lookup?.nutrition ?? NutritionInfo()
            let scale = serving / 100.0
            let scaled = NutritionInfo(
                calories: per100.calories * scale,
                protein: per100.protein * scale,
                carbohydrates: per100.carbohydrates * scale,
                fiber: per100.fiber * scale,
                sugar: per100.sugar * scale,
                fat: per100.fat * scale,
                saturatedFat: per100.saturatedFat * scale,
                sodium: per100.sodium * scale
            )
            let entry = FoodEntry(
                name: item.name.capitalized,
                category: group,
                servingSize: serving,
                timestamp: entryTimestamp,
                imageData: nil,
                nutritionInfo: scaled,
                confidence: 0.8
            )
            store.addEntry(entry)
        }
        dismiss()
    }

    private func saveEntry() {
        let serving = Double(servingSize) ?? 100
        var per100 = nutrition

        if per100.calories == 0 {
            per100 = NutritionInfo(calories: 100, protein: 3, carbohydrates: 15, fiber: 2, sugar: 2, fat: 3, saturatedFat: 1, sodium: 200)
        }

        let scale = serving / 100.0
        let scaled = NutritionInfo(
            calories: per100.calories * scale,
            protein: per100.protein * scale,
            carbohydrates: per100.carbohydrates * scale,
            fiber: per100.fiber * scale,
            sugar: per100.sugar * scale,
            fat: per100.fat * scale,
            saturatedFat: per100.saturatedFat * scale,
            sodium: per100.sodium * scale
        )

        let entry = FoodEntry(
            name: foodName,
            category: selectedGroup,
            servingSize: serving,
            timestamp: entryTimestamp,
            imageData: capturedImage?.jpegData(compressionQuality: 0.5),
            nutritionInfo: scaled,
            confidence: 0.8
        )

        store.addEntry(entry)
        dismiss()
    }
}

struct NutritionRow: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.1f %@", value, unit))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Camera

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
        } else {
            picker.sourceType = .photoLibrary
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    DietQualityView()
}
