//
//  HealthKitTypes.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import HealthKit

struct HealthKitTypes {
    
    // MARK: - Read Types
    static let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        
        // Workout data
        types.insert(HKObjectType.workoutType())
        
        // Heart rate metrics
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let heartRateVariability = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(heartRateVariability)
        }
        if let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }
        
        // Energy and activity
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        
        // Distance metrics
        if let swimmingDistance = HKObjectType.quantityType(forIdentifier: .distanceSwimming) {
            types.insert(swimmingDistance)
        }
        if let cyclingDistance = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingDistance)
        }
        if let walkingRunningDistance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(walkingRunningDistance)
        }
        
        // Sleep analysis
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }
        
        // Respiratory rate
        if let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        
        return types
    }()
    
    // MARK: - Write Types (if needed in future)
    static let writeTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()
        // Currently no write permissions needed
        return types
    }()
    
    // MARK: - Workout Types
    static let supportedWorkoutTypes: [HKWorkoutActivityType] = [
        .swimming,
        .running,
        .cycling,
        .walking,
        .hiking,
        .rowing,
        .functionalStrengthTraining,
        .traditionalStrengthTraining,
        .coreTraining,
        .yoga,
        .crossTraining,
        .elliptical,
        .stairClimbing,
        .highIntensityIntervalTraining
    ]
    
    // MARK: - Swimming Stroke Types
    static let swimmingStrokes: [HKSwimmingStrokeStyle] = [
        .freestyle,
        .backstroke,
        .breaststroke,
        .butterfly,
        .mixed
    ]
}
