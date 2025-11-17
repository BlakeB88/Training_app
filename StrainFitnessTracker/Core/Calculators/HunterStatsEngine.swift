import Foundation

struct HunterStatsEngine {
    private let sprintWeight: Double = 0.35

    func makeSnapshot(from inputs: HunterStatsInputs) -> HunterStatsSnapshot {
        let metrics = inputs.metricsHistory.sorted(by: { $0.date > $1.date })
        let latest = metrics.first
        let readiness = ReadinessContext(metrics: latest, history: metrics)

        let swimPerformances = computeSwimPerformances(inputs.swimEventPRs)
        let swimMasteryScore = swimPerformances.map { $0.performanceIndex }.average()
        let swimMasteryRank = HunterRank.rank(for: swimMasteryScore)

        let (modifiers, awakenState) = buildDailyModifiers(from: readiness)
        let statCards = buildStatCards(
            readiness: readiness,
            body: inputs.bodyComposition,
            swimMasteryScore: swimMasteryScore,
            swimPerformances: swimPerformances,
            modifiers: modifiers
        )

        let overallScore = statCards.map { $0.score }.average()
        let hunterRank = HunterRank.rank(for: overallScore)
        let consistencyStreak = computeConsistencyStreak(from: metrics)
        let dailyScore = (readiness.dailyReadinessScore + overallScore) / 2.0

        let xpState = computeXPState(
            base: inputs.xpState,
            statCards: statCards,
            swimMastery: swimMasteryScore,
            swimEvents: swimPerformances,
            consistency: consistencyStreak
        )

        return HunterStatsSnapshot(
            statCards: statCards,
            hunterRank: hunterRank,
            xpState: xpState,
            dailyModifiers: modifiers,
            swimPerformances: swimPerformances,
            swimMasteryScore: swimMasteryScore,
            swimMasteryRank: swimMasteryRank,
            overallPerformanceIndex: overallScore,
            consistencyStreak: consistencyStreak,
            dailyScore: dailyScore,
            awakenStateActive: awakenState
        )
    }

    // MARK: - Stat Construction
    private func buildStatCards(
        readiness: ReadinessContext,
        body: BodyCompositionInputs,
        swimMasteryScore: Double,
        swimPerformances: [SwimEventPerformance],
        modifiers: [DailyModifier]
    ) -> [HunterStat] {
        let sprintEvent = swimPerformances.sorted(by: { $0.definition.distance < $1.definition.distance }).first
        let enduranceEvent = swimPerformances.sorted(by: { $0.definition.distance > $1.definition.distance }).first

        let sprintPI = sprintEvent?.performanceIndex ?? 0
        let endurancePI = enduranceEvent?.performanceIndex ?? 0

        var statScores: [HunterStatCategory: Double] = [:]
        statScores[.vitality] = vitalityScore(readiness: readiness, body: body)
        statScores[.strength] = strengthScore(readiness: readiness, body: body, sprintPI: sprintPI)
        statScores[.endurance] = enduranceScore(readiness: readiness, swimPI: endurancePI)
        statScores[.agility] = agilityScore(readiness: readiness, sprintPI: sprintPI)
        statScores[.physique] = physiqueScore(body: body)
        statScores[.metabolicPower] = metabolicPowerScore(readiness: readiness, body: body)
        statScores[.swimMastery] = swimMasteryScore

        // Apply modifiers
        var adjustedScores: [HunterStatCategory: Double] = [:]
        for category in HunterStatCategory.allCases {
            var value = statScores[category] ?? 0
            let modifierImpact = modifiers.filter { $0.targetStat == category }.map { $0.scoreImpact }.reduce(0, +)
            value = max(0, min(100, value + modifierImpact))
            adjustedScores[category] = value
        }

        return HunterStatCategory.allCases.map { category in
            let score = adjustedScores[category] ?? 0
            let rank = HunterRank.rank(for: score)
            let explanation = explanationFor(category: category, readiness: readiness, body: body, swimMastery: swimMasteryScore)
            let positives = positiveHighlights(for: category, readiness: readiness, body: body, swimMastery: swimMasteryScore)
            let negatives = negativeHighlights(for: category, readiness: readiness, body: body)
            let trend = trendFor(category: category, readiness: readiness)
            let nextHint = nextRankHint(for: rank, score: score)

            return HunterStat(
                category: category,
                score: score,
                rank: rank,
                explanation: explanation,
                positives: positives,
                negatives: negatives,
                trend: trend,
                nextRankHint: nextHint
            )
        }
    }

