import Foundation

// MARK: - Plan Goal

enum PlanGoal: String, CaseIterable, Codable {
    case base = "Base Building"
    case build = "Build Phase"
    case peak = "Peak / Race Prep"
    case general = "General Fitness"

    var description: String {
        switch self {
        case .base: return "Build aerobic foundation with endurance and tempo"
        case .build: return "Increase threshold power with structured intervals"
        case .peak: return "Sharpen fitness with race-specific intensity"
        case .general: return "Balanced mix of all training zones"
        }
    }

    var icon: String {
        switch self {
        case .base: return "figure.walk"
        case .build: return "flame.fill"
        case .peak: return "bolt.heart.fill"
        case .general: return "circle.grid.cross.fill"
        }
    }
}

// MARK: - Scheduled Workout

struct ScheduledWorkout: Identifiable, Codable {
    let id: UUID
    var date: Date
    var name: String
    var subtitle: String
    var shorthand: String
    var category: String  // WorkoutCategory rawValue
    var estimatedTSS: Int
    var estimatedMinutes: Int
    var difficulty: String  // "Easy", "Moderate", "Hard", "Very Hard"
    var completed: Bool
    var sessionId: UUID?
    var notes: String?

    init(date: Date, name: String, subtitle: String = "", shorthand: String, category: WorkoutCategory, estimatedTSS: Int, estimatedMinutes: Int, difficulty: String = "Moderate") {
        self.id = UUID()
        self.date = date
        self.name = name
        self.subtitle = subtitle
        self.shorthand = shorthand
        self.category = category.rawValue
        self.estimatedTSS = estimatedTSS
        self.estimatedMinutes = estimatedMinutes
        self.difficulty = difficulty
        self.completed = false
    }

    var workoutCategory: WorkoutCategory {
        WorkoutCategory(rawValue: category) ?? .endurance
    }
}

// MARK: - Training Plan

struct TrainingPlan: Identifiable, Codable {
    let id: UUID
    var name: String
    var goal: String  // PlanGoal rawValue
    var startDate: Date
    var weeks: Int
    var daysPerWeek: Int
    var maxHoursPerWeek: Double
    var trainingDays: [Int]  // 1=Sun, 2=Mon, ..., 7=Sat
    var scheduledWorkouts: [ScheduledWorkout]
    var createdDate: Date

    init(name: String, goal: PlanGoal, startDate: Date, weeks: Int, daysPerWeek: Int, maxHoursPerWeek: Double, trainingDays: [Int]) {
        self.id = UUID()
        self.name = name
        self.goal = goal.rawValue
        self.startDate = startDate
        self.weeks = weeks
        self.daysPerWeek = daysPerWeek
        self.maxHoursPerWeek = maxHoursPerWeek
        self.trainingDays = trainingDays
        self.scheduledWorkouts = []
        self.createdDate = Date()
    }

    var planGoal: PlanGoal {
        PlanGoal(rawValue: goal) ?? .general
    }

    var endDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: startDate) ?? startDate
    }

    var completedCount: Int {
        scheduledWorkouts.filter { $0.completed }.count
    }

    var totalCount: Int {
        scheduledWorkouts.count
    }

    var progressPercent: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    func workouts(for date: Date) -> [ScheduledWorkout] {
        let calendar = Calendar.current
        return scheduledWorkouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func weekNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: calendar.startOfDay(for: date)).day ?? 0
        return (days / 7) + 1
    }

    func weekTSS(weekNum: Int) -> Int {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekNum - 1, to: startDate) else { return 0 }
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { return 0 }

        return scheduledWorkouts
            .filter { $0.date >= weekStart && $0.date < weekEnd }
            .reduce(0) { $0 + $1.estimatedTSS }
    }
}

// MARK: - Training Plan Store

class TrainingPlanStore: ObservableObject {
    static let shared = TrainingPlanStore()

    @Published var plans: [TrainingPlan] = []

    private let key = "trainingPlans"

    init() {
        load()
    }

    var activePlan: TrainingPlan? {
        let today = Date()
        return plans.first { $0.startDate <= today && $0.endDate >= today }
    }

    func save(_ plan: TrainingPlan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.insert(plan, at: 0)
        }
        persist()
    }

    func delete(_ plan: TrainingPlan) {
        plans.removeAll { $0.id == plan.id }
        persist()
    }

    func markWorkoutCompleted(planId: UUID, workoutId: UUID, sessionId: UUID?) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planId }),
              let workoutIndex = plans[planIndex].scheduledWorkouts.firstIndex(where: { $0.id == workoutId }) else { return }
        plans[planIndex].scheduledWorkouts[workoutIndex].completed = true
        plans[planIndex].scheduledWorkouts[workoutIndex].sessionId = sessionId
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TrainingPlan].self, from: data) else { return }
        plans = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(plans) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
