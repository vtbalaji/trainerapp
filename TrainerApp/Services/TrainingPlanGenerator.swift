import Foundation

/// Single rule-based function that generates a complete training plan.
/// All workout creation rules, periodization logic, and scheduling constraints live here.
struct TrainingPlanGenerator {

    // MARK: - Public API

    /// Generate a complete training plan based on user inputs and current fitness.
    /// This is the ONLY entry point — all rules are encoded within.
    static func generate(
        name: String,
        goal: PlanGoal,
        startDate: Date,
        weeks: Int,
        trainingDays: [Int],       // 1=Sun, 2=Mon, ..., 7=Sat
        maxHoursPerWeek: Double,
        dayHours: [Int: Double]? = nil,  // Optional per-day hours (key = weekday 1-7)
        ftp: Int,
        currentCTL: Double
    ) -> TrainingPlan {

        var plan = TrainingPlan(
            name: name,
            goal: goal,
            startDate: startDate,
            weeks: weeks,
            daysPerWeek: trainingDays.count,
            maxHoursPerWeek: maxHoursPerWeek,
            trainingDays: trainingDays
        )

        let calendar = Calendar.current

        // ── Step 1: Weekly TSS targets (periodization) ──────────────
        let baseTSS = startingWeeklyTSS(currentCTL: currentCTL, daysPerWeek: trainingDays.count, maxHours: maxHoursPerWeek)
        let weeklyTargets = weeklyTSSTargets(baseTSS: baseTSS, weeks: weeks, goal: goal)

        // ── Step 2: For each week, assign workout categories to days ─
        for weekNum in 0..<weeks {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekNum, to: startDate) else { continue }

            let isRecoveryWeek = isRecoveryWeek(weekNum: weekNum + 1, totalWeeks: weeks)
            let weekTSS = weeklyTargets[weekNum]

            // Get actual dates for this week's training days
            let dates = trainingDaysInWeek(weekStart: weekStart, trainingDays: trainingDays)
            guard !dates.isEmpty else { continue }

            // Assign categories based on goal, recovery week, and hard/easy rules
            let categories = assignCategories(
                dates: dates,
                goal: goal,
                isRecoveryWeek: isRecoveryWeek,
                weekNum: weekNum + 1,
                totalWeeks: weeks
            )

            // Get per-day hour allocations for weighting
            let dayMaxHoursList = dates.map { date -> Double in
                let wd = calendar.component(.weekday, from: date)
                return dayHours?[wd] ?? (maxHoursPerWeek / Double(trainingDays.count))
            }
            // Distribute TSS across days and generate workouts
            let tssPerDay = distributeTSS(weekTSS: weekTSS, categories: categories, dayHours: dayMaxHoursList)

            for i in 0..<dates.count {
                let category = categories[i]
                let targetTSS = tssPerDay[i]
                let weekday = calendar.component(.weekday, from: dates[i])
                let dayMaxHours = dayHours?[weekday] ?? (maxHoursPerWeek / Double(trainingDays.count))
                let maxMinutes = Int(dayMaxHours * 60)

                let workout = generateWorkout(
                    date: dates[i],
                    category: category,
                    targetTSS: targetTSS,
                    maxMinutes: maxMinutes,
                    weekNum: weekNum + 1,
                    isRecoveryWeek: isRecoveryWeek
                )
                plan.scheduledWorkouts.append(workout)
            }
        }

