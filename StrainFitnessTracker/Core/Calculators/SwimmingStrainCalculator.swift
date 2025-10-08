//
//  SwimmingStrainCalculator.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

struct SwimmingStrainCalculator {
    
    /// Calculate strain specifically for swimming workouts
    /// Swimming HR is often unreliable underwater, so we use pace and calories
    static func calculateSwimmingStrain(
        workout: HKWorkout,
        hrProfile: HeartRateProfile
    ) -> Double {
        let duration = workout.durationMinutes
        let calories = workout.activeCalories
        let distance = workout.swimmingDistance ?? 0
        
        // Calculate pace (minutes per 100m)
        let pace = distance > 0 ? (duration / (distance / 100.0)) : 0
        
        // Estimate intensity from pace and calories
        let paceIntensity = calculatePaceIntensity(pace: pace)
        let calorieIntensity = calories / duration / 12.0 // Normalize to ~12 cal/min max
        
        // Combine pace and calorie intensity
        let combinedIntensity = (paceIntensity * 0.6 + calorieIntensity * 0.4)
        
        // Apply stroke type multiplier
        let strokeMultiplier = getStrokeMultiplier(for: workout)
        
        // Calculate base strain
        let baseStrain = log2(combinedIntensity * duration + calories * 0.3 + 1) * 3
        
        return baseStrain * strokeMultiplier
    }
    
    /// Calculate intensity from swimming pace
    /// - Parameter pace: Minutes per 100 meters
    /// - Returns: Intensity factor (0-1.5)
    private static func calculatePaceIntensity(pace: Double) -> Double {
        guard pace > 0 else { return 0.5 } // Default moderate intensity
        
        // Pace intensity scale (approximate for freestyle)
        // Easy: 2.5+ min/100m
        // Moderate: 1.8-2.5 min/100m
        // Hard: 1.3-1.8 min/100m
        // Very Hard: <1.3 min/100m
        
        switch pace {
        case ..<1.3:
            return 1.4 // Very hard
        case 1.3..<1.8:
            return 1.1 // Hard
        case 1.8..<2.5:
            return 0.8 // Moderate
        default:
            return 0.5 // Easy
        }
    }
    
    /// Get stroke-specific multiplier
    private static func getStrokeMultiplier(for workout: HKWorkout) -> Double {
        // Try to get stroke type from metadata
        if let strokeType = workout.metadata?[HKMetadataKeySwimmingStrokeStyle] as? Int {
            return strokeMultiplier(for: HKSwimmingStrokeStyle(rawValue: strokeType) ?? .freestyle)
        }
        
        // Default to freestyle
        return 1.0
    }
    
    /// Stroke-specific multipliers based on energy expenditure
    private static func strokeMultiplier(for strokeStyle: HKSwimmingStrokeStyle) -> Double {
        switch strokeStyle {
        case .freestyle:
            return 1.0
        case .backstroke:
            return 1.1
        case .breaststroke:
            return 1.2
        case .butterfly:
            return 1.4
        case .mixed:
            return 1.2 // Individual Medley average
        default:
            return 1.0
        }
    }
    
    /// Estimate average heart rate for swimming when not available
    /// This is used as a fallback for display purposes
    static func estimateSwimmingHeartRate(
        pace: Double,
        hrProfile: HeartRateProfile
    ) -> Double {
        let intensity = calculatePaceIntensity(pace: pace)
        let hrReserve = hrProfile.maxHeartRate - hrProfile.restingHeartRate
        
        // Estimate HR based on intensity
        return hrProfile.restingHeartRate + (hrReserve * intensity * 0.7) // 0.7 factor for swimming
    }
}