    // MARK: - Individual Stat Scores
    private func vitalityScore(readiness: ReadinessContext, body: BodyCompositionInputs) -> Double {
        let sleepQuality = normalized(readiness.sleepDurationHours, min: 4, max: 9)
        let sleepEfficiency = normalized(readiness.sleepEfficiency, min: 60, max: 100)
        let hrv = normalized(readiness.hrvAverage, min: 20, max: 120)
        let hydration = normalized(body.bodyWaterPercentage, min: 45, max: 70)
        return [sleepQuality, sleepEfficiency, hrv, hydration].average()
    }

    private func strengthScore(readiness: ReadinessContext, body: BodyCompositionInputs, sprintPI: Double) -> Double {
        let muscleRatio = normalized(body.muscleMass / max(body.weight, 1), min: 0.3, max: 0.55)
        let strainLoad = normalized(readiness.strainScore, min: 4, max: 20)
        let protein = normalized(body.proteinPercentage, min: 12, max: 25)
        let sprintContribution = sprintPI * sprintWeight
        return [muscleRatio, strainLoad, protein, sprintContribution].average()
    }

    private func enduranceScore(readiness: ReadinessContext, swimPI: Double) -> Double {
        let vo2 = normalized(readiness.vo2Max, min: 30, max: 65)
        let longSwim = swimPI
        let steps = normalized(Double(readiness.steps), min: 3000, max: 15000)
        let recovery = normalized(readiness.recoveryScore, min: 30, max: 100)
        return [vo2, longSwim, steps, recovery].average()
    }

    private func agilityScore(readiness: ReadinessContext, sprintPI: Double) -> Double {
        let readinessScore = normalized(readiness.recoveryScore, min: 30, max: 100)
        let steps = normalized(Double(readiness.steps), min: 3000, max: 12000)
        let sprint = sprintPI
        let hrv = normalized(readiness.hrvAverage, min: 20, max: 120)
        return [readinessScore, steps, sprint, hrv].average()
    }

    private func physiqueScore(body: BodyCompositionInputs) -> Double {
        let bodyFat = inverseNormalized(body.bodyFatPercentage, min: 8, max: 30)
        let bmi = inverseNormalized(body.bmi, min: 18, max: 28)
        let muscle = normalized(body.muscleMass / max(body.weight, 1), min: 0.3, max: 0.55)
        return [bodyFat, bmi, muscle].average()
    }

    private func metabolicPowerScore(readiness: ReadinessContext, body: BodyCompositionInputs) -> Double {
        let bmrScore = normalized(body.bmr, min: 1200, max: 2500)
        let metabolicAge = inverseNormalized(body.metabolicAge, min: 18, max: 60)
        let restingHR = inverseNormalized(readiness.restingHeartRate, min: 45, max: 80)
        let protein = normalized(body.proteinPercentage, min: 12, max: 25)
        return [bmrScore, metabolicAge, restingHR, protein].average()
    }

