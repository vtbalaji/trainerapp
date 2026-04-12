import SwiftUI

struct WorkoutsView: View {
    @StateObject private var store = WorkoutStore.shared
    @StateObject private var settings = UserSettings.shared
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedCategory: WorkoutCategory?
    @State private var showCreateSheet = false
    @State private var showFavoritesOnly = false
    
    var filteredPlans: [WorkoutPlan] {
        var result = store.plans
        if showFavoritesOnly {
            result = store.favorites
        }
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category picker + Favorites + Add button
            HStack {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(nil as WorkoutCategory?)
                    ForEach(WorkoutCategory.allCases, id: \.self) { category in
                        Label(category.rawValue, systemImage: category.icon)
                            .tag(category as WorkoutCategory?)
                    }
                }
                .pickerStyle(.menu)
                
                Spacer()
                
                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .foregroundStyle(showFavoritesOnly ? .yellow : .secondary)
                }
                
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Workout list
            List {
                if filteredPlans.isEmpty {
                    Text("No workout plans found.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredPlans) { plan in
                        WorkoutPlanRow(plan: plan, ftp: settings.ftp)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedPlan = plan
                            }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteCustomPlan(filteredPlans[index])
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedPlan) { plan in
            WorkoutDetailView(plan: plan, ftp: settings.ftp)
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateWorkoutView(store: store)
        }
    }
}

