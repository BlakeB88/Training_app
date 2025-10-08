//
//  WorkoutQuery.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

/// Handles all workout-related HealthKit queries
class WorkoutQuery {
    
    private let healthStore: HKHealthStore
    
    // MARK: - Initialization
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    // MARK: - Workout Queries
    
    /// Fetch today's workouts
    func fetchTodaysWorkouts() async throws -> [HKWorkout] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        return try await fetchWorkouts(from: today, to: tomorrow)
    }
    
    /// Fetch workouts within a date range
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch workouts of a specific type
    func fetchWorkouts(
        ofType workoutType: HKWorkoutActivityType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKWorkout] {
        let datePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: .strictStartDate
        )
        
        let typePredicate = HKQuery.predicateForWorkouts(with: workoutType)
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, typePredicate])
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: compoundPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workouts = samples as? [HKWorkout] ?? []
                continuation.resume(returning: workouts)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch the most recent workout
    func fetchLatestWorkout() async throws -> HKWorkout? {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: nil,
                limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let workout = samples?.first as? HKWorkout
                continuation.resume(returning: workout)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Heart Rate Queries
    
    /// Fetch heart rate data for a specific workout
    func fetchHeartRateData(for workout: HKWorkout) async throws -> [Double] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRates = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                } ?? []
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch heart rate samples with timestamps for a workout
    func fetchHeartRateSamples(for workout: HKWorkout) async throws -> [(date: Date, heartRate: Double)] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let heartRates = (samples as? [HKQuantitySample])?.map { sample in
                    (
                        date: sample.startDate,
                        heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []
                
                continuation.resume(returning: heartRates)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch resting heart rate
    func fetchRestingHeartRate() async throws -> Double? {
        let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let rhr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: rhr)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Statistics
    
    /// Get detailed workout statistics
    func fetchWorkoutStatistics(for workout: HKWorkout) async throws -> WorkoutStatistics {
        let heartRates = try await fetchHeartRateData(for: workout)
        
        let avgHeartRate = heartRates.isEmpty ? nil : heartRates.reduce(0.0, +) / Double(heartRates.count)
        let maxHeartRate = heartRates.max()
        let minHeartRate = heartRates.min()
        
        // Get calories using the new API
        let calories: Double
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyStats = workout.statistics(for: energyType),
           let energySum = energyStats.sumQuantity() {
            calories = energySum.doubleValue(for: .kilocalorie())
        } else {
            calories = 0
        }
        
        let distance = workout.totalDistance?.doubleValue(for: .meter())
        
        return WorkoutStatistics(
            workout: workout,
            averageHeartRate: avgHeartRate,
            maxHeartRate: maxHeartRate,
            minHeartRate: minHeartRate,
            calories: calories,
            distance: distance,
            heartRateSamples: heartRates.count
        )
    }
    
    /// Start observing workout changes
    func startObserving(handler: @escaping () -> Void) {
        let workoutType = HKObjectType.workoutType()
        
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { _, completionHandler, error in
            if error != nil {
                completionHandler()
                return
            }
            
            DispatchQueue.main.async {
                handler()
            }
            completionHandler()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }
}

// MARK: - Workout Statistics Model

struct WorkoutStatistics {
    let workout: HKWorkout
    let averageHeartRate: Double?
    let maxHeartRate: Double?
    let minHeartRate: Double?
    let calories: Double
    let distance: Double?
    let heartRateSamples: Int
    
    var duration: TimeInterval {
        workout.duration
    }
    
    var durationMinutes: Double {
        duration / 60.0
    }
    
    var workoutType: HKWorkoutActivityType {
        workout.workoutActivityType
    }
    
    var startDate: Date {
        workout.startDate
    }
    
    var endDate: Date {
        workout.endDate
    }
    
    var pace: Double? {
        guard let distance = distance, distance > 0, duration > 0 else { return nil }
        // Returns minutes per kilometer
        return (duration / 60.0) / (distance / 1000.0)
    }
    
    var speed: Double? {
        guard let distance = distance, duration > 0 else { return nil }
        // Returns meters per second
        return distance / duration
    }
}
