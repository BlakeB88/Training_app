//
//  DataSyncService.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//  Updated: 10/9/25 - Fixed type mismatches
//

import Foundation
import HealthKit
import Combine

@MainActor
class DataSyncService: ObservableObject {
    
    static let shared = DataSyncService()
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let healthKitManager: HealthKitManager
    private let repository: MetricsRepository
    private let workoutQuery: WorkoutQuery
    private let hrvQuery: HRVQuery
    private let sleepQuery: SleepQuery
    
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastSyncDate"
    
    // MARK: - Initialization
    
    private init() {
        self.healthKitManager = HealthKitManager.shared
        self.repository = MetricsRepository()
        
        let healthStore = HKHealthStore()
        self.workoutQuery = WorkoutQuery(healthStore: healthStore)
        self.hrvQuery = HRVQuery(healthStore: healthStore)
        self.sleepQuery = SleepQuery(healthStore: healthStore)
        
        self.lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
    }
    
    // MARK: - Sync Methods
    
    /// Quick sync - only today's data
    func quickSync() async {
        guard !isSyncing else {
            print("⚠️ Already syncing, skipping quickSync")
            return
        }
        
        print("🔄 Starting quick sync for today...")
        isSyncing = true
        syncError = nil
        
        do {
            let today = Date().startOfDay
            print("📅 Syncing: \(today.formatted(.dateTime.month().day().year()))")
            try await syncDay(today)
            
            updateLastSyncDate()
            print("✅ Quick sync completed successfully")
        } catch {
            syncError = error
            print("❌ Quick sync error: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }
    
    /// Full sync - last 7 days
    func fullSync(days: Int = 7) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            let endDate = Date().startOfDay
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
            
            var currentDate = startDate
            while currentDate <= endDate {
                try await syncDay(currentDate)
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            updateLastSyncDate()
        } catch {
            syncError = error
            print("Full sync error: \(error)")
        }
        
        isSyncing = false
    }
    
    /// Sync specific date
    func syncDate(_ date: Date) async {
            guard !isSyncing else { return }
            
            isSyncing = true
            syncError = nil
            
            do {
                print("🔄 Syncing data for \(date.formatted())...")
                
                // REPLACE YOUR OLD FETCH WITH THIS NEW ONE:
                let metrics = try await fetchEnhancedDailyMetrics(for: date)
                
                // Save to repository
                try repository.saveDailyMetrics(metrics)
                
                lastSyncDate = Date()
                print("✅ Sync completed successfully")
                
            } catch {
                print("❌ Sync failed: \(error)")
                syncError = error
            }
            
            isSyncing = false
        }
        
        // MARK: - NEW: Enhanced Metrics Fetching
        
        /// Fetch all daily metrics including new health data
        private func fetchEnhancedDailyMetrics(for date: Date) async throws -> SimpleDailyMetrics {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            print("📊 Fetching enhanced metrics for \(date.formatted())...")
            
            // 1. Get existing metrics or create new
            var metrics = (try? repository.fetchDailyMetrics(for: date)) ?? SimpleDailyMetrics(date: date)
            
            // 2. Fetch workouts and calculate strain
            print("  🏋️ Fetching workouts...")
            let workouts = try await healthKitManager.fetchWorkouts(from: startOfDay, to: endOfDay)
            let workoutSummaries = try await processWorkouts(workouts)
            let strain = StrainCalculator.calculateDailyStrain(from: workoutSummaries)
            
            // 3. Fetch ENHANCED sleep data (from previous night)
            print("  😴 Fetching detailed sleep data...")
            let sleepStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay)!
            let sleepData = try await healthKitManager.fetchDetailedSleepData(from: sleepStart, to: endOfDay)
            
            // 4. Fetch physiological metrics
            print("  ❤️ Fetching physiological metrics...")
            async let hrvTask = healthKitManager.fetchLatestHRV()
            async let rhrTask = healthKitManager.fetchRestingHeartRate()
            async let respRateTask = healthKitManager.fetchRespiratoryRate()
            async let vo2MaxTask = healthKitManager.fetchLatestVO2Max()
            
            let (hrv, rhr, respiratoryRate, vo2Max) = try await (hrvTask, rhrTask, respRateTask, vo2MaxTask)
            
            // 5. Fetch NEW activity metrics
            print("  🚶 Fetching activity metrics...")
            async let stepsTask = healthKitManager.fetchStepCount(from: startOfDay, to: endOfDay)
            async let avgHRTask = calculateAverageHeartRate(for: date)
            
            let (steps, averageHR) = try await (stepsTask, avgHRTask)
            
            // 6. Calculate NEW sleep metrics
            print("  📊 Calculating sleep metrics...")
            let sleepDebt = try await calculateSleepDebt(for: date, currentSleep: sleepData.totalSleepDuration / 3600)
            let sleepConsistency = try await calculateSleepConsistency(for: date)
            
            // 7. Calculate recovery (if baseline exists)
            if let baseline = metrics.baselineMetrics {
                print("  🔋 Calculating recovery...")
                let recoveryResult = RecoveryCalculator.calculateRecovery(
                    hrv: hrv,
                    rhr: rhr,
                    sleepDuration: sleepData.totalSleepDuration / 3600,
                    baseline: baseline
                )
                metrics.recovery = recoveryResult.score
                metrics.recoveryComponents = recoveryResult.components
            }
            
            // 8. Update all metrics
            print("  💾 Updating metrics...")
            
            // Strain & Workouts
            metrics.strain = strain
            metrics.workouts = workoutSummaries
            
            // Sleep metrics (ALL NEW DATA)
            if sleepData.totalSleepDuration > 0 {
                metrics.sleepDuration = sleepData.totalSleepDuration / 3600
                metrics.sleepStart = sleepData.sleepStart
                metrics.sleepEnd = sleepData.sleepEnd
                metrics.timeInBed = sleepData.timeInBed / 3600
                metrics.sleepEfficiency = sleepData.sleepEfficiency
                metrics.restorativeSleepPercentage = sleepData.restorativeSleepPercentage
                metrics.restorativeSleepDuration = sleepData.restorativeSleepDuration / 3600
                metrics.sleepDebt = sleepDebt
                metrics.sleepConsistency = sleepConsistency
            }
            
            // Physiological metrics
            metrics.hrvAverage = hrv
            metrics.restingHeartRate = rhr
            metrics.respiratoryRate = respiratoryRate
            metrics.vo2Max = vo2Max
            
            // Activity metrics (ALL NEW DATA)
            metrics.steps = steps
            metrics.activeCalories = workoutSummaries.reduce(0.0) { $0 + $1.calories }
            metrics.averageHeartRate = averageHR
            
            metrics.lastUpdated = Date()
            
            print("✅ Enhanced metrics fetched successfully")
            return metrics
        }
        
        // MARK: - Helper Methods for New Metrics
        
        /// Calculate average heart rate for the entire day
        private func calculateAverageHeartRate(for date: Date) async throws -> Double? {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let heartRateData = try await healthKitManager.fetchContinuousHeartRate(from: startOfDay, to: endOfDay)
            
            guard !heartRateData.isEmpty else { return nil }
            
            let sum = heartRateData.reduce(0.0) { $0 + $1.heartRate }
            return sum / Double(heartRateData.count)
        }
        
        /// Calculate cumulative sleep debt over the last 7 days
        private func calculateSleepDebt(for date: Date, currentSleep: Double) async throws -> Double {
            let optimalSleep = 8.0 // 8 hours is the target
            
            // Get last 7 days of sleep data
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: date)!
            let weekMetrics = (try? repository.fetchDailyMetrics(from: weekAgo, to: date)) ?? []
            
            // Calculate cumulative debt
            var totalDebt = 0.0
            for dayMetrics in weekMetrics {
                if let sleep = dayMetrics.sleepDuration {
                    let dailyDebt = max(0, optimalSleep - sleep)
                    totalDebt += dailyDebt
                }
            }
            
            // Add today's debt
            let todayDebt = max(0, optimalSleep - currentSleep)
            totalDebt += todayDebt
            
            return totalDebt
        }
        
