//
//  StrainCalculator.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

struct StrainCalculator {
    
    /// Calculate total daily strain from all workouts
    /// - Parameters:
    ///   - workouts: Array of workouts for the day
    ///   - profile: User's heart rate profile
    /// - Returns: Total strain score (0-21 scale)
    static func calculateDailyStrain(
        workouts: [HKWorkout],
        hrProfile: HeartRateProfile
    ) async -> Double {
        var totalStrain = 0.0
        
        for workout in workouts {
            let workoutStrain = await calculateWorkoutStrain(workout: workout, hrProfile: hrProfile)
            totalStrain += workoutStrain
        }
        
        // Cap at 21 (theoretical maximum)
        return min(totalStrain, 21.0)
    }
    
    /// Calculate strain for a single workout
    /// - Parameters:
    ///   - workout: The workout to calculate strain for
    ///   - profile: User's heart rate profile
    /// - Returns: Strain score for this workout
    static func calculateWorkoutStrain(
        workout: HKWorkout,
        hrProfile: HeartRateProfile
    ) async -> Double {
        // Special handling for swimming
        if workout.isSwimming {
            return SwimmingStrainCalculator.calculateSwimmingStrain(
                workout: workout,
                hrProfile: hrProfile
            )
        }
        
        // Get workout metrics
        let duration = workout.durationMinutes
        let calories = workout.activeCalories
        
        // Try to get heart rate data
        let hrIntensity: Double
        if let avgHR = workout.averageHeartRate {
            hrIntensity = calculateHRIntensity(avgHR: avgHR, profile: hrProfile)
        } else {
            // Fallback: estimate from calories and duration
            hrIntensity = estimateIntensityFromCalories(
                calories: calories,
                duration: duration,
                workoutType: workout.workoutActivityType
            )
        }
        
        // Strain formula: log₂(HR_Intensity × Duration + Calories × 0.3 + 1) × 3
        let rawStrain = log2(hrIntensity * duration + calories * 0.3 + 1) * 3
        
        // Apply activity type multiplier
        let multiplier = activityMultiplier(for: workout.workoutActivityType)
        
        return rawStrain * multiplier
    }
    
    /// Calculate heart rate intensity factor
    /// - Parameters:
    ///   - avgHR: Average heart rate during workout
    ///   - profile: User's heart rate profile
    /// - Returns: Intensity factor (0-1 scale, but can exceed 1 for very high intensity)
    static func calculateHRIntensity(avgHR: Double, profile: HeartRateProfile) -> Double {
        let hrReserve = profile.maxHeartRate - profile.restingHeartRate
        let workingHR = avgHR - profile.restingHeartRate
        
        // Calculate percentage of heart rate reserve
        let intensity = workingHR / hrReserve
        
        // Clamp between 0 and 1.5 (allow for some overshoot)
        return max(0, min(intensity, 1.5))
    }
    
    /// Estimate intensity when HR data is not available
    private static func estimateIntensityFromCalories(
        calories: Double,
        duration: Double,
        workoutType: HKWorkoutActivityType
    ) -> Double {
        // Calories per minute as intensity proxy
        let caloriesPerMinute = duration > 0 ? calories / duration : 0
        
        // Rough intensity estimation based on calories/min
        // Light: 3-5 cal/min, Moderate: 5-8 cal/min, Hard: 8-12 cal/min, Very Hard: 12+ cal/min
        let baseIntensity = min(caloriesPerMinute / 12.0, 1.0)
        
        // Adjust based on activity type
        let typeMultiplier = activityMultiplier(for: workoutType)
        
        return baseIntensity * typeMultiplier
    }
    
    /// Get activity-specific multiplier
    private static func activityMultiplier(for activityType: HKWorkoutActivityType) -> Double {
        switch activityType {
        case .highIntensityIntervalTraining:
            return 1.3
        case .running:
            return 1.1
        case .cycling:
            return 1.0
        case .rowing:
            return 1.2
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return 0.9
        case .yoga, .flexibility:
            return 0.5
        case .walking:
            return 0.7
        case .hiking:
            return 0.9
        case .elliptical:
            return 0.95
        case .stairClimbing:
            return 1.1
        default:
            return 1.0
        }
    }
    
    /// Categorize strain level
    static func strainLevel(for strain: Double) -> StrainLevel {
        switch strain {
        case 0..<6:
            return .light
        case 6..<11:
            return .moderate
        case 11..<16:
            return .hard
        default:
            return .veryHard
        }
    }
    
    /// Get strain level description
    static func strainDescription(for level: StrainLevel) -> String {
        switch level {
        case .light:
            return "Light activity or recovery day"
        case .moderate:
            return "Moderate training day"
        case .hard:
            return "Hard training day"
        case .veryHard:
            return "Very hard or all-out effort"
        }
    }
}

// MARK: - Strain Level

enum StrainLevel {
    case light      // 0-5
    case moderate   // 6-10
    case hard       // 11-15
    case veryHard   // 16-21
    
    var color: String {
        switch self {
        case .light: return "green"
        case .moderate: return "yellow"
        case .hard: return "orange"
        case .veryHard: return "red"
        }
    }
}
