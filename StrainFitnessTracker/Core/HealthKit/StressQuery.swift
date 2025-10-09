//
//  StressQuery.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import Foundation
import HealthKit

/// Handles HealthKit queries specifically for stress monitoring
class StressQuery {
    
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    // MARK: - Heart Rate Queries
    
    /// Fetch continuous heart rate data for a time period
    func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> [(timestamp: Date, heartRate: Double)] {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
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
                
                let heartRateData = (samples as? [HKQuantitySample])?.map { sample in
                    (
                        timestamp: sample.startDate,
                        heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    )
                } ?? []
                
                continuation.resume(returning: heartRateData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch the most recent heart rate reading
    func fetchLatestHeartRate() async throws -> (timestamp: Date, heartRate: Double)? {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
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
                
                let result = (
                    timestamp: sample.startDate,
                    heartRate: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                )
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch resting heart rate for baseline calculation
    func fetchRestingHeartRate(for date: Date = Date()) async throws -> Double? {
        let rhrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        // Get RHR from the last 7 days for more stable baseline
        let endDate = Calendar.current.startOfDay(for: date.addingTimeInterval(86400))
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: rhrType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Average the last 7 days of RHR for a stable baseline
                let rhrValues = samples.map { $0.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) }
                let averageRHR = rhrValues.reduce(0.0, +) / Double(rhrValues.count)
                
                continuation.resume(returning: averageRHR)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - HRV Queries
    
    /// Fetch HRV data for a time period
    func fetchHRVData(from startDate: Date, to endDate: Date) async throws -> [(timestamp: Date, hrv: Double)] {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let hrvData = (samples as? [HKQuantitySample])?.map { sample in
                    (
                        timestamp: sample.startDate,
                        hrv: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    )
                } ?? []
                
                continuation.resume(returning: hrvData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch baseline HRV (average from last 7 days)
    func fetchBaselineHRV(for date: Date = Date()) async throws -> Double? {
        let endDate = Calendar.current.startOfDay(for: date.addingTimeInterval(86400))
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        let hrvData = try await fetchHRVData(from: startDate, to: endDate)
        
        guard !hrvData.isEmpty else { return nil }
        
        let hrvValues = hrvData.map { $0.hrv }
        return hrvValues.reduce(0.0, +) / Double(hrvValues.count)
    }
    
    /// Fetch the most recent HRV reading
    func fetchLatestHRV() async throws -> (timestamp: Date, hrv: Double)? {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
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
                
                let result = (
                    timestamp: sample.startDate,
                    hrv: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                )
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Workout Context Queries
    
    /// Check if there's an active or recent workout at a given time
    func isWorkoutActive(at timestamp: Date, bufferMinutes: Int = 60) async throws -> Bool {
        let bufferSeconds = TimeInterval(bufferMinutes * 60)
        let startDate = timestamp.addingTimeInterval(-bufferSeconds)
        let endDate = timestamp.addingTimeInterval(bufferSeconds)
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let hasWorkout = !(samples?.isEmpty ?? true)
                continuation.resume(returning: hasWorkout)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch all workouts for a time period (to filter exercise-related stress)
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
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
    
    // MARK: - Combined Stress Data Query
    
    /// Fetch all data needed for stress calculation in one go
    func fetchStressContextData(from startDate: Date, to endDate: Date) async throws -> StressContextData {
        async let heartRateData = fetchHeartRateData(from: startDate, to: endDate)
        async let hrvData = fetchHRVData(from: startDate, to: endDate)
        async let workouts = fetchWorkouts(from: startDate, to: endDate)
        async let baselineRHR = fetchRestingHeartRate(for: startDate)
        async let baselineHRV = fetchBaselineHRV(for: startDate)
        
        return try await StressContextData(
            heartRateReadings: heartRateData,
            hrvReadings: hrvData,
            workouts: workouts,
            baselineRestingHeartRate: baselineRHR,
            baselineHRV: baselineHRV
        )
    }
}

// MARK: - Supporting Types

struct StressContextData {
    let heartRateReadings: [(timestamp: Date, heartRate: Double)]
    let hrvReadings: [(timestamp: Date, hrv: Double)]
    let workouts: [HKWorkout]
    let baselineRestingHeartRate: Double?
    let baselineHRV: Double?
    
    /// Check if a timestamp falls within or near a workout
    func isWorkoutRelated(timestamp: Date, bufferMinutes: Int = 60) -> Bool {
        let buffer = TimeInterval(bufferMinutes * 60)
        
        return workouts.contains { workout in
            let workoutStart = workout.startDate.addingTimeInterval(-buffer)
            let workoutEnd = workout.endDate.addingTimeInterval(buffer)
            return timestamp >= workoutStart && timestamp <= workoutEnd
        }
    }
    
    /// Find HRV reading closest to a timestamp
    func findNearestHRV(to timestamp: Date, withinMinutes: Int = 30) -> Double? {
        let maxInterval = TimeInterval(withinMinutes * 60)
        
        let closest = hrvReadings.min { reading1, reading2 in
            abs(reading1.timestamp.timeIntervalSince(timestamp)) < abs(reading2.timestamp.timeIntervalSince(timestamp))
        }
        
        guard let hrvReading = closest,
              abs(hrvReading.timestamp.timeIntervalSince(timestamp)) <= maxInterval else {
            return nil
        }
        
        return hrvReading.hrv
    }
}