        /// Calculate sleep consistency score based on bedtime variance
        private func calculateSleepConsistency(for date: Date) async throws -> Double {
            let calendar = Calendar.current
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: date)!
            let weekMetrics = (try? repository.fetchDailyMetrics(from: weekAgo, to: date)) ?? []
            
            // Get all sleep start times from the week
            let sleepTimes = weekMetrics.compactMap { $0.sleepStart }
            
            guard sleepTimes.count >= 3 else {
                print("  ⚠️ Not enough sleep data for consistency calculation")
                return 0
            }
            
            // Calculate average bedtime (in hours from midnight)
            let avgTime = sleepTimes.reduce(0.0) { sum, time in
                let hour = Double(calendar.component(.hour, from: time))
                let minute = Double(calendar.component(.minute, from: time))
                return sum + (hour + minute / 60.0)
            } / Double(sleepTimes.count)
            
            // Calculate standard deviation
            let variance = sleepTimes.reduce(0.0) { sum, time in
                let hour = Double(calendar.component(.hour, from: time))
                let minute = Double(calendar.component(.minute, from: time))
                let timeValue = hour + minute / 60.0
                let diff = abs(timeValue - avgTime)
                return sum + (diff * diff)
            } / Double(sleepTimes.count)
            
            let standardDeviation = sqrt(variance)
            
