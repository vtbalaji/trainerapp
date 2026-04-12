import SwiftUI
import PhotosUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

struct DietQualityView: View {
    @StateObject private var store = DietQualityStore()
    @State private var showCamera = false
    @State private var showFoodEntry = false
    @State private var selectedDate = Date()
    @State private var capturedImage: UIImage?
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showNoCameraAlert = false
    @State private var showMealPresets = false

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
            ScrollView {
                VStack(spacing: 10) {
                    // GDQS Score Card
                    GDQSScoreCard(result: gdqsResult)

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
                            showFoodEntry = true
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
                            showMealPresets = true
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
                            List {
                                ForEach(dayEntries) { entry in
                                    FoodEntryRow(entry: entry)
                                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        store.deleteEntry(dayEntries[index])
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .frame(minHeight: CGFloat(dayEntries.count) * 80)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(dateLabel)
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera, onDismiss: {
                if capturedImage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showFoodEntry = true
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
            .sheet(isPresented: $showFoodEntry) {
                AddFoodEntryView(store: store, capturedImage: capturedImage, selectedDate: selectedDate)
            }
            .sheet(isPresented: $showMealPresets) {
                MealPresetView(store: store, selectedDate: selectedDate)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        capturedImage = image
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        showFoodEntry = true
                    }
                }
            }
        }
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(MealPresets.all) { preset in
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

// MARK: - Food Entry Row

struct FoodEntryRow: View {
    let entry: FoodEntry

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
                HStack(spacing: 6) {
                    Text(entry.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.gdqsFoodGroup.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(entry.gdqsFoodGroup.color.opacity(0.2))
                        .cornerRadius(4)
                }
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
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .padding(.horizontal)
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
    @State private var recognizedFoods: [String] = []
    @State private var isRecognizing = false

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
                        Section("Suggested Foods") {
                            ForEach(recognizedFoods, id: \.self) { food in
                                Button {
                                    foodName = food
                                    if let (group, _) = IndianFoodDatabase.lookup(food) {
                                        selectedGroup = group
                                    }
                                } label: {
                                    HStack {
                                        Text(food.capitalized)
                                        Spacer()
                                        if foodName.lowercased() == food.lowercased() {
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
                recognizedFoods = foods.map { $0.name.capitalized }
                if recognizedFoods.isEmpty {
                    recognizedFoods = ["Could not identify food — enter manually"]
                }
            case .failure(let error):
                print("Recognition error: \(error.localizedDescription)")
                recognizedFoods = ["Recognition failed — enter manually"]
            }
        }
    }

    private func saveEntry() {
        let serving = Double(servingSize) ?? 100
        var finalNutrition = nutrition

        if finalNutrition.calories == 0 {
            finalNutrition = NutritionInfo(calories: 100, protein: 3, carbohydrates: 15, fiber: 2, sugar: 2, fat: 3, saturatedFat: 1, sodium: 200)
        }

        let entry = FoodEntry(
            name: foodName,
            category: selectedGroup,
            servingSize: serving,
            timestamp: selectedDate,
            imageData: capturedImage?.jpegData(compressionQuality: 0.5),
            nutritionInfo: finalNutrition,
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
