import Foundation
import HealthKit
import Testing
@testable import StrainFitnessTracker

struct StrainFitnessTrackerTests {
    private let profile = HeartRateProfile(maxHeartRate: 190, restingHeartRate: 55, age: 30)

    @Test func poolSwimWithNoisyPaceStaysModerate() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 45,
            calories: 430,
            distanceMeters: 5000,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let strain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            heartRateData: Array(repeating: 136, count: 12)
        )

        #expect(strain < 12.0)
        #expect(strain > 8.0)
    }

    @Test func longHardPoolSwimKeepsPremiumWithoutNearMaxing() async {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 90,
            calories: 950,
            distanceMeters: 4200,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let swimStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            heartRateData: Array(repeating: 152, count: 18)
        )

        let cyclingWorkout = makeWorkout(
            activityType: .cycling,
            durationMinutes: 60,
            calories: 550
        )

        let cyclingStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: cyclingWorkout,
            hrProfile: profile
        )

        #expect(swimStrain > cyclingStrain)
        #expect(swimStrain > 12.0)
        #expect(swimStrain < 17.0)
    }

    @Test func veryLongHardPoolSwimReachesHighTeens() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 129,
            calories: 839,
            distanceMeters: 4850,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let strain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 146
        )

        #expect(strain >= 17.0)
        #expect(strain < 20.0)
    }

    @Test func openWaterSwimLetsPaceMatterMoreThanPool() {
        let poolWorkout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 50,
            calories: 500,
            distanceMeters: 3800,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )
        let openWaterWorkout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 50,
            calories: 500,
            distanceMeters: 3800,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.openWater.rawValue)
            ]
        )

        let heartRateData = Array(repeating: 142, count: 16)
        let poolStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: poolWorkout,
            hrProfile: profile,
            heartRateData: heartRateData
        )
        let openWaterStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: openWaterWorkout,
            hrProfile: profile,
            heartRateData: heartRateData
        )

        #expect(openWaterStrain > poolStrain)
    }

    @Test func heartRateDrivesSwimStrainMoreThanSecondaryInputs() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 95,
            calories: 760,
            distanceMeters: 4700,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let lowerHRStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 136
        )
        let higherHRStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 150
        )

        #expect(higherHRStrain > lowerHRStrain)
        #expect(higherHRStrain - lowerHRStrain >= 2.0)
    }

    @Test func swimMinimumHeartRateOnlyAddsSmallStabilityEffect() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 75,
            calories: 640,
            distanceMeters: 3600,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let lowerMinHRStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 142,
            minHeartRateOverride: 110
        )
        let higherMinHRStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 142,
            minHeartRateOverride: 126
        )

        #expect(higherMinHRStrain > lowerMinHRStrain)
        #expect(higherMinHRStrain - lowerMinHRStrain < 0.5)
    }

    @Test func poolSwimWithoutHeartRateFallsBackWithoutInflation() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 35,
            calories: 280,
            distanceMeters: 3200,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue)
            ]
        )

        let strain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: workout,
            hrProfile: profile
        )

        #expect(strain < 9.5)
        #expect(strain > 4.0)
    }

    @Test func strokeMultiplierAddsOnlySmallPremium() {
        let freestyleWorkout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 60,
            calories: 620,
            distanceMeters: 3000,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue),
                HKMetadataKeySwimmingStrokeStyle: NSNumber(value: HKSwimmingStrokeStyle.freestyle.rawValue)
            ]
        )
        let butterflyWorkout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 60,
            calories: 620,
            distanceMeters: 3000,
            metadata: [
                HKMetadataKeySwimmingLocationType: NSNumber(value: HKWorkoutSwimmingLocationType.pool.rawValue),
                HKMetadataKeySwimmingStrokeStyle: NSNumber(value: HKSwimmingStrokeStyle.butterfly.rawValue)
            ]
        )

        let heartRateData = Array(repeating: 145, count: 14)
        let freestyleStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: freestyleWorkout,
            hrProfile: profile,
            heartRateData: heartRateData
        )
        let butterflyStrain = SwimmingStrainCalculator.calculateSwimmingStrain(
            workout: butterflyWorkout,
            hrProfile: profile,
            heartRateData: heartRateData
        )

        #expect(butterflyStrain > freestyleStrain)
        #expect(butterflyStrain <= freestyleStrain * 1.08 + 0.01)
    }

    @Test func nonSwimmingFallbackFormulaIsUnchanged() async {
        let workout = makeWorkout(
            activityType: .walking,
            durationMinutes: 60,
            calories: 300
        )

        let strain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile
        )

        let expectedIntensity = min((300.0 / 60.0) / 12.0, 1.0) * 0.7
        let expectedStrain = min(log2(expectedIntensity * 60.0 + 300.0 * 0.3 + 1.0) * 3.0, 21.0)

        #expect(abs(strain - expectedStrain) < 0.0001)
    }

    @Test func nonSwimmingHeartRateBiasBeatsCalorieOnlyDifferences() async {
        let workout = makeWorkout(
            activityType: .cycling,
            durationMinutes: 60,
            calories: 500
        )

        let lowerHRHigherCalories = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 128,
            caloriesOverride: 620
        )
        let higherHRLowerCalories = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 152,
            caloriesOverride: 460
        )

        #expect(higherHRLowerCalories > lowerHRHigherCalories)
        #expect(higherHRLowerCalories - lowerHRHigherCalories >= 1.0)
    }

    @Test func nonSwimmingMinimumHeartRateOnlySlightlyMovesIntensityAndStrain() async {
        let workout = makeWorkout(
            activityType: .cycling,
            durationMinutes: 60,
            calories: 500
        )

        let lowerMinIntensity = StrainCalculator.calculateHRIntensity(
            avgHR: 145,
            minHR: 104,
            profile: profile
        )
        let higherMinIntensity = StrainCalculator.calculateHRIntensity(
            avgHR: 145,
            minHR: 122,
            profile: profile
        )

        let lowerMinStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 145,
            minHeartRateOverride: 104
        )
        let higherMinStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 145,
            minHeartRateOverride: 122
        )

        #expect(higherMinIntensity > lowerMinIntensity)
        #expect(higherMinIntensity - lowerMinIntensity < 0.04)
        #expect(higherMinStrain > lowerMinStrain)
        #expect(higherMinStrain - lowerMinStrain < 0.35)
    }

    @Test func nonSwimmingAverageHeartRateChangesMatterMoreThanMinimumHeartRate() async {
        let workout = makeWorkout(
            activityType: .cycling,
            durationMinutes: 60,
            calories: 500
        )

        let lowerAvgIntensity = StrainCalculator.calculateHRIntensity(
            avgHR: 136,
            minHR: 118,
            profile: profile
        )
        let higherAvgIntensity = StrainCalculator.calculateHRIntensity(
            avgHR: 152,
            minHR: 118,
            profile: profile
        )

        let lowerAvgStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 136,
            minHeartRateOverride: 118
        )
        let higherAvgStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: profile,
            averageHeartRateOverride: 152,
            minHeartRateOverride: 118
        )

        #expect(higherAvgIntensity > lowerAvgIntensity)
        #expect(higherAvgIntensity - lowerAvgIntensity >= 0.12)
        #expect(higherAvgStrain > lowerAvgStrain)
        #expect(higherAvgStrain - lowerAvgStrain >= 1.0)
    }

    @Test func autoWorkoutCutoffUsesBufferedLowHeartRateStart() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 90,
            calories: 600
        )

        let samples: [(date: Date, heartRate: Double)] = [
            (workout.startDate.addingTimeInterval(45 * 60), 132),
            (workout.startDate.addingTimeInterval(60 * 60), 118),
            (workout.startDate.addingTimeInterval(65 * 60), 112),
            (workout.startDate.addingTimeInterval(70 * 60), 109)
        ]

        let effectiveEndDate = WorkoutAutoCutoff.effectiveEndDate(for: workout, heartRateSamples: samples)

        #expect(effectiveEndDate == workout.startDate.addingTimeInterval(65 * 60))
    }

    @Test func autoWorkoutCutoffIgnoresBriefLowHeartRateDip() {
        let workout = makeWorkout(
            activityType: .swimming,
            durationMinutes: 90,
            calories: 600
        )

        let samples: [(date: Date, heartRate: Double)] = [
            (workout.startDate.addingTimeInterval(55 * 60), 118),
            (workout.startDate.addingTimeInterval(62 * 60), 116),
            (workout.startDate.addingTimeInterval(63 * 60), 124),
            (workout.startDate.addingTimeInterval(74 * 60), 114)
        ]

        let effectiveEndDate = WorkoutAutoCutoff.effectiveEndDate(for: workout, heartRateSamples: samples)

        #expect(effectiveEndDate == nil)
    }

    private func makeWorkout(
        activityType: HKWorkoutActivityType,
        durationMinutes: Double,
        calories: Double,
        distanceMeters: Double? = nil,
        metadata: [String: Any] = [:]
    ) -> HKWorkout {
        let startDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        let endDate = startDate.addingTimeInterval(durationMinutes * 60.0)
        let energy = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let distance = distanceMeters.map { HKQuantity(unit: .meter(), doubleValue: $0) }

        return HKWorkout(
            activityType: activityType,
            start: startDate,
            end: endDate,
            duration: durationMinutes * 60.0,
            totalEnergyBurned: energy,
            totalDistance: distance,
            metadata: metadata.isEmpty ? nil : metadata
        )
    }
}
