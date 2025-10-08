//
//  WorkoutSummary.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

/// Represents a summarized workout with calculated strain
struct WorkoutSummary {
    
    // MARK: - Basic Properties
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval // in seconds
    
    // MARK: - Metrics
    let distance: Double? // in meters
    let calories: Double // active calories
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    
    // MARK: - Swimming Specific
    let swimmingStrokeStyle: HKSwimmingStrokeStyle?
    let lapCount: Int?
    
    // MARK: - Calculated Values
    let strain: Double
    let heartRateIntensity: Double? // 0-1 scale
    
    // MARK: - Computed Properties
    
    var workoutTypeName: String {
        return workoutType.name
    }
    
    var durationFormatted: String {
        return duration.formattedDuration()
    }
    
    var distanceFormatted: String? {
        guard let dist = distance else { return nil }
        return dist.formattedDistance()
    }
    
    var caloriesFormatted: String {
        return calories.formattedCalories()
    }
    
    var strainFormatted: String {
        return strain.formattedStrain()
    }
    
    var strainLevel: String {
        return strain.strainLevel()
    }
    
    var isSwimming: Bool {
        return workoutType == .swimming
    }
    
    var pace: Double? {
        guard let dist = distance, dist > 0, duration > 0 else {
            return nil
        }
        // Return seconds per 100m (or per 100 yards)
        return (duration / dist) * 100.0
    }
    
    var paceFormatted: String? {
        guard let paceValue = pace else { return nil }
        let minutes = Int(paceValue) / 60
        let seconds = Int(paceValue) % 60
        return String(format: "%d:%02d/100m", minutes, seconds)
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        workoutType: HKWorkoutActivityType,
        startDate: Date,
        endDate: Date,
        duration: TimeInterval,
        distance: Double? = nil,
        calories: Double,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil,
        swimmingStrokeStyle: HKSwimmingStrokeStyle? = nil,
        lapCount: Int? = nil,
        strain: Double,
        heartRateIntensity: Double? = nil
    ) {
        self.id = id
        self.workoutType = workoutType
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distance = distance
        self.calories = calories
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.swimmingStrokeStyle = swimmingStrokeStyle
        self.lapCount = lapCount
        self.strain = strain
        self.heartRateIntensity = heartRateIntensity
    }
    
    // MARK: - Convenience Initializer from HKWorkout
    init(from workout: HKWorkout, strain: Double, heartRateIntensity: Double? = nil) {
        self.id = UUID()
        self.workoutType = workout.workoutActivityType
        self.startDate = workout.startDate
        self.endDate = workout.endDate
        self.duration = workout.duration
        self.distance = workout.totalDistance?.doubleValue(for: .meter())
        
        // Use statistics API for energy
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyStats = workout.statistics(for: energyType) {
            self.calories = energyStats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        } else {
            self.calories = 0
        }
        
        self.averageHeartRate = nil // Will be populated separately
        self.maxHeartRate = nil
        
        // Safely handle swimming-specific properties
        if workout.workoutActivityType == .swimming {
            self.swimmingStrokeStyle = nil // Will be populated from workout metadata
            self.lapCount = nil // Will be populated from workout metadata
        } else {
            self.swimmingStrokeStyle = nil
            self.lapCount = nil
        }
        
        self.strain = strain
        self.heartRateIntensity = heartRateIntensity
    }
}

// MARK: - HKWorkoutActivityType Extension
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .swimming: return "Swimming"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .rowing: return "Rowing"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .coreTraining: return "Core Training"
        case .yoga: return "Yoga"
        case .crossTraining: return "Cross Training"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
    
    var emoji: String {
        switch self {
        case .swimming: return "🏊"
        case .running: return "🏃"
        case .cycling: return "🚴"
        case .walking: return "🚶"
        case .hiking: return "🥾"
        case .rowing: return "🚣"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "💪"
        case .coreTraining: return "🧘"
        case .yoga: return "🧘‍♀️"
        case .highIntensityIntervalTraining: return "🔥"
        default: return "⚡"
        }
    }
}

// MARK: - HKSwimmingStrokeStyle Extension
extension HKSwimmingStrokeStyle {
    var name: String {
        switch self {
        case .freestyle: return "Freestyle"
        case .backstroke: return "Backstroke"
        case .breaststroke: return "Breaststroke"
        case .butterfly: return "Butterfly"
        case .mixed: return "Mixed"
        case .kickboard: return "Kickboard"
        case .unknown: return "Unknown"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Codable Conformance
extension WorkoutSummary: Codable {
    enum CodingKeys: String, CodingKey {
        case id, startDate, endDate, duration, distance, calories
        case averageHeartRate, maxHeartRate, lapCount, strain, heartRateIntensity
        case workoutTypeRawValue, swimmingStrokeStyleRawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        let workoutTypeRaw = try container.decode(UInt.self, forKey: .workoutTypeRawValue)
        workoutType = HKWorkoutActivityType(rawValue: workoutTypeRaw) ?? .other
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        calories = try container.decode(Double.self, forKey: .calories)
        averageHeartRate = try container.decodeIfPresent(Double.self, forKey: .averageHeartRate)
        maxHeartRate = try container.decodeIfPresent(Double.self, forKey: .maxHeartRate)
        
        if let strokeRaw = try container.decodeIfPresent(Int.self, forKey: .swimmingStrokeStyleRawValue) {
            swimmingStrokeStyle = HKSwimmingStrokeStyle(rawValue: strokeRaw)
        } else {
            swimmingStrokeStyle = nil
        }
        
        lapCount = try container.decodeIfPresent(Int.self, forKey: .lapCount)
        strain = try container.decode(Double.self, forKey: .strain)
        heartRateIntensity = try container.decodeIfPresent(Double.self, forKey: .heartRateIntensity)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(workoutType.rawValue, forKey: .workoutTypeRawValue)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(endDate, forKey: .endDate)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(distance, forKey: .distance)
        try container.encode(calories, forKey: .calories)
        try container.encodeIfPresent(averageHeartRate, forKey: .averageHeartRate)
        try container.encodeIfPresent(maxHeartRate, forKey: .maxHeartRate)
        try container.encodeIfPresent(swimmingStrokeStyle?.rawValue, forKey: .swimmingStrokeStyleRawValue)
        try container.encodeIfPresent(lapCount, forKey: .lapCount)
        try container.encode(strain, forKey: .strain)
        try container.encodeIfPresent(heartRateIntensity, forKey: .heartRateIntensity)
    }
}

// MARK: - Identifiable Conformance
extension WorkoutSummary: Identifiable {}

// MARK: - Equatable Conformance
extension WorkoutSummary: Equatable {}
