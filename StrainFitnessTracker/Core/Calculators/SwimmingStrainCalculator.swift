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

        // 1️⃣ Pace intensity (more aggressive scaling: 0.5–1.4)
        // Note: Apple Watch distance is often inaccurate in pools
        // Pace calculation may not be reliable - HR and calories are better indicators
        let pace = distance > 0 ? (duration / (distance / 100.0)) : 0
        let paceIntensity = calculatePaceIntensity(pace: pace)
        
        print("🏊 Swimming Debug:")
        print("  Duration: \(duration) min")
        print("  Distance: \(distance) m")
        print("  Calculated Pace: \(pace) min/100m")
        print("  Pace Intensity: \(paceIntensity)")
        print("  Calories: \(calories)")

        // 2️⃣ Heart rate intensity (if available) - PRIMARY INDICATOR for swimming
        var hrIntensity: Double? = nil
        if let hrData = heartRateData, !hrData.isEmpty {
            let avgHR = hrData.reduce(0, +) / Double(hrData.count)
            let maxHR = hrProfile.maxHeartRate
            let restHR = hrProfile.restingHeartRate
            // Slightly higher ceiling for swimming (1.35 vs 1.25)
            hrIntensity = max(0, min(1.35, (avgHR - restHR) / (maxHR - restHR)))
            print("  Avg HR: \(avgHR) bpm")
            print("  HR Intensity: \(hrIntensity ?? 0)")
        } else if let avgHR = workout.averageHeartRate {
            // Fallback to workout's average HR if no detailed data
            let maxHR = hrProfile.maxHeartRate
            let restHR = hrProfile.restingHeartRate
            hrIntensity = max(0, min(1.35, (avgHR - restHR) / (maxHR - restHR)))
            print("  Avg HR (from workout): \(avgHR) bpm")
            print("  HR Intensity: \(hrIntensity ?? 0)")
        } else {
            print("  ⚠️ No HR data available")
        }

        // 3️⃣ Blend HR + pace (HR heavily weighted when available due to pace unreliability)
        let blendedIntensity: Double
        if let hr = hrIntensity {
            // When HR available, weight it heavily (85% vs 15%) since pace is often wrong
            blendedIntensity = hr * 0.85 + paceIntensity * 0.15
            print("  Blended Intensity (HR-heavy): \(blendedIntensity)")
        } else {
            // No HR data - must rely on pace/calories (less reliable)
            blendedIntensity = paceIntensity
            print("  Blended Intensity (pace-only): \(blendedIntensity)")
        }

        // 4️⃣ Calorie weighting (20% - increased from 15% to compensate for pace issues)
        let calorieFactor = min(calories / (duration * 10.0), 1.0)
        let combinedIntensity = blendedIntensity * 0.80 + calorieFactor * 0.20
        print("  Calorie Factor: \(calorieFactor)")
        print("  Combined Intensity: \(combinedIntensity)")

        // 5️⃣ Duration scaling - LINEAR for swimming (no log dampening)
        // Swimming is sustained cardio and should scale more directly with time
        // Cap at 120 minutes for normalization
        let durationFactor = min(duration / 60.0, 2.0) // 30min=0.5, 60min=1.0, 120min=2.0
        print("  Duration Factor: \(durationFactor)")

        // 6️⃣ Stroke multiplier
        let strokeMultiplier = getStrokeMultiplier(for: workout)
        print("  Stroke Multiplier: \(strokeMultiplier)")

        // 7️⃣ WHOOP-like strain scaling - AGGRESSIVE for competitive swimming
        // Competitive swimmers maintain high work rates for extended periods
        // Formula calibrated for: 90min @ 141avg HR (0.65 intensity) → 16-18 strain
        let baseScore = pow(combinedIntensity, 1.05) * 18.0 * durationFactor
        let adjusted = baseScore * strokeMultiplier
        
        print("  Base Score: \(baseScore)")
        print("  Final Strain: \(min(adjusted, 21.0))")

        return min(adjusted, 21.0)
    }

    // More aggressive pace intensity thresholds
    private static func calculatePaceIntensity(pace: Double) -> Double {
        guard pace > 0 else { return 0.7 }
        switch pace {
        case ..<1.2: return 1.4      // Sprint pace (was 1.1)
        case 1.2..<1.5: return 1.2   // Fast pace (new tier)
        case 1.5..<2.0: return 1.0   // Moderate-fast (was 0.9)
        case 2.0..<2.5: return 0.8   // Moderate (was 0.7)
        case 2.5..<3.0: return 0.6   // Easy (was 0.5)
        default: return 0.5          // Recovery (was 0.4)
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