    // MARK: - Modifiers
    private func buildDailyModifiers(from readiness: ReadinessContext) -> ([DailyModifier], Bool) {
        var modifiers: [DailyModifier] = []
        var awakenState = false

        if readiness.recoveryScore >= 80 {
            modifiers.append(
                DailyModifier(
                    title: "Recovery Surge",
                    description: "High readiness grants +1 rank to Agility",
                    icon: "hare",
                    modifierType: .recoveryBuff,
                    targetStat: .agility,
                    scoreImpact: 8
                )
            )
        }

        if readiness.strainScore >= 16 {
            modifiers.append(
                DailyModifier(
                    title: "Power Through",
                    description: "Heavy strain boosts Strength",
                    icon: "bolt",
                    modifierType: .strainBuff,
                    targetStat: .strength,
                    scoreImpact: 6
                )
            )
        }

        if readiness.recoveryScore <= 40 {
            modifiers.append(
                DailyModifier(
                    title: "Fatigue",
                    description: "Low recovery reduces Endurance",
                    icon: "zzz",
                    modifierType: .penalty,
                    targetStat: .endurance,
                    scoreImpact: -10
                )
            )
        }

        if readiness.sleepStreak >= 3 {
            modifiers.append(
                DailyModifier(
                    title: "Deep Sleep Streak",
                    description: "3-night streak adds Vitality boost",
                    icon: "bed.double",
                    modifierType: .sleepBuff,
                    targetStat: .vitality,
                    scoreImpact: 7
                )
            )
            modifiers.append(
                DailyModifier(
                    title: "Metabolic Reset",
                    description: "Well-rested metabolism",
                    icon: "flame",
                    modifierType: .sleepBuff,
                    targetStat: .metabolicPower,
                    scoreImpact: 5
                )
            )
        }

        if readiness.recoveryScore >= 90 && readiness.hrvAverage >= 70 && readiness.sleepDurationHours >= 7.5 {
            awakenState = true
        }

        return (modifiers, awakenState)
    }

    // MARK: - Swim Performance
    private func computeSwimPerformances(_ inputs: [SwimEventInput]) -> [SwimEventPerformance] {
        if inputs.isEmpty {
            return SwimEventDefinition.catalog.prefix(3).map { def in
                SwimEventPerformance(
                    definition: def,
                    personalRecordSeconds: def.worldRecordSeconds * 1.6,
                    performanceIndex: 35,
                    rank: HunterRank.rank(for: 35),
                    recordDate: Date().addingTimeInterval(-86400 * 30),
                    progressToNextRank: 0.4
                )
            }
        }

        let scored = inputs.map { input -> SwimEventPerformance in
            let ratio = input.personalRecordSeconds / input.definition.worldRecordSeconds
            let logScore = -log(ratio)
            let performanceIndex = max(1, min(100, exp(logScore * 5) * 100))
            let rank = HunterRank.rank(for: performanceIndex)
            let progress = progressToNextRank(for: performanceIndex)
            return SwimEventPerformance(
                definition: input.definition,
                personalRecordSeconds: input.personalRecordSeconds,
                performanceIndex: performanceIndex,
                rank: rank,
                recordDate: input.recordDate,
                progressToNextRank: progress
            )
        }

        return Array(scored.sorted(by: { $0.performanceIndex > $1.performanceIndex }).prefix(3))
    }

    private func progressToNextRank(for performance: Double) -> Double {
        let rank = HunterRank.rank(for: performance)
        guard let next = rank.nextRank else { return 1.0 }
        let gap = next.minimumScore - rank.minimumScore
        guard gap > 0 else { return 0 }
        let progress = (performance - rank.minimumScore) / gap
        return max(0, min(1, progress))
    }

    // MARK: - XP + Level
    private func computeXPState(
        base: HunterXPState,
        statCards: [HunterStat],
        swimMastery: Double,
        swimEvents: [SwimEventPerformance],
        consistency: Int
    ) -> HunterXPState {
        let statXP = Int(statCards.map { $0.score }.average() / 5)
        let swimXP = Int(swimMastery / 4)
        let streakXP = min(consistency, 15)
        let prBonus = swimEvents.filter { Calendar.current.isDateInToday($0.recordDate) }.isEmpty ? 0 : 25
        let earned = statXP + swimXP + streakXP + prBonus

        var currentXP = base.currentXP + earned
        var level = base.level
        var xpToNext = base.xpToNextLevel

        while currentXP >= xpToNext {
            currentXP -= xpToNext
            level += 1
            xpToNext = HunterLevelCurve.nextRequirement(for: level)
        }

        return HunterXPState(level: level, currentXP: currentXP, xpToNextLevel: xpToNext, earnedToday: earned)
    }

