import HealthKit

struct StrengthTrainingStrainCalculator {
    
    /// Calculate strain for strength training workouts
    /// Strength training requires different modeling than cardio:
    /// - Intermittent effort (sets/rests) vs sustained cardio
    /// - Lower average HR but high peak efforts
    /// - Volume and intensity matter more than pure duration
    static func calculateStrengthTrainingStrain(
        workout: HKWorkout,
        hrProfile: HeartRateProfile,
        heartRateData: [Double]? = nil
    ) -> Double {
        let duration = workout.durationMinutes
        let calories = workout.activeCalories
        guard duration > 0 else { return 0 }
        
        // 1️⃣ Calculate intensity components
        let hrIntensity = calculateHRIntensity(
            heartRateData: heartRateData,
            hrProfile: hrProfile
        )
        
        let calorieIntensity = calculateCalorieIntensity(
            calories: calories,
            duration: duration
        )
        
        // 2️⃣ Blend intensities (HR weighted more heavily if available)
        let blendedIntensity: Double
        if hrIntensity > 0 {
            blendedIntensity = hrIntensity * 0.65 + calorieIntensity * 0.35
        } else {
            blendedIntensity = calorieIntensity
        }
        
        // 3️⃣ Duration scaling for strength training
        // Strength sessions are typically 45-90 minutes
        // Use a gentler curve than cardio since work density varies
        let durationFactor = calculateDurationFactor(duration: duration)
        
        // 4️⃣ Workout type modifier
        let typeMultiplier = getStrengthTypeMultiplier(for: workout)
        
        // 5️⃣ Calculate final strain
        // Base formula emphasizes intensity over duration
        // Target: Light session (30min, moderate) ≈ 6-8
        //         Moderate session (60min, good intensity) ≈ 10-13
        //         Hard session (75min, high intensity) ≈ 14-17
        //         Max session (90min, very high intensity) ≈ 18-21
        let baseStrain = pow(blendedIntensity, 1.3) * durationFactor * 16.0
        let adjustedStrain = baseStrain * typeMultiplier
        
        return min(adjustedStrain, 21.0)
    }
    
    // MARK: - Intensity Calculations
    
    /// Calculate HR-based intensity for strength training
    /// Accounts for intermittent nature (average HR will be lower than sustained cardio)
    private static func calculateHRIntensity(
        heartRateData: [Double]?,
        hrProfile: HeartRateProfile
    ) -> Double {
        guard let hrData = heartRateData, !hrData.isEmpty else {
            return 0 // Return 0 to signal no HR data (not a default moderate value)
        }
        
        let avgHR = hrData.reduce(0, +) / Double(hrData.count)
        let maxHR = hrProfile.maxHeartRate
        let restHR = hrProfile.restingHeartRate
        let hrReserve = maxHR - restHR
        
        // Calculate % of HR reserve
        let percentReserve = (avgHR - restHR) / hrReserve
        
        // For strength training, 50-60% HR reserve is normal/good
        // Scale accordingly (higher ceiling than raw percentage suggests)
        switch percentReserve {
        case ..<0.35: // Very light
            return 0.4
        case 0.35..<0.50: // Light to moderate
            return 0.65
        case 0.50..<0.65: // Moderate to hard (typical good session)
            return 0.85
        case 0.65..<0.75: // Hard (circuit-style or short rests)
            return 1.05
        case 0.75...: // Very hard (HIIT-style strength or metabolic)
            return 1.25
        default:
            return 0.65
        }
    }
    
    /// Calculate calorie-based intensity
    private static func calculateCalorieIntensity(calories: Double, duration: Double) -> Double {
        let caloriesPerMinute = calories / duration
        
        // Strength training burns 4-10 cal/min typically
        // Lower than cardio but should still register as intense
        switch caloriesPerMinute {
        case ..<3: // Very light
            return 0.4
        case 3..<5: // Light
            return 0.6
        case 5..<7: // Moderate
            return 0.8
        case 7..<9: // Hard
            return 1.0
        case 9...: // Very hard
            return 1.2
        default:
            return 0.7
        }
    }
    
    /// Calculate duration factor for strength training
    /// Gentler curve than cardio since rest periods are built in
    private static func calculateDurationFactor(duration: Double) -> Double {
        switch duration {
        case ..<30: // Very short
            return 0.6
        case 30..<45: // Short session
            return 0.8
        case 45..<60: // Standard session
            return 1.0
        case 60..<75: // Long session
            return 1.15
        case 75..<90: // Very long session
            return 1.25
        case 90...: // Extended session
            return 1.35
        default:
            return 1.0
        }
    }
    
    /// Get multiplier based on specific strength training type
    private static func getStrengthTypeMultiplier(for workout: HKWorkout) -> Double {
        switch workout.workoutActivityType {
        case .functionalStrengthTraining:
            return 1.15 // Circuit-style, higher cardio component
        case .traditionalStrengthTraining:
            return 1.0 // Standard lifting
        case .highIntensityIntervalTraining:
            return 1.25 // If HIIT with weights
        case .coreTraining:
            return 0.9 // Typically lower strain
        case .flexibility:
            return 0.6 // Mobility work
        default:
            return 1.0
        }
    }
}
