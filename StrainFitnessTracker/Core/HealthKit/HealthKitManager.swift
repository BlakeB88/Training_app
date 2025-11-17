//
//  HealthKitManager.swift (UPDATED WITH STRESS MONITORING)
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/1/25.
//  Updated: 10/8/25 - Added stress monitoring capabilities
//

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    let healthStore = HKHealthStore()
    @Published private(set) var isAuthorized = false
    
    // MARK: - HealthKit Types
    
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .vo2Max)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .dietaryProtein)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates)!,
        HKObjectType.quantityType(forIdentifier: .dietaryFatTotal)!,
        HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
        HKObjectType.quantityType(forIdentifier: .dietaryCaffeine)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.quantityType(forIdentifier: .bodyFatPercentage)!,
        HKObjectType.quantityType(forIdentifier: .leanBodyMass)!,
        HKObjectType.quantityType(forIdentifier: .height)!
    ]
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        await MainActor.run {
            isAuthorized = true
        }
    }
    
    // Completion-based version for compatibility
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthKitError.notAvailable)
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isAuthorized = success
                completion(success, error)
            }
        }
    }
    
    // MARK: - Workout Queries
    
    func fetchTodaysWorkouts() async throws -> [HKWorkout] {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: today,
            end: tomorrow,
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
    
    // MARK: - HRV Queries
    
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

    // MARK: - Body Composition Queries

    struct BodyCompositionSnapshot {
        let weight: Double?
        let bodyFatPercentage: Double?
        let leanBodyMass: Double?
        let height: Double?
    }

    func fetchBodyCompositionSnapshot() async throws -> BodyCompositionSnapshot {
        async let weightTask = fetchLatestQuantity(for: .bodyMass, unit: HKUnit.pound())
        async let fatTask = fetchLatestQuantity(for: .bodyFatPercentage, unit: HKUnit.percent())
        async let leanTask = fetchLatestQuantity(for: .leanBodyMass, unit: HKUnit.pound())
        async let heightTask = fetchLatestQuantity(for: .height, unit: HKUnit.meterUnit(with: .none))

        let (weight, bodyFatRaw, leanMass, height) = try await (weightTask, fatTask, leanTask, heightTask)
        let bodyFatPercentage = bodyFatRaw.map { $0 * 100 }

        return BodyCompositionSnapshot(
            weight: weight,
            bodyFatPercentage: bodyFatPercentage,
            leanBodyMass: leanMass,
            height: height
        )
    }

    private func fetchLatestQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
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

                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Heart Rate Queries
    
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
    
    // MARK: - NEW: Stress Monitoring Heart Rate Queries
    
    /// Fetch continuous heart rate data for stress monitoring
    func fetchContinuousHeartRate(from startDate: Date, to endDate: Date) async throws -> [(timestamp: Date, heartRate: Double)] {
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
    
    // MARK: - Sleep Queries
    
    func fetchLastNightSleep() async throws -> HKCategorySample? {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Get sleep from yesterday evening to this morning
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let yesterdayEvening = calendar.date(byAdding: .hour, value: -12, to: startOfToday)!
        
        let predicate = HKQuery.predicateForSamples(
            withStart: yesterdayEvening,
            end: now,
            options: .strictStartDate
        )
        
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
                
                let sleepSample = (samples as? [HKCategorySample])?.first {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                }
                
                continuation.resume(returning: sleepSample)
            }
            
            healthStore.execute(query)
        }
    }
    
    func fetchSleepDuration(from startDate: Date, to endDate: Date) async throws -> Double {
        let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let sleepSamples = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
                } ?? []
                
                let totalDuration = sleepSamples.reduce(0.0) { sum, sample in
                    sum + sample.endDate.timeIntervalSince(sample.startDate)
                }
                
                continuation.resume(returning: totalDuration / 3600.0) // Convert to hours
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Respiratory Rate
    
    func fetchRespiratoryRate() async throws -> Double? {
        let respType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: respType,
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
                
                let rate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: rate)
            }
            
            healthStore.execute(query)
        }
    }
    
    //
    // Add these new query methods to your HealthKitManager.swift file
    // Insert them after the existing query methods
    //

    // MARK: - Steps Queries

    /// Fetch step count for a specific date range
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.notAvailable
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            
            healthStore.execute(query)
        }
    }

    /// Fetch today's step count
    func fetchTodaySteps() async throws -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        let now = Date()
        return try await fetchStepCount(from: today, to: now)
    }

    // MARK: - VO2 Max Queries

    /// Fetch the latest VO2 Max reading
    func fetchLatestVO2Max() async throws -> Double? {
        guard let vo2MaxType = HKQuantityType.quantityType(forIdentifier: .vo2Max) else {
            throw HealthKitError.notAvailable
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: vo2MaxType,
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
                
                let vo2Max = sample.quantity.doubleValue(for: HKUnit.literUnit(with: .milli).unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute())))
                continuation.resume(returning: vo2Max)
            }
            
            healthStore.execute(query)
        }
    }

    // MARK: - Enhanced Sleep Queries

    /// Fetch detailed sleep data including time in bed
    func fetchDetailedSleepData(from startDate: Date, to endDate: Date) async throws -> SleepData {
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
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    continuation.resume(returning: SleepData(
                        totalSleepDuration: 0,
                        timeInBed: 0,
                        sleepStart: nil,
                        sleepEnd: nil,
                        restorativeSleepDuration: 0,
                        remSleepDuration: 0,
                        deepSleepDuration: 0,
                        coreSleepDuration: 0,
                        awakeDuration: 0
                    ))
                    return
                }
                
                // Calculate time in bed (from first to last sample)
                let firstSample = sleepSamples.min(by: { $0.startDate < $1.startDate })!
                let lastSample = sleepSamples.max(by: { $0.endDate < $1.endDate })!
                let timeInBed = lastSample.endDate.timeIntervalSince(firstSample.startDate)
                
                // Calculate sleep durations by stage
                var totalSleep: TimeInterval = 0
                var remSleep: TimeInterval = 0
                var deepSleep: TimeInterval = 0
                var coreSleep: TimeInterval = 0
                var awakeDuration: TimeInterval = 0
                
                for sample in sleepSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        remSleep += duration
                        totalSleep += duration
                        
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deepSleep += duration
                        totalSleep += duration
                        
                    case HKCategoryValueSleepAnalysis.asleepCore.rawValue:
                        coreSleep += duration
                        totalSleep += duration
                        
                    case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue:
                        totalSleep += duration
                        
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeDuration += duration
                        
                    default:
                        break
                    }
                }
                
                // Restorative sleep = REM + Deep sleep
                let restorativeSleep = remSleep + deepSleep
                
                let sleepData = SleepData(
                    totalSleepDuration: totalSleep,
                    timeInBed: timeInBed,
                    sleepStart: firstSample.startDate,
                    sleepEnd: lastSample.endDate,
                    restorativeSleepDuration: restorativeSleep,
                    remSleepDuration: remSleep,
                    deepSleepDuration: deepSleep,
                    coreSleepDuration: coreSleep,
                    awakeDuration: awakeDuration
                )
                
                continuation.resume(returning: sleepData)
            }
            
            healthStore.execute(query)
        }
    }

    /// Fetch last night's detailed sleep data
    func fetchLastNightDetailedSleep() async throws -> SleepData {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let yesterdayEvening = calendar.date(byAdding: .hour, value: -12, to: startOfToday)!
        
        return try await fetchDetailedSleepData(from: yesterdayEvening, to: now)
    }

    // MARK: - Sleep Data Model

    struct SleepData {
        let totalSleepDuration: TimeInterval // Actual sleep time
        let timeInBed: TimeInterval // From first to last sample
        let sleepStart: Date?
        let sleepEnd: Date?
        let restorativeSleepDuration: TimeInterval // REM + Deep
        let remSleepDuration: TimeInterval
        let deepSleepDuration: TimeInterval
        let coreSleepDuration: TimeInterval
        let awakeDuration: TimeInterval
        
        // Calculated properties
        var sleepEfficiency: Double {
            guard timeInBed > 0 else { return 0 }
            return (totalSleepDuration / timeInBed) * 100
        }
        
        var restorativeSleepPercentage: Double {
            guard totalSleepDuration > 0 else { return 0 }
            return (restorativeSleepDuration / totalSleepDuration) * 100
        }
    }
    
    // MARK: - Observers
    
    func startObservingWorkouts(handler: @escaping () -> Void) {
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
    
    func startObservingRecoveryMetrics(handler: @escaping () -> Void) {
        let types: [HKQuantityTypeIdentifier] = [
            .heartRateVariabilitySDNN,
            .restingHeartRate,
            .respiratoryRate
        ]
        
        for typeIdentifier in types {
            guard let quantityType = HKQuantityType.quantityType(forIdentifier: typeIdentifier) else { continue }
            
            let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { _, completionHandler, error in
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
            healthStore.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { _, _ in }
        }
    }
    
    // MARK: - NEW: Stress Monitoring Observer
    
    /// Start observing heart rate changes for real-time stress monitoring
    func startObservingHeartRate(handler: @escaping () -> Void) {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { _, completionHandler, error in
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
        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { _, _ in }
    }
}

// MARK: - Errors

enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case insufficientData
    case baselineNotEstablished
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied. Please enable in Settings."
        case .insufficientData:
            return "Not enough data available to calculate metrics"
        case .baselineNotEstablished:
            return "Baseline metrics need at least 7 days of data"
        }
    }
}