        return plan
    }

    // MARK: - Periodization Rules

    /// Calculate starting weekly TSS from current fitness
    private static func startingWeeklyTSS(currentCTL: Double, daysPerWeek: Int, maxHours: Double) -> Int {
        // CTL roughly equals daily TSS average, so weekly ≈ CTL × 7
        // Minimum 200 TSS/week for meaningful training stimulus
        let ctlBased = max(Int(currentCTL * 7), 200)
        // Hours-based: assume average IF ~0.70 → TSS/hr ≈ 49, so maxHours × 49
        let hoursBased = Int(maxHours * 49)

        return min(ctlBased, hoursBased)
    }

    /// Generate weekly TSS targets with 3:1 build/recovery periodization
    private static func weeklyTSSTargets(baseTSS: Int, weeks: Int, goal: PlanGoal) -> [Int] {
        let rampRate: Double
        switch goal {
        case .base: rampRate = 0.07     // 7% per build week
        case .build: rampRate = 0.10    // 10% per build week — aggressive
        case .peak: rampRate = 0.06     // 6% — sharpening
        case .general: rampRate = 0.08  // 8%
        }

        var targets: [Int] = []
        var buildWeekCount = 0

        for weekNum in 1...weeks {
            if isRecoveryWeek(weekNum: weekNum, totalWeeks: weeks) {
                // Recovery week: 60% of previous build week
                let lastBuild = targets.last ?? baseTSS
                targets.append(Int(Double(lastBuild) * 0.60))
            } else {
                buildWeekCount += 1
                let ramp = pow(1.0 + rampRate, Double(buildWeekCount - 1))
                targets.append(Int(Double(baseTSS) * ramp))
            }
        }

        // Peak plan: taper last 1-2 weeks
        if goal == .peak && weeks >= 6 {
            targets[weeks - 1] = Int(Double(targets[weeks - 2]) * 0.50)  // Race week
            if weeks >= 8 {
                targets[weeks - 2] = Int(Double(targets[weeks - 3]) * 0.70)  // Taper week
            }
        }

        return targets
    }

    /// Recovery week every 4th week (3:1 pattern), and last week of peak plans
    private static func isRecoveryWeek(weekNum: Int, totalWeeks: Int) -> Bool {
        weekNum % 4 == 0
    }

    // MARK: - Day Scheduling Rules

    /// Get actual dates for training days within a given week
    private static func trainingDaysInWeek(weekStart: Date, trainingDays: [Int]) -> [Date] {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: weekStart)  // 1=Sun

        var dates: [Date] = []
        for day in trainingDays.sorted() {
            var offset = day - weekday
            if offset < 0 { offset += 7 }
            if let date = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                dates.append(date)
            }
        }
        return dates.sorted()
    }

    /// Assign workout categories to training days following hard/easy rules
    private static func assignCategories(
        dates: [Date],
        goal: PlanGoal,
        isRecoveryWeek: Bool,
        weekNum: Int,
        totalWeeks: Int
    ) -> [WorkoutCategory] {

        let count = dates.count

        if isRecoveryWeek {
            return recoveryWeekCategories(count: count)
        }

        // Category mix based on goal
        let mix = categoryMix(goal: goal, daysPerWeek: count)

        // Arrange so hard days aren't consecutive
        return arrangeHardEasy(mix: mix, count: count)
    }

    /// Recovery week: all easy
    private static func recoveryWeekCategories(count: Int) -> [WorkoutCategory] {
        var cats: [WorkoutCategory] = []
        for i in 0..<count {
            if i == 0 {
                cats.append(.endurance)
            } else if i == count - 1 {
                cats.append(.endurance)
            } else {
                cats.append(.recovery)
            }
        }
        return cats
    }

    /// Define the weekly category mix based on plan goal
    private static func categoryMix(goal: PlanGoal, daysPerWeek: Int) -> [WorkoutCategory] {
        // These are ordered by priority — we take the first N matching daysPerWeek
        let fullMix: [WorkoutCategory]

        switch goal {
        case .base:
            // Endurance base + tempo + micro-bursts for neuromuscular activation
            fullMix = [.endurance, .tempo, .microBurst, .threshold, .endurance, .tempo, .recovery]
        case .build:
            // Threshold + VO2max + micro-bursts — high intensity focus
            fullMix = [.threshold, .microBurst, .vo2max, .endurance, .tempo, .threshold, .recovery]
        case .peak:
            // Race intensity: VO2max + sprint + micro-bursts + threshold
            fullMix = [.vo2max, .microBurst, .threshold, .sprint, .endurance, .vo2max, .recovery]
        case .general:
            // Balanced with micro-bursts
            fullMix = [.threshold, .microBurst, .endurance, .vo2max, .tempo, .endurance, .recovery]
        }

        // Take first N, ensuring we have enough
        var result: [WorkoutCategory] = []
        for i in 0..<daysPerWeek {
            result.append(fullMix[i % fullMix.count])
        }
        return result
    }

    /// Rearrange so hard days (threshold, VO2max, sprint) are never consecutive
    private static func arrangeHardEasy(mix: [WorkoutCategory], count: Int) -> [WorkoutCategory] {
        let hard: Set<WorkoutCategory> = [.threshold, .vo2max, .sprint, .microBurst]
        var hardDays = mix.filter { hard.contains($0) }
        var easyDays = mix.filter { !hard.contains($0) }

        var result: [WorkoutCategory] = Array(repeating: .endurance, count: count)
        var lastWasHard = false

        var i = 0
        while i < count {
            if !lastWasHard && !hardDays.isEmpty {
                result[i] = hardDays.removeFirst()
                lastWasHard = true
            } else if !easyDays.isEmpty {
                result[i] = easyDays.removeFirst()
                lastWasHard = false
            } else if !hardDays.isEmpty {
                // Force place remaining hard days
                result[i] = hardDays.removeFirst()
                lastWasHard = true
            }
            i += 1
        }
        return result
    }

    // MARK: - TSS Distribution

    /// Distribute weekly TSS across days based on category intensity and available hours
    private static func distributeTSS(weekTSS: Int, categories: [WorkoutCategory], dayHours: [Double]) -> [Int] {
        // Weight = category intensity × available hours for that day
        let weights = zip(categories, dayHours).map { categoryTSSWeight($0.0) * $0.1 }
        let totalWeight = weights.reduce(0, +)
        guard totalWeight > 0 else { return categories.map { _ in weekTSS / max(categories.count, 1) } }

        return weights.map { Int(Double(weekTSS) * ($0 / totalWeight)) }
    }

    /// Relative TSS weight for each category
    private static func categoryTSSWeight(_ category: WorkoutCategory) -> Double {
        switch category {
        case .recovery: return 0.5
        case .endurance: return 1.0
        case .tempo: return 1.4
        case .threshold: return 1.6
        case .vo2max: return 1.5
        case .sprint: return 1.0
        case .microBurst: return 1.3
        case .test: return 1.0
        }
    }

    // MARK: - Workout Generation Rules

    /// Generate a single workout as a ScheduledWorkout with shorthand
    /// ALL workout structure rules live here.
    private static func generateWorkout(
        date: Date,
        category: WorkoutCategory,
        targetTSS: Int,
        maxMinutes: Int,
        weekNum: Int,
        isRecoveryWeek: Bool
    ) -> ScheduledWorkout {

        let result = buildWorkout(
            category: category,
            targetTSS: targetTSS,
            maxMinutes: maxMinutes,
            isRecoveryWeek: isRecoveryWeek
        )

        // Calculate actual TSS from the generated shorthand intervals
        let actualTSS = tssFromShorthand(result.shorthand)

        // Difficulty based on IF (TSS per hour)
        let tssPerHour = result.minutes > 0 ? Double(actualTSS) / (Double(result.minutes) / 60.0) : 0
        let difficulty: String
        if tssPerHour < 45 { difficulty = "Easy" }
        else if tssPerHour < 65 { difficulty = "Moderate" }
        else if tssPerHour < 85 { difficulty = "Hard" }
        else { difficulty = "Very Hard" }

        return ScheduledWorkout(
            date: date,
            name: result.name,
            subtitle: result.subtitle,
            shorthand: result.shorthand,
            category: category,
            estimatedTSS: actualTSS,
            estimatedMinutes: result.minutes,
            difficulty: difficulty
        )
    }

    /// Calculate TSS from shorthand using Normalized Power (NP)
    /// NP uses 30-sec rolling average of power^4 to weight variability
    /// TSS = (duration_sec × NP × IF) / (FTP × 3600) × 100
    /// Since shorthand uses %FTP, we normalize with FTP=100 (NP in %FTP units)
    static func tssFromShorthand(_ shorthand: String) -> Int {
        guard let intervals = ShorthandParser.parse(shorthand) else { return 0 }
        return tssFromIntervals(intervals)
    }

    /// Calculate NP-based TSS from parsed intervals
    static func tssFromIntervals(_ intervals: [WorkoutInterval]) -> Int {
        // Build 1-second power stream (as fraction of FTP)
        var powerStream: [Double] = []
        for interval in intervals {
            let power = interval.powerFraction  // e.g. 0.90 for 90% FTP
            for _ in 0..<interval.durationSeconds {
                powerStream.append(power)
            }
        }

        guard powerStream.count >= 30 else {
            // Too short for NP, use simple calculation
            let totalSeconds = powerStream.count
            guard totalSeconds > 0 else { return 0 }
            let avgPower = powerStream.reduce(0, +) / Double(totalSeconds)
            let hours = Double(totalSeconds) / 3600.0
            return Int(round(hours * avgPower * avgPower * 100.0))
        }

        // 30-second rolling average raised to 4th power
        var sum30: Double = 0
        for i in 0..<30 { sum30 += powerStream[i] }

        var fourthPowerSum: Double = 0
        let count = powerStream.count - 29

        for i in 0..<count {
            if i > 0 {
                sum30 += powerStream[i + 29] - powerStream[i - 1]
            }
            let avg30 = sum30 / 30.0
            fourthPowerSum += avg30 * avg30 * avg30 * avg30
        }

        // NP = 4th root of mean of 4th powers (in FTP fraction units)
        let np = pow(fourthPowerSum / Double(count), 0.25)
        let totalSeconds = Double(powerStream.count)
        let hours = totalSeconds / 3600.0

        // TSS = hours × NP² × 100 (since NP is already in IF units when FTP=1.0)
        return Int(round(hours * np * np * 100.0))
    }

    /// Workout builder result
    private struct WorkoutResult {
        let name: String
        let subtitle: String
        let shorthand: String
        let minutes: Int
    }

    // Workout name pools for variety
    private static let recoveryNames = ["Recess", "Pettit", "Taku", "Lazy Mountain", "Carter"]
    private static let enduranceNames = ["Beech", "Boarstone", "Gibbs", "Fletcher", "Colosseum"]
    private static let tempoNames = ["Kaweah", "Ericsson", "Leavitt", "Donner", "Round Bald"]
    private static let sweetSpotNames = ["Slide Mountain", "Geiger", "Antelope", "Carson", "Wright Peak"]
    private static let thresholdNames = ["Auburn", "Lamarck", "Kaweah", "Darwin", "Dicks"]
    private static let overUnderNames = ["McAdie", "Palisade", "Tunemah", "Piute", "Reinstein"]
    private static let vo2maxNames = ["Baird", "Bashful", "Dade", "Kaiser", "Spencer"]
    private static let sprintNames = ["Wynne", "Xalibu", "Osceola", "Striped", "Gould"]
    private static let microBurstNames = ["Brasted", "Olancha", "Avery", "Birch", "Copperas"]

    /// Core workout builder — returns WorkoutResult with name, subtitle, shorthand, minutes
    /// This encodes ALL the rules for what a workout looks like per category.
    /// Calculates reps/duration to match targetTSS by accounting for warmup/cooldown overhead.
    private static func buildWorkout(
        category: WorkoutCategory,
        targetTSS: Int,
        maxMinutes: Int,
        isRecoveryWeek: Bool
    ) -> WorkoutResult {

        switch category {

        // ── Recovery: 30-45min steady at 40-55% FTP ──────────────
        case .recovery:
            let warmup = ("W5m@45%", tssForBlock(minutes: 5, ifactor: 0.45))
            let cooldown = ("C5m@40%", tssForBlock(minutes: 5, ifactor: 0.40))
            let overhead = warmup.1 + cooldown.1
            let steadyIF = 0.48
            let steadyMins = clamp(minutesForTSS(tss: Double(targetTSS) - overhead, ifactor: steadyIF), min: 15, max: 35)
            let total = steadyMins + 10
            return WorkoutResult(
                name: recoveryNames.randomElement()!,
                subtitle: "Active Recovery",
                shorthand: "\(warmup.0),S\(steadyMins)m@48%,\(cooldown.0)",
                minutes: total
            )

        // ── Endurance: 45-120min steady at 55-72% FTP ────────────
        case .endurance:
            let pct = isRecoveryWeek ? 58 : Int.random(in: 60...68)
            let steadyIF = Double(pct) / 100.0
            let warmup = ("W8m@50%", tssForBlock(minutes: 8, ifactor: 0.50))
            let cooldown = ("C7m@42%", tssForBlock(minutes: 7, ifactor: 0.42))
            let overhead = warmup.1 + cooldown.1
            let steadyMins = clamp(minutesForTSS(tss: Double(targetTSS) - overhead, ifactor: steadyIF), min: 25, max: min(105, maxMinutes - 15))
            let total = steadyMins + 15
            return WorkoutResult(
                name: enduranceNames.randomElement()!,
                subtitle: "Sustained Power",
                shorthand: "\(warmup.0),S\(steadyMins)m@\(pct)%,\(cooldown.0)",
                minutes: total
            )

        // ── Tempo: blocks of 10-20min at 76-85% FTP ─────────────
        case .tempo:
            let blockMins = Int.random(in: 10...15)
            let pct = Int.random(in: 76...82)
            let workIF = Double(pct) / 100.0
            let restIF = 0.50
            let warmup = ("W10m@50%", tssForBlock(minutes: 10, ifactor: 0.50))
            let cooldown = ("C7m@42%", tssForBlock(minutes: 7, ifactor: 0.42))
            let overhead = warmup.1 + cooldown.1
            let tssPerRep = tssForBlock(minutes: blockMins, ifactor: workIF) + tssForBlock(minutes: 3, ifactor: restIF)
            let reps = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerRep), min: 2, max: (maxMinutes - 17) / (blockMins + 3))
            let total = 17 + reps * (blockMins + 3)
            return WorkoutResult(
                name: tempoNames.randomElement()!,
                subtitle: "Tempo Intervals",
                shorthand: "\(warmup.0),[I\(blockMins)m@\(pct)%,R3m@50%]x\(reps),\(cooldown.0)",
                minutes: total
            )

        // ── Threshold / Sweet Spot / Over-Unders ─────────────────
        case .threshold:
            let variant = Int.random(in: 0...2)  // 0=sweet spot, 1=threshold, 2=over-unders

            if variant == 0 {
                // Sweet Spot
                let intervalMins = Int.random(in: 10...15)
                let pct = Int.random(in: 88...93)
                let workIF = Double(pct) / 100.0
                let warmup = ("W10m@50%", tssForBlock(minutes: 10, ifactor: 0.50))
                let cooldown = ("C7m@42%", tssForBlock(minutes: 7, ifactor: 0.42))
                let overhead = warmup.1 + cooldown.1
                let tssPerRep = tssForBlock(minutes: intervalMins, ifactor: workIF) + tssForBlock(minutes: 5, ifactor: 0.50)
                let maxReps = max(2, (maxMinutes - 17) / (intervalMins + 5))
                let reps = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerRep), min: 2, max: maxReps)
                let total = 17 + reps * (intervalMins + 5)
                return WorkoutResult(
                    name: sweetSpotNames.randomElement()!,
                    subtitle: "Intervals",
                    shorthand: "W10m@50%,[I\(intervalMins)m@\(pct)%,R5m@50%]x\(reps),C7m@42%",
                    minutes: total
                )
            } else if variant == 1 {
                // Threshold
                let intervalMins = Int.random(in: 8...12)
                let pct = Int.random(in: 95...102)
                let workIF = Double(pct) / 100.0
                let warmup = ("W10m@55%", tssForBlock(minutes: 10, ifactor: 0.55))
                let cooldown = ("C7m@42%", tssForBlock(minutes: 7, ifactor: 0.42))
                let overhead = warmup.1 + cooldown.1
                let tssPerRep = tssForBlock(minutes: intervalMins, ifactor: workIF) + tssForBlock(minutes: 5, ifactor: 0.55)
                let maxReps = max(2, (maxMinutes - 17) / (intervalMins + 5))
                let reps = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerRep), min: 2, max: maxReps)
                let total = 17 + reps * (intervalMins + 5)
                return WorkoutResult(
                    name: thresholdNames.randomElement()!,
                    subtitle: "Threshold Intervals",
                    shorthand: "W10m@55%,[I\(intervalMins)m@\(pct)%,R5m@55%]x\(reps),C7m@42%",
                    minutes: total
                )
            } else {
                // Over-Unders: 2min over / 2min under alternating
                let overPct = Int.random(in: 102...108)
                let underPct = Int.random(in: 88...94)
                let overIF = Double(overPct) / 100.0
                let underIF = Double(underPct) / 100.0
                let warmup = ("W10m@55%", tssForBlock(minutes: 10, ifactor: 0.55))
                let cooldown = ("C7m@42%", tssForBlock(minutes: 7, ifactor: 0.42))
                let overhead = warmup.1 + cooldown.1
                // Each set: 3x(2min over + 2min under) = 12min, then 5min rest
                let tssPerSet = tssForBlock(minutes: 6, ifactor: overIF) + tssForBlock(minutes: 6, ifactor: underIF) + tssForBlock(minutes: 5, ifactor: 0.50)
                let maxSets = max(2, (maxMinutes - 17) / 17)
                let sets = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerSet), min: 2, max: maxSets)
                let total = 17 + sets * 17
                return WorkoutResult(
                    name: overUnderNames.randomElement()!,
                    subtitle: "Over-Unders",
                    shorthand: "W10m@55%,[[I2m@\(overPct)%,I2m@\(underPct)%]x3,R5m@50%]x\(sets),C7m@42%",
                    minutes: total
                )
            }

        // ── VO2max: intervals of 2-5min at 106-120% FTP ─────────
        case .vo2max:
            let intervalMins = Int.random(in: 3...5)
            let recoveryMins = intervalMins  // 1:1 work:rest
            let pct = Int.random(in: 108...118)
            let workIF = Double(pct) / 100.0
            let warmup = ("W10m@55%", tssForBlock(minutes: 10, ifactor: 0.55))
            let cooldown = ("C8m@42%", tssForBlock(minutes: 8, ifactor: 0.42))
            let overhead = warmup.1 + cooldown.1
            let tssPerRep = tssForBlock(minutes: intervalMins, ifactor: workIF) + tssForBlock(minutes: recoveryMins, ifactor: 0.50)
            let maxReps = max(3, (min(65, maxMinutes) - 18) / (intervalMins + recoveryMins))
            let reps = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerRep), min: 3, max: maxReps)
            let total = 18 + reps * (intervalMins + recoveryMins)
            return WorkoutResult(
                name: vo2maxNames.randomElement()!,
                subtitle: "VO2max Intervals",
                shorthand: "\(warmup.0),[I\(intervalMins)m@\(pct)%,R\(recoveryMins)m@50%]x\(reps),\(cooldown.0)",
                minutes: total
            )

        // ── Micro-Bursts: 15-20sec at 150%+ within endurance ride ──
        // Develops neuromuscular power while building aerobic base
        // Structure: warmup, [burst,recovery]xN, endurance, [burst,recovery]xN, ..., cooldown
        case .microBurst:
            let burstSec = Int.random(in: 15...20)
            let burstFrac = Double(burstSec) / 60.0
            let burstMinsStr = String(format: "%.1fm", burstFrac)
            let burstRecoverySec = 10
            let burstRecoveryFrac = Double(burstRecoverySec) / 60.0
            let burstRecoveryStr = String(format: "%.1fm", burstRecoveryFrac)
            let burstPct = Int.random(in: 150...180)
            let burstIF = Double(burstPct) / 100.0
            let endurancePct = Int.random(in: 62...68)
            let enduranceIF = Double(endurancePct) / 100.0
            let warmup = ("W10m@50%", tssForBlock(minutes: 10, ifactor: 0.50))
            let cooldown = ("C8m@42%", tssForBlock(minutes: 8, ifactor: 0.42))
            let overhead = warmup.1 + cooldown.1
            let burstsPerSet = Int.random(in: 8...12)
            let enduranceBetweenMins = 5
            let tssPerBurst = tssForBlock(seconds: burstSec, ifactor: burstIF) + tssForBlock(seconds: burstRecoverySec, ifactor: 0.45)
            let tssPerSet = tssPerBurst * Double(burstsPerSet) + tssForBlock(minutes: enduranceBetweenMins, ifactor: enduranceIF)
            let maxSets = max(2, (min(75, maxMinutes) - 18) / (burstsPerSet * 1 + enduranceBetweenMins))
            let sets = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerSet), min: 2, max: maxSets)
            // Build flat shorthand: W, [bursts]xN, S, [bursts]xN, S, ..., C
            var parts: [String] = [warmup.0]
            for s in 0..<sets {
                parts.append("[I\(burstMinsStr)@\(burstPct)%,R\(burstRecoveryStr)@45%]x\(burstsPerSet)")
                if s < sets - 1 {
                    parts.append("S\(enduranceBetweenMins)m@\(endurancePct)%")
                }
            }
            parts.append(cooldown.0)
            let setMins = burstsPerSet * 1 + enduranceBetweenMins
            let mbTotal = 18 + sets * setMins
            return WorkoutResult(
                name: microBurstNames.randomElement()!,
                subtitle: "Micro-Bursts",
                shorthand: parts.joined(separator: ","),
                minutes: mbTotal
            )

        // ── Sprint: short bursts 15-60sec at 150%+ FTP ──────────
        case .sprint:
            let sprintSec = Int.random(in: 20...30)
            let sprintFrac = Double(sprintSec) / 60.0
            let sprintMinsStr = String(format: "%.1fm", sprintFrac)
            let recoveryMins = 3
            let pct = Int.random(in: 150...180)
            let workIF = Double(pct) / 100.0
            let warmup = ("W12m@50%", tssForBlock(minutes: 12, ifactor: 0.50))
            let cooldown = ("C8m@42%", tssForBlock(minutes: 8, ifactor: 0.42))
            let overhead = warmup.1 + cooldown.1
            let tssPerRep = tssForBlock(seconds: sprintSec, ifactor: workIF) + tssForBlock(minutes: recoveryMins, ifactor: 0.45)
            let maxReps = max(4, (min(55, maxMinutes) - 20) / (1 + recoveryMins))
            let reps = clamp(repsForTSS(tss: Double(targetTSS) - overhead, tssPerRep: tssPerRep), min: 4, max: maxReps)
            let total = 20 + reps * (1 + recoveryMins)
            return WorkoutResult(
                name: sprintNames.randomElement()!,
                subtitle: "Sprint Power",
                shorthand: "\(warmup.0),[I\(sprintMinsStr)@\(pct)%,R\(recoveryMins)m@45%]x\(reps),\(cooldown.0)",
                minutes: total
            )

        // ── Test: FTP test ───────────────────────────────────────
        case .test:
            return WorkoutResult(
                name: "Ramp Test",
                subtitle: "FTP Assessment",
                shorthand: "W15m@55%,I5m@95%,R5m@45%,I20m@100%,C10m@40%",
                minutes: 55
            )
        }
    }

    // MARK: - TSS Math Helpers

    /// TSS for a single block: (minutes/60) × IF² × 100
    private static func tssForBlock(minutes: Int, ifactor: Double) -> Double {
        (Double(minutes) / 60.0) * ifactor * ifactor * 100.0
    }

    /// TSS for a block specified in seconds
    private static func tssForBlock(seconds: Int, ifactor: Double) -> Double {
        (Double(seconds) / 3600.0) * ifactor * ifactor * 100.0
    }

    /// How many minutes at a given IF to produce a target TSS
    /// TSS = (mins/60) × IF² × 100  →  mins = TSS × 60 / (IF² × 100)
    private static func minutesForTSS(tss: Double, ifactor: Double) -> Int {
        guard ifactor > 0 && tss > 0 else { return 10 }
        return Int(round(tss * 60.0 / (ifactor * ifactor * 100.0)))
    }

    /// How many reps of a repeating block to hit target TSS
    private static func repsForTSS(tss: Double, tssPerRep: Double) -> Int {
        guard tssPerRep > 0 && tss > 0 else { return 2 }
        return Int(round(tss / tssPerRep))
    }

    private static func clamp(_ value: Int, min minVal: Int, max maxVal: Int) -> Int {
        max(minVal, min(value, maxVal))
    }

    // MARK: - CTL Calculator (reusable)

    /// Calculate current CTL from workout history
    static func currentCTL(from sessions: [WorkoutSession]) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var tssPerDay: [Date: Int] = [:]
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            tssPerDay[day, default: 0] += session.tss
        }

        guard let oldest = sessions.map({ $0.date }).min() else { return 0 }
        let startDate = calendar.startOfDay(for: oldest)

        var ctl: Double = 0
        let ctlDecay = 1.0 - exp(-1.0 / 42.0)

        var current = startDate
        while current <= today {
            let tss = Double(tssPerDay[current] ?? 0)
            ctl = ctl + (tss - ctl) * ctlDecay
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }

        return ctl
    }
}
