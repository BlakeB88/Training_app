import Foundation
import Combine
import HealthKit

@MainActor
final class HunterStatsViewModel: ObservableObject {
    @Published var snapshot: HunterStatsSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showSwimTimeInput = false

    private let repository: MetricsRepository
    private let statsEngine = HunterStatsEngine()
    private let persistence = HunterProgressPersistence()
    private let swimPersistence = SwimTimePersistence()
    private let healthKitManager: HealthKitManager

    init(repository: MetricsRepository? = nil, healthKitManager: HealthKitManager = .shared) {
        self.repository = repository ?? MetricsRepository()
        self.healthKitManager = healthKitManager
    }

    func load() async {
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let metrics = try repository.fetchRecentDailyMetrics(days: 30)
            let body = await buildBodyCompositionInputs()
            
            // Use manual swim times instead of workout data
            let swimEvents = buildSwimEventsFromManualInput()
            
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
    private func buildBodyCompositionInputs() async -> BodyCompositionInputs {
        var inputs = defaultBodyComposition()

        guard healthKitManager.isAuthorized else {
            return inputs
        }

        do {
            let snapshot = try await healthKitManager.fetchBodyCompositionSnapshot()

            if let weight = snapshot.weight {
                inputs.weight = weight
            }

            if let leanMass = snapshot.leanBodyMass {
                inputs.fatFreeMass = leanMass
                inputs.muscleMass = max(leanMass * 0.9, leanMass - 8)
                if inputs.weight > 0 {
                    let leanRatio = leanMass / inputs.weight
                    inputs.bodyWaterPercentage = min(75, max(45, leanRatio * 72))
                    inputs.proteinPercentage = min(30, max(12, leanRatio * 28))
                    inputs.boneMass = max(6, leanMass * 0.04)
                }
                let leanMassKg = leanMass * 0.45359237
                inputs.bmr = max(1200, round(370 + (21.6 * leanMassKg)))
            }

            if let bodyFat = snapshot.bodyFatPercentage {
                inputs.bodyFatPercentage = bodyFat
                inputs.subcutaneousFatPercentage = bodyFat * 0.8
                inputs.visceralFat = max(4, (bodyFat - 8) * 0.6)
            }

            if let weight = snapshot.weight,
               let height = snapshot.height,
               height > 0 {
                let weightKg = weight * 0.45359237
                let bmi = weightKg / (height * height)
                inputs.bmi = (bmi * 10).rounded() / 10
            }
        } catch {
            print("⚠️ Failed to fetch body composition: \(error.localizedDescription)")
        }

        return inputs
    }

    private func defaultBodyComposition() -> BodyCompositionInputs {
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

    // NEW: Build swim events from manual user input
    private func buildSwimEventsFromManualInput() -> [SwimEventInput] {
        let manualTimes = swimPersistence.getAllBestTimes()
        
        if manualTimes.isEmpty {
            return defaultSwimEvents()
        }
        
        return manualTimes
    }

    // DEPRECATED: Old method that parsed workout data
    private func buildSwimEvents(from metrics: [SimpleDailyMetrics]) -> [SwimEventInput] {
        var bestByEvent: [Double: SwimEventInput] = [:]
        let workouts = metrics.flatMap { $0.workouts }
        for workout in workouts where workout.workoutType == .swimming {
            guard let distance = workout.distance, distance > 0 else { continue }
            guard let definition = SwimEventDefinition.closestMatch(for: distance, unit: .meters) else { continue }
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
        let freestyle100 = SwimEventDefinition.expandedCatalog.first { $0.displayName == "100m Freestyle" && $0.unit == .meters }
        let freestyle200 = SwimEventDefinition.expandedCatalog.first { $0.displayName == "200m Freestyle" && $0.unit == .meters }
        let freestyle800 = SwimEventDefinition.expandedCatalog.first { $0.displayName == "800m Freestyle" && $0.unit == .meters }

        return [
            freestyle100.map { SwimEventInput(definition: $0, personalRecordSeconds: 28.5, recordDate: today.addingTimeInterval(-86400 * 3)) },
            freestyle200.map { SwimEventInput(definition: $0, personalRecordSeconds: 125.0, recordDate: today.addingTimeInterval(-86400 * 10)) },
            freestyle800.map { SwimEventInput(definition: $0, personalRecordSeconds: 520.0, recordDate: today.addingTimeInterval(-86400 * 15)) }
        ].compactMap { $0 }
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