    // MARK: - Trend + Explanation
    private func explanationFor(
        category: HunterStatCategory,
        readiness: ReadinessContext,
        body: BodyCompositionInputs,
        swimMastery: Double
    ) -> String {
        switch category {
        case .vitality:
            return "Sleep efficiency and HRV drive today’s Vitality score."
        case .strength:
            return "Training load + muscle mass fuel Strength."
        case .endurance:
            return "VO₂ and long swim performance guide Endurance."
        case .agility:
            return "High readiness and sprint swim speed shape Agility."
        case .physique:
            return "Body fat, BMI, and lean mass define Physique."
        case .metabolicPower:
            return "BMR, protein intake, and resting HR set Metabolic Power."
        case .swimMastery:
            return "Average of top swim event performance indices."
        }
    }

    private func positiveHighlights(
        for category: HunterStatCategory,
        readiness: ReadinessContext,
        body: BodyCompositionInputs,
        swimMastery: Double
    ) -> [String] {
        switch category {
        case .vitality:
            return ["Sleep \(String(format: "%.1f h", readiness.sleepDurationHours))",
                    "HRV \(Int(readiness.hrvAverage)) ms"]

        case .strength:
            return ["Strain \(String(format: "%.1f", readiness.strainScore))",
                    "Muscle mass \(Int(body.muscleMass)) lbs"]

        case .endurance:
            return ["VO₂Max \(Int(readiness.vo2Max))",
                    "Steps \(readiness.steps)"]

        case .agility:
            return ["Readiness \(Int(readiness.recoveryScore))",
                    "Steps \(readiness.steps)"]

        case .physique:
            return ["Body fat \(String(format: "%.1f%%", body.bodyFatPercentage))",
                    "BMI \(String(format: "%.1f", body.bmi))"]

        case .metabolicPower:
            return ["BMR \(Int(body.bmr))",
                    "Protein \(Int(body.proteinPercentage))%"]

        case .swimMastery:
            return ["Avg PI \(String(format: "%.0f", swimMastery))"]
        }
    }

    private func negativeHighlights(for category: HunterStatCategory, readiness: ReadinessContext, body: BodyCompositionInputs) -> [String] {
        switch category {
        case .vitality:
            return readiness.sleepDurationHours < 7 ? ["Sleep debt active"] : []
        case .strength:
            return readiness.strainScore < 10 ? ["Light strain"] : []
        case .endurance:
            return readiness.steps < 6000 ? ["Low steps"] : []
        case .agility:
            return readiness.recoveryScore < 60 ? ["Low readiness"] : []
        case .physique:
            return body.bodyFatPercentage > 20 ? ["Cut body fat"] : []
        case .metabolicPower:
            return readiness.restingHeartRate > 60 ? ["High resting HR"] : []
        case .swimMastery:
            return []
        }
    }

    private func trendFor(category: HunterStatCategory, readiness: ReadinessContext) -> StatTrend {
        let delta: Double
        switch category {
        case .vitality:
            delta = readiness.sleepTrendDelta
        case .strength:
            delta = readiness.strainTrendDelta
        case .endurance:
            delta = readiness.enduranceTrendDelta
        case .agility:
            delta = readiness.stepsTrendDelta
        case .physique:
            delta = 0
        case .metabolicPower:
            delta = readiness.restingHeartRateTrendDelta
        case .swimMastery:
            delta = readiness.swimTrendDelta
        }
        let direction: StatTrend.Direction
        if delta > 1 {
            direction = .up
        } else if delta < -1 {
            direction = .down
        } else {
            direction = .flat
        }
        return StatTrend(direction: direction, delta: delta)
    }

