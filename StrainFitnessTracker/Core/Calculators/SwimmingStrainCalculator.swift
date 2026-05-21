import HealthKit

struct SwimmingStrainCalculator {
    static func calculateSwimmingStrain(
        workout: HKWorkout,
        hrProfile: HeartRateProfile,
        heartRateData: [Double]? = nil,
        durationOverride: Double? = nil,
        caloriesOverride: Double? = nil,
        distanceOverride: Double? = nil,
        averageHeartRateOverride: Double? = nil,
        minHeartRateOverride: Double? = nil
    ) -> Double {
        let duration = durationOverride ?? workout.durationMinutes
        let calories = caloriesOverride ?? workout.activeCalories
        let distance = distanceOverride ?? workout.swimmingDistance ?? 0
        guard duration > 0 else { return 0 }

        let isPoolSwim = workout.swimmingLocationType == .pool
        let pace = distance > 0 ? (duration / (distance / 100.0)) : 0
        let paceIntensity = calculatePaceIntensity(pace: pace, isPoolSwim: isPoolSwim)
        let calorieIntensity = calculateCalorieIntensity(calories: calories, duration: duration)
        let hrIntensity = calculateHRIntensity(
            workout: workout,
            hrProfile: hrProfile,
            heartRateData: heartRateData,
            averageHeartRateOverride: averageHeartRateOverride,
            minHeartRateOverride: minHeartRateOverride
        )
        let combinedIntensity = combineIntensity(
            hrIntensity: hrIntensity,
            paceIntensity: paceIntensity,
            calorieIntensity: calorieIntensity,
            isPoolSwim: isPoolSwim
        )
        let durationFactor = calculateDurationFactor(duration: duration)
        let strokeMultiplier = getStrokeMultiplier(for: workout)
        let baseScore = pow(combinedIntensity, 1.15) * 14.75 * durationFactor
        let adjusted = baseScore * strokeMultiplier

        return min(adjusted, 21.0)
    }

    private static func calculateHRIntensity(
        workout: HKWorkout,
        hrProfile: HeartRateProfile,
        heartRateData: [Double]?,
        averageHeartRateOverride: Double?,
        minHeartRateOverride: Double?
    ) -> Double? {
        let averageHeartRate: Double?
        if let averageHeartRateOverride {
            averageHeartRate = averageHeartRateOverride
        } else if let heartRateData, !heartRateData.isEmpty {
            averageHeartRate = heartRateData.reduce(0, +) / Double(heartRateData.count)
        } else {
            averageHeartRate = workout.averageHeartRate
        }

        guard let averageHeartRate else { return nil }
        let minHeartRate = minHeartRateOverride ?? heartRateData?.min()

        return StrainCalculator.calculateHRIntensity(
            avgHR: averageHeartRate,
            minHR: minHeartRate,
            profile: hrProfile
        )
    }

    private static func combineIntensity(
        hrIntensity: Double?,
        paceIntensity: Double,
        calorieIntensity: Double,
        isPoolSwim: Bool
    ) -> Double {
        if let hrIntensity {
            let weightedHRIntensity = pow(hrIntensity, 1.12)
            if isPoolSwim {
                return weightedHRIntensity * 0.88 + calorieIntensity * 0.09 + paceIntensity * 0.03
            }
            return weightedHRIntensity * 0.80 + calorieIntensity * 0.09 + paceIntensity * 0.11
        }

        if isPoolSwim {
            return calorieIntensity * 0.75 + paceIntensity * 0.25
        }

        return calorieIntensity * 0.55 + paceIntensity * 0.45
    }

    private static func calculatePaceIntensity(pace: Double, isPoolSwim: Bool) -> Double {
        guard pace > 0 else { return isPoolSwim ? 0.5 : 0.55 }

        if isPoolSwim {
            switch pace {
            case ..<1.2: return 0.82
            case 1.2..<1.5: return 0.76
            case 1.5..<1.9: return 0.70
            case 1.9..<2.3: return 0.63
            case 2.3..<2.8: return 0.56
            default: return 0.48
            }
        }

        switch pace {
        case ..<1.2: return 1.02
        case 1.2..<1.5: return 0.95
        case 1.5..<1.9: return 0.87
        case 1.9..<2.3: return 0.78
        case 2.3..<2.8: return 0.68
        default: return 0.58
        }
    }

    private static func calculateCalorieIntensity(calories: Double, duration: Double) -> Double {
        guard duration > 0 else { return 0.45 }

        let caloriesPerMinute = calories / duration
        switch caloriesPerMinute {
        case ..<4.0: return 0.45
        case 4.0..<6.0: return 0.60
        case 6.0..<8.5: return 0.75
        case 8.5..<11.0: return 0.90
        default: return 1.02
        }
    }

    private static func calculateDurationFactor(duration: Double) -> Double {
        switch duration {
        case ..<20: return 0.65
        case 20..<40: return 0.82
        case 40..<60: return 1.0
        case 60..<90: return 1.15
        case 90..<120: return 1.28
        case 120..<150: return 1.72
        default: return 1.84
        }
    }

    private static func getStrokeMultiplier(for workout: HKWorkout) -> Double {
        if let strokeStyle = workout.swimmingStrokeStyleMetadata {
            switch strokeStyle {
            case .butterfly: return 1.08
            case .breaststroke: return 1.05
            case .backstroke: return 1.03
            default: return 1.0
            }
        }
        return 1.0
    }
}
