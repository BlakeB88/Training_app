import HealthKit

struct SwimmingStrainCalculator {
    static func calculateSwimmingStrain(
        workout: HKWorkout,
        hrProfile: HeartRateProfile,
        heartRateData: [Double]? = nil
    ) -> Double {
        let duration = workout.durationMinutes
        let calories = workout.activeCalories
        let distance = workout.swimmingDistance ?? 0
        guard duration > 0 else { return 0 }

        // 1️⃣ Pace intensity (0.4–1.2)
        let pace = distance > 0 ? (duration / (distance / 100.0)) : 0
        let paceIntensity = calculatePaceIntensity(pace: pace)

        // 2️⃣ Heart rate intensity (if available)
        var hrIntensity: Double? = nil
        if let hrData = heartRateData, !hrData.isEmpty {
            let avgHR = hrData.reduce(0, +) / Double(hrData.count)
            let maxHR = hrProfile.maxHeartRate
            let restHR = hrProfile.restingHeartRate
            hrIntensity = max(0, min(1.25, (avgHR - restHR) / (maxHR - restHR)))
        }

        // 3️⃣ Blend HR + pace (HR heavier when available)
        let blendedIntensity: Double
        if let hr = hrIntensity {
            blendedIntensity = hr * 0.65 + paceIntensity * 0.35
        } else {
            blendedIntensity = paceIntensity
        }

        // 4️⃣ Add small calorie weighting (10%)
        let calorieFactor = min(calories / (duration * 10.0), 1.0)
        let combinedIntensity = blendedIntensity * 0.9 + calorieFactor * 0.1

        // 5️⃣ Duration scaling — logarithmic curve for 45–120 min range
        // Keeps long swims (2h) from inflating unrealistically
        let durationFactor = log10(duration + 10) / log10(130) // ≈0.5–1.0 for 45–120 min

        // 6️⃣ Stroke multiplier
        let strokeMultiplier = getStrokeMultiplier(for: workout)

        // 7️⃣ WHOOP-like strain scaling
        let baseScore = pow(combinedIntensity, 1.2) * 12.0 * durationFactor
        let adjusted = baseScore * strokeMultiplier

        return min(adjusted, 21.0)
    }

    private static func calculatePaceIntensity(pace: Double) -> Double {
        guard pace > 0 else { return 0.6 }
        switch pace {
        case ..<1.3: return 1.1
        case 1.3..<1.8: return 0.9
        case 1.8..<2.5: return 0.7
        case 2.5..<3.0: return 0.5
        default: return 0.4
        }
    }

    private static func getStrokeMultiplier(for workout: HKWorkout) -> Double {
        if let strokeType = workout.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int {
            switch HKSwimmingStrokeStyle(rawValue: strokeType) {
            case .butterfly: return 1.25
            case .breaststroke: return 1.15
            case .backstroke: return 1.05
            default: return 1.0
            }
        }
        return 1.0
    }
}