    private func nextRankHint(for rank: HunterRank, score: Double) -> String? {
        guard let next = rank.nextRank else { return nil }
        let needed = max(0, next.minimumScore - score)
        let rounded = String(format: "%.1f", needed)
        return "\(rounded) pts to reach \(next.displayName)"
    }

    // MARK: - Helpers
    private func computeConsistencyStreak(from metrics: [SimpleDailyMetrics]) -> Int {
        guard !metrics.isEmpty else { return 0 }
        var streak = 0
        for day in metrics {
            let metActivityGoal = (day.steps ?? 0) >= 6000 || !day.workouts.isEmpty
            if metActivityGoal {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private func normalized(_ value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        let clamped = Swift.max(Swift.min(value, max), min)
        return ((clamped - min) / (max - min)) * 100
    }

    private func inverseNormalized(_ value: Double, min: Double, max: Double) -> Double {
        return 100 - normalized(value, min: min, max: max)
    }
}

// MARK: - Readiness Context
private struct ReadinessContext {
    let recoveryScore: Double
    let strainScore: Double
    let sleepDurationHours: Double
    let sleepEfficiency: Double
    let hrvAverage: Double
    let restingHeartRate: Double
    let sleepStreak: Int
    let vo2Max: Double
    let steps: Int
    let sleepTrendDelta: Double
    let strainTrendDelta: Double
    let enduranceTrendDelta: Double
    let stepsTrendDelta: Double
    let restingHeartRateTrendDelta: Double
    let swimTrendDelta: Double

    var dailyReadinessScore: Double {
        return [recoveryScore, hrvAverage / 1.2, sleepEfficiency].average()
    }

    init(metrics: SimpleDailyMetrics?, history: [SimpleDailyMetrics]) {
        recoveryScore = metrics?.recovery ?? 55
        strainScore = metrics?.strain ?? 10
        sleepDurationHours = metrics?.sleepDuration ?? 6.5
        sleepEfficiency = metrics?.sleepEfficiency ?? 85
        hrvAverage = metrics?.hrvAverage ?? 45
        restingHeartRate = metrics?.restingHeartRate ?? 58
        vo2Max = metrics?.vo2Max ?? 44
        steps = metrics?.steps ?? 7500
        sleepStreak = Self.computeSleepStreak(history: history)

        sleepTrendDelta = Self.trendDelta(for: history.map { $0.sleepDuration ?? 0 })
        strainTrendDelta = Self.trendDelta(for: history.map { $0.strain })
        enduranceTrendDelta = Self.trendDelta(for: history.map { Double($0.steps ?? 0) })
        stepsTrendDelta = enduranceTrendDelta
        restingHeartRateTrendDelta = -Self.trendDelta(for: history.map { $0.restingHeartRate ?? 0 })
        swimTrendDelta = 0
    }

    static func computeSleepStreak(history: [SimpleDailyMetrics]) -> Int {
        var streak = 0
        for metrics in history {
            if (metrics.sleepDuration ?? 0) >= 7.5 {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    static func trendDelta(for values: [Double]) -> Double {
        guard values.count >= 7 else { return 0 }
        let short = values.prefix(7).average()
        let long = values.prefix(30).average()
        return short - long
    }
}

struct HunterLevelCurve {
    static func nextRequirement(for level: Int) -> Int {
        return 100 + (level * 25)
    }
}

// MARK: - Collection Helpers
private extension Collection where Element == Double {
    /// Allow `average()` to work for ArraySlices produced by `prefix` so the Hunter stats build errors are resolved.
    func average() -> Double {
        guard !self.isEmpty else { return 0 }
        let total = self.reduce(0, +)
        return total / Double(self.count)
    }
}
