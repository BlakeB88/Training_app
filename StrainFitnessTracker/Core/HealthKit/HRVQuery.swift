//
//  HRVQuery.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

/// Handles all HRV (Heart Rate Variability) related HealthKit queries
class HRVQuery {
    
    private let healthStore: HKHealthStore
    
    // MARK: - Initialization
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    // MARK: - HRV Queries
    
    /// Fetch the most recent HRV reading
    func fetchLatestHRV() async throws -> Double? {
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
                
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: hrv)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch all HRV readings within a date range
    func fetchHRVReadings(from startDate: Date, to endDate: Date) async throws -> [Double] {
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
                
                let readings = (samples as? [HKQuantitySample])?.map {
                    $0.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                } ?? []
                
                continuation.resume(returning: readings)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch HRV readings with timestamps
    func fetchHRVSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, value: Double)] {
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
                
                let readings = (samples as? [HKQuantitySample])?.map { sample in
                    (
                        date: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    )
                } ?? []
                
                continuation.resume(returning: readings)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch average HRV for a date range
    func fetchAverageHRV(from startDate: Date, to endDate: Date) async throws -> Double? {
        let readings = try await fetchHRVReadings(from: startDate, to: endDate)
        guard !readings.isEmpty else { return nil }
        return readings.reduce(0.0, +) / Double(readings.count)
    }
    
    /// Fetch daily HRV averages for a date range
    func fetchDailyHRVAverages(from startDate: Date, to endDate: Date) async throws -> [(date: Date, average: Double)] {
        let samples = try await fetchHRVSamples(from: startDate, to: endDate)
        
        // Group by day
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.date)
        }
        
        // Calculate averages
        return grouped.map { date, samples in
            let average = samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
            return (date: date, average: average)
        }.sorted { $0.date < $1.date }
    }
    
    /// Fetch morning HRV (first reading of the day, typically most reliable)
    func fetchMorningHRV(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let morningEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart)!
        
        let samples = try await fetchHRVSamples(from: dayStart, to: morningEnd)
        return samples.first?.value
    }
    
    /// Start observing HRV changes
    func startObserving(handler: @escaping () -> Void) {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
        
        let query = HKObserverQuery(sampleType: hrvType, predicate: nil) { _, completionHandler, error in
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
        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { _, _ in }
    }
}
