//
//  HKWorkout+Extensions.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import HealthKit

extension HKWorkout {
    /// Returns true if this is a swimming workout
    var isSwimming: Bool {
        workoutActivityType == .swimming ||
        workoutActivityType == .swimBikeRun
    }
    
    var isStrengthTraining: Bool {
        workoutActivityType == .traditionalStrengthTraining ||
        workoutActivityType == .functionalStrengthTraining
    }
    
    /// Returns the stroke type for swimming workouts
    var swimmingStrokeStyle: HKWorkoutSwimmingLocationType? {
        guard isSwimming else { return nil }
        return metadata?[HKMetadataKeySwimmingLocationType] as? HKWorkoutSwimmingLocationType
    }
    
    /// Returns average heart rate if available
    var averageHeartRate: Double? {
        guard let avgHR = allStatistics[HKQuantityType.quantityType(forIdentifier: .heartRate)!] else {
            return nil
        }
        return avgHR.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
    }
    
    /// Returns total active calories burned
    var activeCalories: Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }
        
        // Try allStatistics first
        if let calories = allStatistics[energyType] {
            return calories.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }
        
        // Fallback to statisticsForType
        if let stats = statistics(for: energyType) {
            return stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        }
        
        return 0
    }
    
    /// Returns swimming distance in meters
    var swimmingDistance: Double? {
        guard isSwimming else { return nil }
        return totalDistance?.doubleValue(for: .meter())
    }
    
    /// Returns workout duration in minutes
    var durationMinutes: Double {
        duration / 60.0
    }
    
    /// Returns a user-friendly activity name
    var activityName: String {
        switch workoutActivityType {
        case .swimming: return "Swimming"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .yoga: return "Yoga"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
    
    /// Returns an emoji for the activity type
    var activityEmoji: String {
        switch workoutActivityType {
        case .swimming: return "🏊"
        case .running: return "🏃"
        case .cycling: return "🚴"
        case .walking: return "🚶"
        case .hiking: return "🥾"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "💪"
        case .yoga: return "🧘"
        case .rowing: return "🚣"
        case .elliptical: return "⚙️"
        case .stairClimbing: return "🪜"
        case .highIntensityIntervalTraining: return "🔥"
        default: return "⚡"
        }
    }
}
