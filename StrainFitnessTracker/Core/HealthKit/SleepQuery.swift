//
//  SleepQuery.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

/// Handles all sleep-related HealthKit queries
class SleepQuery {
    
    private let healthStore: HKHealthStore
    
    // MARK: - Initialization
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    // MARK: - Sleep Queries
    
    /// Fetch last night's sleep data
    func fetchLastNightSleep() async throws -> SleepData? {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let yesterdayEvening = calendar.date(byAdding: .hour, value: -12, to: startOfToday)!
        
        return try await fetchSleepData(from: yesterdayEvening, to: now)
    }
    
    /// Fetch sleep data for a specific date range
    func fetchSleepData(from startDate: Date, to endDate: Date) async throws -> SleepData? {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let samples = samples as? [HKCategorySample], !samples.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let sleepData = self.processSleepSamples(samples)
                continuation.resume(returning: sleepData)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch total sleep duration for a date range
    func fetchSleepDuration(from startDate: Date, to endDate: Date) async throws -> Double {
        guard let sleepData = try await fetchSleepData(from: startDate, to: endDate) else {
            return 0.0
        }
        return sleepData.totalDuration
    }
    
    /// Fetch sleep samples for multiple days
    func fetchDailySleepData(from startDate: Date, to endDate: Date) async throws -> [SleepData] {
        let calendar = Calendar.current
        var sleepDataArray: [SleepData] = []
        
        var currentDate = startDate
        while currentDate <= endDate {
            let dayStart = calendar.startOfDay(for: currentDate)
            let previousEvening = calendar.date(byAdding: .hour, value: -12, to: dayStart)!
            let nextMorning = calendar.date(byAdding: .hour, value: 12, to: dayStart)!
            
            if let sleepData = try await fetchSleepData(from: previousEvening, to: nextMorning) {
                sleepDataArray.append(sleepData)
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return sleepDataArray
    }
    
    /// Start observing sleep changes
    func startObserving(handler: @escaping () -> Void) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        
        let query = HKObserverQuery(sampleType: sleepType, predicate: nil) { _, completionHandler, error in
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
        healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { _, _ in }
    }
    
    // MARK: - Private Helpers
    
    private func processSleepSamples(_ samples: [HKCategorySample]) -> SleepData {
        var totalAsleep: TimeInterval = 0
        var totalInBed: TimeInterval = 0
        var deepSleep: TimeInterval = 0
        var remSleep: TimeInterval = 0
        var coreSleep: TimeInterval = 0
        var awake: TimeInterval = 0
        
        var sleepStart: Date?
        var sleepEnd: Date?
        
        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            
            // Track overall sleep period
            if sleepStart == nil || sample.startDate < sleepStart! {
                sleepStart = sample.startDate
            }
            if sleepEnd == nil || sample.endDate > sleepEnd! {
                sleepEnd = sample.endDate
            }
            
            switch sample.value {
            case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                coreSleep += duration
                totalAsleep += duration
                
            case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                deepSleep += duration
                totalAsleep += duration
                
            case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                remSleep += duration
                totalAsleep += duration
                
            case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                totalAsleep += duration
                
            case HKCategoryValueSleepAnalysis.awake.rawValue:
                awake += duration
                totalInBed += duration
                
            case HKCategoryValueSleepAnalysis.inBed.rawValue:
                totalInBed += duration
                
            default:
                break
            }
        }
        
        totalInBed += totalAsleep
        
        return SleepData(
            startDate: sleepStart ?? Date(),
            endDate: sleepEnd ?? Date(),
            totalDuration: totalAsleep / 3600.0, // Convert to hours
            inBedDuration: totalInBed / 3600.0,
            deepSleepDuration: deepSleep / 3600.0,
            remSleepDuration: remSleep / 3600.0,
            coreSleepDuration: coreSleep / 3600.0,
            awakeDuration: awake / 3600.0
        )
    }
}

// MARK: - Sleep Data Model

struct SleepData {
    let startDate: Date
    let endDate: Date
    let totalDuration: Double // in hours
    let inBedDuration: Double // in hours
    let deepSleepDuration: Double // in hours
    let remSleepDuration: Double // in hours
    let coreSleepDuration: Double // in hours
    let awakeDuration: Double // in hours
    
    var sleepEfficiency: Double {
        guard inBedDuration > 0 else { return 0 }
        return (totalDuration / inBedDuration) * 100
    }
    
    var hasDetailedStages: Bool {
        deepSleepDuration > 0 || remSleepDuration > 0 || coreSleepDuration > 0
    }
}
