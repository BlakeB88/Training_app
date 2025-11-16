import Foundation
import Combine
import HealthKit

@MainActor
final class HunterStatsViewModel: ObservableObject {
    @Published var snapshot: HunterStatsSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: MetricsRepository
    private let statsEngine = HunterStatsEngine()
    private let persistence = HunterProgressPersistence()

    init(repository: MetricsRepository? = nil) {
        self.repository = repository ?? MetricsRepository()
    }

    func load() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let metrics = try repository.fetchRecentDailyMetrics(days: 30)
            let body = buildBodyCompositionInputs()
            let swimEvents = buildSwimEvents(from: metrics)
            let inputs = HunterStatsInputs(
                metricsHistory: metrics,
                bodyComposition: body,
                swimEventPRs: swimEvents,
                xpState: persistence.load()
            )
            let snapshot = statsEngine.makeSnapshot(from: inputs)
            persistence.save(snapshot.xpState)
            self.snapshot = snapshot
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Builders
    private func buildBodyCompositionInputs() -> BodyCompositionInputs {
        return BodyCompositionInputs(
            weight: 182,
            bodyFatPercentage: 17.5,
            visceralFat: 9,
            subcutaneousFatPercentage: 14,
            muscleMass: 82,
            fatFreeMass: 150,
            bodyWaterPercentage: 58,
            boneMass: 8.5,
            bmi: 24.5,
            bmr: 1850,
            metabolicAge: 29,
            proteinPercentage: 18
        )
    }

    private func buildSwimEvents(from metrics: [SimpleDailyMetrics]) -> [SwimEventInput] {
        var bestByEvent: [Double: SwimEventInput] = [:]
        let workouts = metrics.flatMap { $0.workouts }
        for workout in workouts where workout.workoutType == .swimming {
            guard let distance = workout.distance, distance > 0 else { continue }
            guard let definition = SwimEventDefinition.closestMatch(for: distance) else { continue }
            let duration = workout.duration
            if let existing = bestByEvent[definition.distance], existing.personalRecordSeconds <= duration {
                continue
            }
            bestByEvent[definition.distance] = SwimEventInput(
                definition: definition,
                personalRecordSeconds: duration,
                recordDate: workout.endDate
            )
        }

        if bestByEvent.isEmpty {
            return defaultSwimEvents()
        }

        return Array(bestByEvent.values)
    }

    private func defaultSwimEvents() -> [SwimEventInput] {
        let today = Date()
        return [
            SwimEventInput(definition: SwimEventDefinition.catalog[0], personalRecordSeconds: 28.5, recordDate: today.addingTimeInterval(-86400 * 3)),
            SwimEventInput(definition: SwimEventDefinition.catalog[2], personalRecordSeconds: 125.0, recordDate: today.addingTimeInterval(-86400 * 10)),
            SwimEventInput(definition: SwimEventDefinition.catalog[4], personalRecordSeconds: 520.0, recordDate: today.addingTimeInterval(-86400 * 15))
        ]
    }
}

private struct HunterProgressPersistence {
    private let levelKey = "hunter.level"
    private let xpKey = "hunter.xp"
    private let xpToNextKey = "hunter.xp.next"

    func load() -> HunterXPState {
        let defaults = UserDefaults.standard
        let level = defaults.integer(forKey: levelKey)
        let storedLevel = level == 0 ? 1 : level
        let xp = defaults.integer(forKey: xpKey)
        let xpToNext = defaults.integer(forKey: xpToNextKey)
        let requirement = xpToNext == 0 ? HunterLevelCurve.nextRequirement(for: storedLevel) : xpToNext
        return HunterXPState(level: storedLevel, currentXP: xp, xpToNextLevel: requirement, earnedToday: 0)
    }

    func save(_ state: HunterXPState) {
        let defaults = UserDefaults.standard
        defaults.set(state.level, forKey: levelKey)
        defaults.set(state.currentXP, forKey: xpKey)
        defaults.set(state.xpToNextLevel, forKey: xpToNextKey)
    }
}
