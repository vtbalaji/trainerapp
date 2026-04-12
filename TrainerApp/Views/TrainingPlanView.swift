import SwiftUI

// MARK: - Main Training Plan View

struct TrainingPlanView: View {
    @StateObject private var planStore = TrainingPlanStore.shared
    @State private var showWizard = false

    var body: some View {
        Group {
            if planStore.plans.isEmpty {
                ContentUnavailableView {
                    Label("No Training Plans", systemImage: "calendar.badge.plus")
                } description: {
                    Text("Create a structured training plan to reach your goals.")
                } actions: {
                    Button("Create Plan") {
                        showWizard = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
            } else {
                List {
                    ForEach(planStore.plans) { plan in
                        NavigationLink {
                            PlanCalendarView(plan: plan)
                        } label: {
                            PlanRowView(plan: plan)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            planStore.delete(planStore.plans[index])
                        }
                    }

                    Section {
                        Button {
                            showWizard = true
                        } label: {
                            Label("Create New Plan", systemImage: "plus.circle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showWizard) {
            PlanWizardView()
        }
    }
}

// MARK: - Plan Row

struct PlanRowView: View {
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: plan.planGoal.icon)
                    .foregroundStyle(.orange)
                Text(plan.name)
                    .font(.headline)
                Spacer()
                Text("\(plan.weeks)w")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.orange)
                        .frame(width: geo.size.width * plan.progressPercent)
                }
            }
            .frame(height: 6)

            HStack {
                Text(plan.planGoal.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(plan.completedCount)/\(plan.totalCount) workouts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Plan Wizard

struct PlanWizardView: View {
    @StateObject private var planStore = TrainingPlanStore.shared
    @StateObject private var historyStore = WorkoutHistoryStore.shared
    @StateObject private var settings = UserSettings.shared
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var planName = ""
    @State private var goal: PlanGoal = .general
    @State private var weeks = 8
    @State private var startDate = Date()
    @State private var selectedDays: Set<Int> = [2, 4, 6, 7]  // Mon, Wed, Fri, Sat
    @State private var dayHours: [Int: Double] = [2: 1.0, 4: 1.0, 6: 1.0, 7: 1.5]  // weekday -> hours

    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let weekOptions = [4, 6, 8, 12]

    var currentCTL: Int {
        Int(TrainingPlanGenerator.currentCTL(from: historyStore.sessions))
    }

    var totalWeeklyHours: Double {
        selectedDays.reduce(0) { $0 + (dayHours[$1] ?? 1.0) }
    }

    var body: some View {
        NavigationStack {
            VStack {
                // Step indicator
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= step ? Color.orange : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                TabView(selection: $step) {
                    // Step 1: Goal
                    goalStep.tag(0)
                    // Step 2: Schedule
                    scheduleStep.tag(1)
                    // Step 3: Training days
                    daysStep.tag(2)
                    // Step 4: Review
                    reviewStep.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                // Navigation buttons
                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < 3 {
                        Button("Next") { step += 1 }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                            .disabled(step == 0 && planName.isEmpty)
                    } else {
                        Button("Create Plan") { createPlan() }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                    }
                }
                .padding()
            }
            .navigationTitle("New Training Plan")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: Step 1 - Goal

    private var goalStep: some View {
        Form {
            Section("Plan Name") {
                TextField("e.g. Spring Build", text: $planName)
            }

            Section("Goal") {
                ForEach(PlanGoal.allCases, id: \.self) { g in
                    Button {
                        goal = g
                    } label: {
                        HStack {
                            Image(systemName: g.icon)
                                .frame(width: 30)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading) {
                                Text(g.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(g.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if goal == g {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Step 2 - Schedule

    private var scheduleStep: some View {
        Form {
            Section("Duration") {
                Picker("Weeks", selection: $weeks) {
                    ForEach(weekOptions, id: \.self) { w in
                        Text("\(w) weeks").tag(w)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Start Date") {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.orange)
            }

            Section {
                HStack {
                    Text("Total Weekly Hours")
                    Spacer()
                    Text(String(format: "%.1fh", totalWeeklyHours))
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // MARK: Step 3 - Training Days

    private var daysStep: some View {
        Form {
            Section {
                ForEach(0..<7, id: \.self) { i in
                    dayToggleRow(index: i)
                }
            } header: {
                Text("Select Training Days")
            } footer: {
                Text("\(selectedDays.count) days selected — \(String(format: "%.1f", totalWeeklyHours))h/week")
            }

            if !selectedDays.isEmpty {
                Section("Hours Per Day") {
                    ForEach(selectedDays.sorted(), id: \.self) { day in
                        HStack {
                            Text(dayNames[day - 1])
                                .frame(width: 40, alignment: .leading)
                            Slider(value: Binding(
                                get: { dayHours[day] ?? 1.0 },
                                set: { dayHours[day] = $0 }
                            ), in: 0.5...3.0, step: 0.5)
                                .tint(.orange)
                            Text(String(format: "%.1fh", dayHours[day] ?? 1.0))
                                .frame(width: 40)
                                .fontWeight(.medium)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Text("Current Fitness (CTL)")
                    Spacer()
                    Text("\(currentCTL)")
                        .fontWeight(.medium)
                        .foregroundStyle(.blue)
                }
                HStack {
                    Text("FTP")
                    Spacer()
                    Text("\(settings.ftp)W")
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Your Current Stats")
            } footer: {
                Text("The plan will use these to set appropriate training load.")
            }
        }
    }

    // MARK: Step 4 - Review

    private var reviewStep: some View {
        Form {
            Section("Plan Summary") {
                LabeledContent("Name", value: planName.isEmpty ? "Untitled" : planName)
                LabeledContent("Goal", value: goal.rawValue)
                LabeledContent("Duration", value: "\(weeks) weeks")
                LabeledContent("Start", value: startDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("Days/Week", value: "\(selectedDays.count)")
                LabeledContent("Weekly Hours", value: String(format: "%.1fh", totalWeeklyHours))
                ForEach(selectedDays.sorted(), id: \.self) { day in
                    LabeledContent("  \(dayNames[day - 1])", value: String(format: "%.1fh", dayHours[day] ?? 1.0))
                }
                LabeledContent("FTP", value: "\(settings.ftp)W")
                LabeledContent("Current CTL", value: "\(currentCTL)")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Periodization: 3 build + 1 recovery")
                    Text("TSS ramp: ~\(goal == .build ? "10" : "7-8")% per build week")
                    Text("Hard/easy day alternation enforced")
                    if goal == .peak {
                        Text("Taper in final 1-2 weeks")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Training Rules Applied")
            }
        }
    }

    @ViewBuilder
    private func dayToggleRow(index i: Int) -> some View {
        let dayNum = i + 1
        Button {
            if selectedDays.contains(dayNum) {
                selectedDays.remove(dayNum)
                dayHours.removeValue(forKey: dayNum)
            } else {
                selectedDays.insert(dayNum)
                dayHours[dayNum] = 1.0
            }
        } label: {
            HStack {
                Text(dayNames[i])
                    .foregroundStyle(.primary)
                Spacer()
                if selectedDays.contains(dayNum) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Create

    private func createPlan() {
        let name = planName.isEmpty ? "\(goal.rawValue) Plan" : planName
        let ctl = TrainingPlanGenerator.currentCTL(from: historyStore.sessions)

        let plan = TrainingPlanGenerator.generate(
            name: name,
            goal: goal,
            startDate: startDate,
            weeks: weeks,
            trainingDays: Array(selectedDays).sorted(),
            maxHoursPerWeek: totalWeeklyHours,
            dayHours: dayHours,
            ftp: settings.ftp,
            currentCTL: ctl
        )

        planStore.save(plan)
        dismiss()
    }
}

// MARK: - Calendar View

struct PlanCalendarView: View {
    let plan: TrainingPlan
    @StateObject private var planStore = TrainingPlanStore.shared
    @State private var selectedDate: Date = Date()
    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        List {
            // Week TSS summary
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(1...plan.weeks, id: \.self) { weekNum in
                            let tss = plan.weekTSS(weekNum: weekNum)
                            let isRecovery = weekNum % 4 == 0
                            VStack(spacing: 4) {
                                Text("W\(weekNum)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(tss)")
                                    .font(.caption.bold())
                                    .foregroundStyle(isRecovery ? .green : .orange)
                                Text("TSS")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(width: 44, height: 54)
                            .background(isRecovery ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Weekly Load")
            }

            // Calendar grid
            Section {
                calendarGrid
            } header: {
                Text("Schedule")
            }

            // Selected date workouts
            let workouts = plan.workouts(for: selectedDate)
            if !workouts.isEmpty {
                Section {
                    ForEach(workouts) { workout in
                        ScheduledWorkoutRow(workout: workout, plan: plan)
                    }
                } header: {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                }
            } else {
                Section {
                    Text("Rest day")
                        .foregroundStyle(.secondary)
                } header: {
                    Text(selectedDate.formatted(date: .complete, time: .omitted))
                }
            }

            // Progress
            Section {
                HStack {
                    Text("Progress")
                    Spacer()
                    Text("\(plan.completedCount)/\(plan.totalCount)")
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: plan.progressPercent)
                    .tint(.orange)
            }
        }
        .navigationTitle(plan.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            displayedMonth = max(plan.startDate, Date())
        }
    }

    // MARK: Calendar Grid

    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .fontWeight(.medium)
                Spacer()
                Button {
                    displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            // Day headers
            HStack(spacing: 0) {
                ForEach(dayNames, id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            let days = daysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        dayCell(date: date)
                    } else {
                        Text("")
                            .frame(height: 36)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayCell(date: Date) -> some View {
        let workouts = plan.workouts(for: date)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isInPlan = date >= plan.startDate && date <= plan.endDate

        return Button {
            selectedDate = date
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(isInPlan ? .primary : .tertiary)

                if !workouts.isEmpty {
                    HStack(spacing: 2) {
                        ForEach(workouts.prefix(2)) { w in
                            Circle()
                                .fill(categoryColor(w.workoutCategory))
                                .frame(width: 5, height: 5)
                                .overlay {
                                    if w.completed {
                                        Circle().stroke(Color.white, lineWidth: 1)
                                    }
                                }
                        }
                    }
                } else {
                    Spacer().frame(height: 5)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.orange.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isToday ? Color.orange : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.borderless)
    }

    private func daysInMonth() -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: displayedMonth)!
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)

        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)

        for day in range {
            if let date = calendar.date(bySetting: .day, value: day, of: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to complete last row
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func categoryColor(_ category: WorkoutCategory) -> Color {
        switch category {
        case .recovery: return .blue
        case .endurance: return .green
        case .tempo: return .yellow
        case .threshold: return .orange
        case .vo2max: return .red
        case .sprint: return .purple
        case .microBurst: return .cyan
        case .test: return .gray
        }
    }
}

// MARK: - Scheduled Workout Row

struct ScheduledWorkoutRow: View {
    let workout: ScheduledWorkout
    let plan: TrainingPlan
    @StateObject private var planStore = TrainingPlanStore.shared
    @State private var showDetail = false

    /// Convert scheduled workout shorthand into a WorkoutPlan for execution
    private var workoutPlan: WorkoutPlan? {
        guard let intervals = ShorthandParser.parse(workout.shorthand) else { return nil }
        var wp = WorkoutPlan(
            name: workout.name,
            description: "\(plan.name) — Week \(plan.weekNumber(for: workout.date))",
            intervals: intervals,
            fileName: "plan_\(workout.id.uuidString)"
        )
        wp.category = workout.workoutCategory
        wp.shorthand = workout.shorthand
        return wp
    }

    private var difficultyColor: Color {
        switch workout.difficulty {
        case "Easy": return .green
        case "Moderate": return .yellow
        case "Hard": return .orange
        case "Very Hard": return .red
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: name + completed check
            HStack {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundStyle(difficultyColor)
                Text(workout.name)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                if workout.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button {
                        planStore.markWorkoutCompleted(planId: plan.id, workoutId: workout.id, sessionId: nil)
                    } label: {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.bottom, 2)

            // Power profile graph
            if let intervals = ShorthandParser.parse(workout.shorthand) {
                WorkoutGraph(intervals: intervals, ftp: UserSettings.shared.ftp)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.bottom, 6)
            }

            // Subtitle + category
            Text(workout.subtitle.isEmpty ? workout.workoutCategory.rawValue : workout.subtitle)
                .font(.subheadline)
                .fontWeight(.medium)

            // Duration + TSS row
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text(formatDuration(workout.estimatedMinutes))
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("DURATION")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading) {
                    Text("\(workout.estimatedTSS)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("TSS")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, 4)

            // Difficulty tag
            HStack(spacing: 4) {
                Image(systemName: "diamond.fill")
                    .font(.caption2)
                    .foregroundStyle(difficultyColor)
                Text(workout.difficulty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)

            // Start button
            if !workout.completed, workoutPlan != nil {
                Button {
                    showDetail = true
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.borderless)
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showDetail) {
            if let wp = workoutPlan {
                NavigationStack {
                    WorkoutDetailView(plan: wp, ftp: UserSettings.shared.ftp)
                }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return String(format: "%d:%02d:00", h, m)
    }

    private func categoryColor(_ category: WorkoutCategory) -> Color {
        switch category {
        case .recovery: return .blue
        case .endurance: return .green
        case .tempo: return .yellow
        case .threshold: return .orange
        case .vo2max: return .red
        case .sprint: return .purple
        case .microBurst: return .cyan
        case .test: return .gray
        }
    }
}