struct WorkoutPlanRow: View {
    let plan: WorkoutPlan
    let ftp: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(plan.name)
                    .font(.headline)
                Spacer()
                Text(plan.formattedDurationLong)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(plan.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            WorkoutGraph(intervals: plan.intervals, ftp: ftp)
                .frame(height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                Label("\(plan.estimatedTSS)", systemImage: "bolt.fill")
                Label(plan.formattedIF, systemImage: "gauge.medium")
                Label("\(plan.estimatedKJ(ftp: ftp))kJ", systemImage: "flame.fill")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}



struct WorkoutGraph: View {
    let intervals: [WorkoutInterval]
    let ftp: Int
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1) {
                ForEach(intervals) { interval in
                    let width = geo.size.width * CGFloat(interval.durationSeconds) / CGFloat(totalDuration)
                    let height = geo.size.height * CGFloat(interval.powerFraction) / 1.2
                    
                    Rectangle()
                        .fill(colorForPower(interval.powerFraction))
                        .frame(width: max(width, 2), height: height)
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

struct WorkoutDetailView: View {
    let plan: WorkoutPlan
    let ftp: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = WorkoutStore.shared
    @State private var showIntervals = false
    @State private var showEditSheet = false
    @State private var copied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WorkoutGraph(intervals: plan.intervals, ftp: ftp)
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                
                List {
                Section {
                    // Description
                    if !plan.description.isEmpty {
                        Text(plan.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Estimated Load — compact row
                    HStack {
                        LoadStat(label: "Duration", value: plan.formattedDurationLong)
                        Divider()
                        LoadStat(label: "TSS", value: "\(plan.estimatedTSS)")
                        Divider()
                        LoadStat(label: "IF", value: plan.formattedIF)
                        Divider()
                        LoadStat(label: "KJ", value: "\(plan.estimatedKJ(ftp: ftp))")
                    }
                    .frame(maxWidth: .infinity)

                    // Shorthand with copy button
                    HStack {
                        Text(plan.generatedShorthand)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.orange)
                        Spacer()
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = plan.generatedShorthand
                            #else
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(plan.generatedShorthand, forType: .string)
                            #endif
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .foregroundStyle(copied ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    NavigationLink("Start Workout") {
                        WorkoutExecutionView(plan: plan)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .listRowBackground(Color.orange)
                }
                
                Section {
                    DisclosureGroup(isExpanded: $showIntervals) {
                        ForEach(plan.intervals) { interval in
                            HStack {
                                Text(interval.name)
                                Spacer()
                                Text(interval.formattedDuration)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(interval.powerFraction * 100))%")
                                    .frame(width: 50, alignment: .trailing)
                                Text("\(interval.targetWatts)W")
                                    .frame(width: 60, alignment: .trailing)
                                    .foregroundStyle(.orange)
                            }
                            .font(.system(.body, design: .monospaced))
                        }
                    } label: {
                        Text("Intervals (\(plan.intervals.count))")
                    }
                }
                }
            }
            .navigationTitle(plan.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            store.toggleFavorite(plan)
                        } label: {
                            Image(systemName: store.isFavorite(plan) ? "star.fill" : "star")
                                .foregroundStyle(store.isFavorite(plan) ? .yellow : .secondary)
                        }
                        if plan.fileName.hasPrefix("custom_") {
                            Button {
                                showEditSheet = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                EditWorkoutView(plan: plan, store: store, onSave: { dismiss() })
            }
        }
    }
}

// MARK: - Edit Workout View

struct EditWorkoutView: View {
    let plan: WorkoutPlan
    @ObservedObject var store: WorkoutStore
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var shorthand: String
    @State private var category: WorkoutCategory
    @State private var description: String
    @State private var parseError: String?
    @State private var previewIntervals: [WorkoutInterval]
    
    init(plan: WorkoutPlan, store: WorkoutStore, onSave: @escaping () -> Void) {
        self.plan = plan
        self.store = store
        self.onSave = onSave
        _name = State(initialValue: plan.name)
        _shorthand = State(initialValue: plan.shorthand.isEmpty ? plan.generatedShorthand : plan.shorthand)
        _category = State(initialValue: plan.category)
        _description = State(initialValue: plan.description)
        _previewIntervals = State(initialValue: plan.intervals)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(WorkoutCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    
                    TextField("Description", text: $description)
                } header: {
                    Text("Details")
                }
                
                Section {
                    TextField("Shorthand", text: $shorthand)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: shorthand) { _, newValue in
                            parseShorthand(newValue)
                        }
                    
                    if let error = parseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Shorthand Format")
                }
                
                if !previewIntervals.isEmpty {
                    Section("Preview") {
                        WorkoutGraph(intervals: previewIntervals, ftp: UserSettings.shared.ftp)
                            .frame(height: 60)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        
                        let totalMins = previewIntervals.reduce(0) { $0 + $1.durationSeconds } / 60
                        Text("Duration: \(totalMins) min • \(previewIntervals.count) intervals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(name.isEmpty || previewIntervals.isEmpty)
                }
            }
        }
    }
    
    private func parseShorthand(_ text: String) {
        guard !text.isEmpty else {
            previewIntervals = []
            parseError = nil
            return
        }
        
        if let intervals = ShorthandParser.parse(text) {
            previewIntervals = intervals
            parseError = nil
        } else {
            parseError = "Invalid format"
        }
    }
    
    private func saveWorkout() {
        store.updateCustomPlan(plan, name: name, description: description, shorthand: shorthand, category: category, intervals: previewIntervals)
        dismiss()
        onSave()
    }
}

// MARK: - Create Workout View

struct CreateWorkoutView: View {
    @ObservedObject var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var shorthand = ""
    @State private var category: WorkoutCategory = .threshold
    @State private var description = ""
    @State private var parseError: String?
    @State private var previewIntervals: [WorkoutInterval] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        ForEach(WorkoutCategory.allCases, id: \.self) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    TextField("Description (optional)", text: $description)
                } header: {
                    Text("Details")
                }
                
                Section {
                    TextField("W10m@50%,[I1m@110%,R0.5m@50%]x3,C10m@40%", text: $shorthand)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: shorthand) { _, newValue in
                            parseShorthand(newValue)
                        }
                    
                    if let error = parseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Shorthand Format")
                } footer: {
                    Text("W=Warmup, I=Interval, R=Recovery, S=Steady, C=Cooldown\nExample: W10m@50% = Warmup 10min at 50% FTP\n[I1m@110%,R0.5m@50%]x3 = 3 repeats")
                        .font(.caption2)
                }
                
                if !previewIntervals.isEmpty {
                    Section("Preview") {
                        WorkoutGraph(intervals: previewIntervals, ftp: UserSettings.shared.ftp)
                            .frame(height: 60)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        
                        let totalMins = previewIntervals.reduce(0) { $0 + $1.durationSeconds } / 60
                        Text("Duration: \(totalMins) min • \(previewIntervals.count) intervals")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("New Workout")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(name.isEmpty || previewIntervals.isEmpty)
                }
            }
        }
    }
    
    private func parseShorthand(_ text: String) {
        guard !text.isEmpty else {
            previewIntervals = []
            parseError = nil
            return
        }
        
        if let intervals = ShorthandParser.parse(text) {
            previewIntervals = intervals
            parseError = nil
            // Auto-classify category
            category = WorkoutCategory.classify(intervals: intervals)
        } else {
            previewIntervals = []
            parseError = "Invalid format"
        }
    }
    
    private func saveWorkout() {
        var plan = WorkoutPlan(
            name: name,
            description: description,
            intervals: previewIntervals,
            fileName: "custom_\(UUID().uuidString)"
        )
        plan.category = category
        plan.shorthand = shorthand
        store.addCustomPlan(plan)
        dismiss()
    }
}

// MARK: - Load Stat (compact column)

struct LoadStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
