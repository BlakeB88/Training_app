//
//  StrainCalculator.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//  Updated: 10/15/25 - Fixed swimming and strength training strain calculations
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
        
        // Cap at 21 (theoretical maximum, aligned with Whoop)
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
        
        // Special handling for strength training
        if workout.isStrengthTraining {
            return StrengthTrainingStrainCalculator.calculateStrengthTrainingStrain(
                workout: workout,
                hrProfile: hrProfile
            )
        }
        
        // Get workout metrics for other activity types
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
        // Aligned with Whoop's logarithmic nature for diminishing returns at higher levels
        let rawStrain = log2(hrIntensity * duration + calories * 0.3 + 1) * 3
        
        return min(rawStrain, 21.0)
    }
    
    /// Calculate heart rate intensity relative to user's zones
    static func calculateHRIntensity(avgHR: Double, profile: HeartRateProfile) -> Double {
        let maxHR = profile.maxHeartRate
        let restingHR = profile.restingHeartRate
        let hrReserve = maxHR - restingHR
        
        // Karvonen formula for intensity (% of HR reserve)
        let intensity = (avgHR - restingHR) / hrReserve
        
        // Whoop-like scaling: emphasize time in higher zones
        return intensity * 1.2 // Slight boost for alignment with Whoop averages
    }
    
    /// Estimate intensity from calories when HR data unavailable
    private static func estimateIntensityFromCalories(
        calories: Double,
        duration: Double,
        workoutType: HKWorkoutActivityType
    ) -> Double {
        guard duration > 0 else { return 0.5 } // Default moderate
        
        let caloriesPerMinute = calories / duration
        // Whoop-inspired thresholds: Light <5 cal/min, Moderate 5-8, High 8-12, All Out >12
        let baseIntensity = min(caloriesPerMinute / 12.0, 1.0)
        
        // Adjust based on activity type (similar to Whoop's activity-specific modeling)
        let typeMultiplier = activityMultiplier(for: workoutType)
        
        return baseIntensity * typeMultiplier
    }
    
    /// Get activity-specific multiplier (calibrated to Whoop averages, e.g., 1h running ~12 strain)
    private static func activityMultiplier(for activityType: HKWorkoutActivityType) -> Double {
        switch activityType {
        case .highIntensityIntervalTraining:
            return 1.4 // Higher for HIIT bursts
        case .running:
            return 1.1 // Matches Whoop avg ~12 for 1h
        case .cycling:
            return 1.0
        case .rowing:
            return 1.2
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            // Should not reach here (handled by StrengthTrainingStrainCalculator)
            return 1.1
        case .yoga, .flexibility:
            return 0.6 // Lower CV, but some muscular
        case .walking:
            return 0.7 // Whoop avg ~6.5 for 1h
        case .hiking:
            return 0.95
        case .elliptical:
            return 0.95
        case .stairClimbing:
            return 1.15
        default:
            return 1.0
        }
    }
    
    /// Categorize strain level (aligned with Whoop: Light 0-9, Moderate 10-13, High 14-17, All Out 18-21)
    static func strainLevel(for strain: Double) -> StrainLevel {
        switch strain {
        case 0..<10:
            return .light
        case 10..<14:
            return .moderate
        case 14..<18:
            return .high
        case 18...21:
            return .allOut
        default:
            return .allOut // Cap at 21
        }
    }
    
    /// Get strain level description (Whoop-inspired)
    static func strainDescription(for level: StrainLevel) -> String {
        switch level {
        case .light:
            return "Light activity or recovery day"
        case .moderate:
            return "Moderate training day - maintain fitness"
        case .high:
            return "High intensity - build fitness"
        case .allOut:
            return "All-out effort - significant stress, monitor recovery"
        }
    }
}

// MARK: - Strain Level (updated to match Whoop)

enum StrainLevel {
    case light      // 0-9
    case moderate   // 10-13
    case high       // 14-17
    case allOut     // 18-21
    
    var color: String {
        switch self {
        case .light: return "green"
        case .moderate: return "yellow"
        case .high: return "orange"
        case .allOut: return "red"
        }
    }
}