            // Convert to consistency score (0-100)
            // Perfect consistency (0 std dev) = 100%
            // 2 hours std dev or more = 0%
            let maxStdDev = 2.0
            let consistency = max(0, min(100, (1 - standardDeviation / maxStdDev) * 100))
            
            print("  📊 Sleep consistency: \(Int(consistency))% (stddev: \(standardDeviation.formatted(.number.precision(.fractionLength(2)))) hrs)")
            
            return consistency
        }
    
    // MARK: - Private Sync Logic
    
    private func syncDay(_ date: Date) async throws {
        let dayStart = date.startOfDay
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        print("   📊 Fetching workouts for \(dayStart.formatted(.dateTime.month().day()))...")
        
        // Fetch workouts
        let hkWorkouts = try await workoutQuery.fetchWorkouts(from: dayStart, to: dayEnd)
        print("   Found \(hkWorkouts.count) workouts")
        
        guard !hkWorkouts.isEmpty else {
            print("   ⚠️ No workouts found, syncing recovery data only...")
            // No workouts, but still sync recovery data
            try await syncRecoveryOnly(for: date)
            return
        }
        
        // Get heart rate profile
        let restingHR = try await workoutQuery.fetchRestingHeartRate() ?? 60.0
        let maxHR = 220.0 - 30.0 // TODO: Get from user profile
        let hrProfile = HeartRateProfile(
            maxHeartRate: maxHR,
            restingHeartRate: restingHR,
            age: 30 // TODO: Get from user profile
        )
        
        // Calculate daily strain
        let totalStrain = await StrainCalculator.calculateDailyStrain(
            workouts: hkWorkouts,
            hrProfile: hrProfile
        )
        
        // Create workout summaries
        var workoutSummaries: [WorkoutSummary] = []
        for hkWorkout in hkWorkouts {
            let summary = try await createWorkoutSummary(hkWorkout, hrProfile: hrProfile)
            workoutSummaries.append(summary)
        }
        
        // Fetch sleep data
        let sleepDuration = try await sleepQuery.fetchSleepDuration(from: dayStart, to: dayEnd)
        
        // Fetch HRV
        let hrvReadings = try await hrvQuery.fetchHRVReadings(from: dayStart, to: dayEnd)
        let hrvAverage = hrvReadings.isEmpty ? nil : hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
        
        // Calculate recovery
        var recovery: Double?
        var recoveryComponents: RecoveryComponents?
        var baselineMetrics: BaselineMetrics?
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
        if !historicalMetrics.isEmpty {
            // Calculate baselines from SimpleDailyMetrics
            baselineMetrics = calculateBaselinesFromSimpleMetrics(historicalMetrics, forDate: date)
            
            if let baseline = baselineMetrics {
                recovery = RecoveryCalculator.calculateRecoveryScore(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration
                )
                
                recoveryComponents = RecoveryCalculator.recoveryComponents(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration,
                    respiratoryRate: nil
                )
            }
        }
        
        // Create and save daily metrics using SimpleDailyMetrics
        let dailyMetrics = SimpleDailyMetrics(
            date: dayStart,
            strain: totalStrain,
            recovery: recovery,
            recoveryComponents: recoveryComponents,
            workouts: workoutSummaries,
            sleepDuration: sleepDuration > 0 ? sleepDuration : nil,
            sleepStart: nil,
            sleepEnd: nil,
            hrvAverage: hrvAverage,
            restingHeartRate: restingHR,
            baselineMetrics: baselineMetrics
        )
        
        try repository.saveDailyMetrics(dailyMetrics)
    }
    
    private func syncRecoveryOnly(for date: Date) async throws {
        let dayStart = date.startOfDay
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        // Check if we already have metrics for this day
        if (try? repository.fetchDailyMetrics(for: date)) != nil {
            // Already have data, skip
            return
        }
        
        // Fetch recovery data
        let restingHR = try await workoutQuery.fetchRestingHeartRate() ?? 60.0
        let sleepDuration = try await sleepQuery.fetchSleepDuration(from: dayStart, to: dayEnd)
        let hrvReadings = try await hrvQuery.fetchHRVReadings(from: dayStart, to: dayEnd)
        let hrvAverage = hrvReadings.isEmpty ? nil : hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
        
        // Calculate recovery
        var recovery: Double?
        var recoveryComponents: RecoveryComponents?
        var baselineMetrics: BaselineMetrics?
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
        if !historicalMetrics.isEmpty {
            // Calculate baselines from SimpleDailyMetrics
            baselineMetrics = calculateBaselinesFromSimpleMetrics(historicalMetrics, forDate: date)
            
            if let baseline = baselineMetrics {
                recovery = RecoveryCalculator.calculateRecoveryScore(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration
                )
                
                recoveryComponents = RecoveryCalculator.recoveryComponents(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration,
                    respiratoryRate: nil
                )
            }
        }
        
        // Create metrics with zero strain using SimpleDailyMetrics
        let dailyMetrics = SimpleDailyMetrics(
            date: dayStart,
            strain: 0,
            recovery: recovery,
            recoveryComponents: recoveryComponents,
            workouts: [],
            sleepDuration: sleepDuration > 0 ? sleepDuration : nil,
            sleepStart: nil,
            sleepEnd: nil,
            hrvAverage: hrvAverage,
            restingHeartRate: restingHR
        )
        
        try repository.saveDailyMetrics(dailyMetrics)
    }
    
    private func createWorkoutSummary(_ workout: HKWorkout, hrProfile: HeartRateProfile) async throws -> WorkoutSummary {
        let workoutStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: hrProfile
        )
        
        let heartRateData = try await workoutQuery.fetchHeartRateData(for: workout)
        let avgHR = heartRateData.isEmpty ? nil : heartRateData.reduce(0.0, +) / Double(heartRateData.count)
        let maxHR = heartRateData.max()
        
        let intensity = avgHR.map { StrainCalculator.calculateHRIntensity(avgHR: $0, profile: hrProfile) }
        
        // Get calories using new API
        let calories: Double
        if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
           let energyStats = workout.statistics(for: energyType),
           let energySum = energyStats.sumQuantity() {
            calories = energySum.doubleValue(for: .kilocalorie())
        } else {
            calories = 0
        }
        
        return WorkoutSummary(
            id: UUID(),
            workoutType: workout.workoutActivityType,
            startDate: workout.startDate,
            endDate: workout.endDate,
            duration: workout.duration,
            distance: workout.totalDistance?.doubleValue(for: .meter()),
            calories: calories,
            averageHeartRate: avgHR,
            maxHeartRate: maxHR,
            swimmingStrokeStyle: nil,
            lapCount: nil,
            strain: workoutStrain,
            heartRateIntensity: intensity
        )
    }
    
    private func updateLastSyncDate() {
        lastSyncDate = Date()
        userDefaults.set(lastSyncDate, forKey: lastSyncKey)
    }
    
    // MARK: - Helper Methods
    
    /// Calculate baselines from SimpleDailyMetrics (instead of using BaselineCalculator which expects DailyMetrics)
    private func calculateBaselinesFromSimpleMetrics(_ metrics: [SimpleDailyMetrics], forDate date: Date) -> BaselineMetrics? {
        guard !metrics.isEmpty else { return nil }
        
        // Filter out metrics without required data
        let validMetrics = metrics.filter { $0.hrvAverage != nil && $0.restingHeartRate != nil }
        guard validMetrics.count >= AppConstants.Baseline.minimumDaysForBaseline else { return nil }
        
        // Calculate HRV baseline
        let hrvValues = validMetrics.compactMap { $0.hrvAverage }
        let hrvBaseline = hrvValues.isEmpty ? nil : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
        let hrvStdDev = hrvValues.isEmpty ? nil : standardDeviation(hrvValues)
        
        // Calculate RHR baseline
        let rhrValues = validMetrics.compactMap { $0.restingHeartRate }
        let rhrBaseline = rhrValues.isEmpty ? nil : rhrValues.reduce(0.0, +) / Double(rhrValues.count)
        let rhrStdDev = rhrValues.isEmpty ? nil : standardDeviation(rhrValues)
        
        // Calculate acute strain (last 7 days)
        let recentMetrics = metrics.suffix(7)
        let acuteStrain = recentMetrics.isEmpty ? nil : recentMetrics.reduce(0.0) { $0 + $1.strain } / Double(recentMetrics.count)
        
        // Calculate chronic strain (all available, up to 28 days)
        let chronicStrain = metrics.isEmpty ? nil : metrics.reduce(0.0) { $0 + $1.strain } / Double(metrics.count)
        
        return BaselineMetrics(
            hrvBaseline: hrvBaseline,
            hrvStandardDeviation: hrvStdDev,
            rhrBaseline: rhrBaseline,
            rhrStandardDeviation: rhrStdDev,
            acuteStrain: acuteStrain,
            chronicStrain: chronicStrain,
            respiratoryRateBaseline: nil,
            calculatedDate: date,
            daysOfData: validMetrics.count
        )
    }
    
    /// Calculate standard deviation
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0.0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    
}
