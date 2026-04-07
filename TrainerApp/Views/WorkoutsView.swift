import SwiftUI

struct WorkoutsView: View {
    @StateObject private var store = WorkoutStore.shared
    @StateObject private var settings = UserSettings.shared
    @State private var selectedPlan: WorkoutPlan?
    @State private var selectedCategory: WorkoutCategory?
    
    var filteredPlans: [WorkoutPlan] {
        if let category = selectedCategory {
            return store.workouts(for: category)
        }
        return store.plans
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(nil as WorkoutCategory?)
                ForEach(WorkoutCategory.allCases, id: \.self) { category in
                    Label(category.rawValue, systemImage: category.icon)
                        .tag(category as WorkoutCategory?)
                }
            }
            .pickerStyle(.menu)
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
                }
            }
        }
        .sheet(item: $selectedPlan) { plan in
            WorkoutDetailView(plan: plan, ftp: settings.ftp)
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
                Text(plan.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !plan.description.isEmpty {
                Text(plan.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            WorkoutGraph(intervals: plan.intervals, ftp: ftp)
                .frame(height: 40)
        }
        .padding(.vertical, 4)
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
    @State private var showIntervals = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    WorkoutGraph(intervals: plan.intervals, ftp: ftp)
                        .frame(height: 100)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
            .navigationTitle(plan.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
