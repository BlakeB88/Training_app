//
//  DataSyncService.swift - ENHANCED VERSION
//  StrainFitnessTracker
//
//  Updated with force refresh capability and better stress data handling
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
    @Published var lastStressDataFetch: Date? // NEW: Track when stress was last fetched
    
    private let healthKitManager: HealthKitManager
    private let repository: MetricsRepository
    private let workoutQuery: WorkoutQuery
    private let hrvQuery: HRVQuery
    private let sleepQuery: SleepQuery
    private let stressQuery: StressQuery
    
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastSyncDate"
    private let lastStressFetchKey = "lastStressDataFetch" // NEW
    
    // MARK: - Initialization
    
    private init() {
        self.healthKitManager = HealthKitManager.shared
        self.repository = MetricsRepository()
        
        let healthStore = HKHealthStore()
        self.workoutQuery = WorkoutQuery(healthStore: healthStore)
        self.hrvQuery = HRVQuery(healthStore: healthStore)
        self.sleepQuery = SleepQuery(healthStore: healthStore)
        self.stressQuery = StressQuery(healthStore: healthStore)
        
        self.lastSyncDate = userDefaults.object(forKey: lastSyncKey) as? Date
        self.lastStressDataFetch = userDefaults.object(forKey: lastStressFetchKey) as? Date
    }
    
    // MARK: - Sync Methods

    /// Quick sync - only today's data (with force refresh option)
    func quickSync(forceRefresh: Bool = false) async {
        guard !isSyncing else {
            print("⚠️ Already syncing, skipping quickSync")
            return
        }
        
        print("🔄 Starting quick sync for today... (force: \(forceRefresh))")
        isSyncing = true
        syncError = nil
        
        do {
            let today = Date().startOfDay
            print("📅 Syncing: \(today.formatted(.dateTime.month().day().year()))")
            
            // Use the enhanced fetch method with force refresh
            let metrics = try await fetchEnhancedDailyMetrics(for: today, forceRefresh: forceRefresh)
            try repository.saveDailyMetrics(metrics)
            
            updateLastSyncDate()
            print("✅ Quick sync completed successfully")
        } catch {
            syncError = error
            print("❌ Quick sync error: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }

    /// Full sync - last N days (with force refresh option)
    func fullSync(days: Int = 7, forceRefresh: Bool = false) async {
        guard !isSyncing else {
            print("⚠️ Already syncing, skipping fullSync")
            return
        }
        
        print("🔄 Starting full sync for last \(days) days... (force: \(forceRefresh))")
        isSyncing = true
        syncError = nil
        
        do {
            let endDate = Date().startOfDay
            let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
            
            var currentDate = startDate
            while currentDate <= endDate {
                print("📅 Syncing: \(currentDate.formatted(.dateTime.month().day()))")
                
                // Use the enhanced fetch method with force refresh
                let metrics = try await fetchEnhancedDailyMetrics(for: currentDate, forceRefresh: forceRefresh)
                try repository.saveDailyMetrics(metrics)
                
                currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            updateLastSyncDate()
            print("✅ Full sync completed successfully")
        } catch {
            syncError = error
            print("❌ Full sync error: \(error.localizedDescription)")
        }
        
        isSyncing = false
    }

    /// Sync specific date (with force refresh option)
    func syncDate(_ date: Date, forceRefresh: Bool = false) async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            print("🔄 Syncing data for \(date.formatted())... (force: \(forceRefresh))")
            
            // Use the enhanced fetch method with force refresh
            let metrics = try await fetchEnhancedDailyMetrics(for: date, forceRefresh: forceRefresh)
            
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
    
    /// NEW: Force refresh stress data only (lightweight refresh)
    func refreshStressData() async {
        print("🔄 Force refreshing stress data...")
        
        do {
            let today = Date().startOfDay
            let now = Date()
            
            // Fetch fresh stress data
            let stressData = try await calculateDailyStress(
                for: today,
                startOfDay: today,
                endOfDay: now,
                forceRefresh: true
            )
            
            // Update only stress metrics in repository
            if var metrics = try? repository.fetchDailyMetrics(for: today) {
                metrics.averageStress = stressData.average
                metrics.maxStress = stressData.max
                metrics.stressReadings = stressData.readings
                metrics.timeInHighStress = stressData.timeInHigh
                metrics.timeInMediumStress = stressData.timeInMedium
                metrics.timeInLowStress = stressData.timeInLow
                metrics.lastUpdated = Date()
                
                try repository.saveDailyMetrics(metrics)
                
                lastStressDataFetch = Date()
                userDefaults.set(lastStressDataFetch, forKey: lastStressFetchKey)
                
                print("✅ Stress data refreshed: \(stressData.readings.count) readings")
            }
            
        } catch {
            print("❌ Failed to refresh stress data: \(error)")
        }
    }
        
    // MARK: - Enhanced Metrics Fetching with Stress

    /// Fetch all daily metrics including stress data
    private func fetchEnhancedDailyMetrics(for date: Date, forceRefresh: Bool = false) async throws -> SimpleDailyMetrics {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        print("📊 Fetching enhanced metrics for \(date.formatted())... (force: \(forceRefresh))")
        
        // 1. Get existing metrics or create new
        var metrics = (try? repository.fetchDailyMetrics(for: date)) ?? SimpleDailyMetrics(date: date)
        
        // NEW: Check if we should skip fetching (unless force refresh)
        if !forceRefresh {
            let timeSinceUpdate = Date().timeIntervalSince(metrics.lastUpdated)
            if timeSinceUpdate < 60 {
                print("  ⭐️ Skipping - data recently updated (\(Int(timeSinceUpdate))s ago)")
                return metrics
            }
        }
        
        // 2. Fetch workouts and calculate strain
        print("  🏋️ Fetching workouts...")
        let hkWorkouts = try await healthKitManager.fetchWorkouts(from: startOfDay, to: endOfDay)
        
        // Get heart rate profile for strain calculation
        let restingHR = try await healthKitManager.fetchRestingHeartRate() ?? 60.0
        let maxHR = 220.0 - 30.0 // TODO: Get from user profile
        let hrProfile = HeartRateProfile(
            maxHeartRate: maxHR,
            restingHeartRate: restingHR,
            age: 30 // TODO: Get from user profile
        )
        
        // Calculate daily strain
        let strain = await StrainCalculator.calculateDailyStrain(
            workouts: hkWorkouts,
            hrProfile: hrProfile
        )
        
        // Create workout summaries
        var workoutSummaries: [WorkoutSummary] = []
        for hkWorkout in hkWorkouts {
            let summary = try await createWorkoutSummary(hkWorkout, hrProfile: hrProfile)
            workoutSummaries.append(summary)
        }
        
        // 3. Fetch ENHANCED sleep data
        print("  😴 Fetching detailed sleep data...")
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: startOfDay)!
        let sleepData = try await healthKitManager.fetchDetailedSleepData(from: sleepStart, to: endOfDay)
        
        // 4. Fetch physiological metrics
        print("  ❤️ Fetching physiological metrics...")
        async let hrvTask = calculateAverageHRV(for: date)
        async let rhrTask = healthKitManager.fetchRestingHeartRate()
        async let respRateTask = healthKitManager.fetchRespiratoryRate()
        async let vo2MaxTask = healthKitManager.fetchLatestVO2Max()
        
        let (hrv, rhr, respiratoryRate, vo2Max) = try await (hrvTask, rhrTask, respRateTask, vo2MaxTask)
        
        // 5. Fetch activity metrics
        print("  🚶 Fetching activity metrics...")
        async let stepsTask = healthKitManager.fetchStepCount(from: startOfDay, to: endOfDay)
        async let avgHRTask = calculateAverageHeartRate(for: date)
        
        let (steps, averageHR) = try await (stepsTask, avgHRTask)
        
        // 6. ✨ Calculate stress metrics (with force refresh option)
        print("  😰 Calculating stress metrics... (force: \(forceRefresh))")
        let stressData = try await calculateDailyStress(
            for: date,
            startOfDay: startOfDay,
            endOfDay: endOfDay,
            forceRefresh: forceRefresh
        )
        
        // 7. Calculate sleep metrics
        print("  📊 Calculating sleep metrics...")
        let sleepDebt = try await calculateSleepDebt(for: date, currentSleep: sleepData.totalSleepDuration / 3600)
        let sleepConsistency = try await calculateSleepConsistency(for: date)
        
        // 8. Calculate recovery
        var recovery: Double?
        var recoveryComponents: RecoveryComponents?
        var baselineMetrics: BaselineMetrics?
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
        if !historicalMetrics.isEmpty {
            baselineMetrics = calculateBaselinesFromSimpleMetrics(historicalMetrics, forDate: date)
            
            if let baseline = baselineMetrics {
                print("  🔋 Calculating recovery...")
                recovery = RecoveryCalculator.calculateRecoveryScore(
                    hrvCurrent: hrv,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: rhr,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepData.totalSleepDuration / 3600,
                    respiratoryRate: respiratoryRate
                )
                
                recoveryComponents = RecoveryCalculator.recoveryComponents(
                    hrvCurrent: hrv,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: rhr,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepData.totalSleepDuration / 3600,
                    respiratoryRate: respiratoryRate
                )
            }
        }
        
        // 9. Update all metrics
        print("  💾 Updating metrics...")
        
        // Strain & Workouts
        metrics.strain = strain
        metrics.workouts = workoutSummaries
        
        // Sleep metrics
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
        
        // Recovery
        metrics.recovery = recovery
        metrics.recoveryComponents = recoveryComponents
        metrics.baselineMetrics = baselineMetrics
        
        // Activity metrics
        metrics.steps = steps
        metrics.activeCalories = workoutSummaries.reduce(0.0) { $0 + $1.calories }
        metrics.averageHeartRate = averageHR
        
        // ✨ Stress metrics
        metrics.averageStress = stressData.average
        metrics.maxStress = stressData.max
        metrics.stressReadings = stressData.readings
        metrics.timeInHighStress = stressData.timeInHigh
        metrics.timeInMediumStress = stressData.timeInMedium
        metrics.timeInLowStress = stressData.timeInLow
        
        metrics.lastUpdated = Date()
        
        print("✅ Enhanced metrics fetched successfully")
        print("   Stress: Avg=\(String(format: "%.1f", stressData.average)), Max=\(String(format: "%.1f", stressData.max)), Readings=\(stressData.readings.count)")
        
        return metrics
    }
    
    private func calculateAverageHRV(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // First, try to get morning HRV (most reliable reading)
        if let morningHRV = try? await hrvQuery.fetchMorningHRV(for: date) {
            print("  ✅ Morning HRV for \(date.formatted(.dateTime.month().day())): \(String(format: "%.1f", morningHRV)) ms")
            return morningHRV
        }
        
        // If no morning reading, fetch all HRV readings for this day
        let hrvReadings = try await hrvQuery.fetchHRVReadings(from: startOfDay, to: endOfDay)
        
        guard !hrvReadings.isEmpty else {
            print("  ⚠️ No HRV readings found for \(date.formatted(.dateTime.month().day()))")
            return nil
        }
        
        let average = hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
        print("  ✅ HRV average for \(date.formatted(.dateTime.month().day())): \(String(format: "%.1f", average)) ms (from \(hrvReadings.count) readings)")
        
        return average
    }

    // MARK: - ENHANCED: Stress Calculation Methods

    /// Calculate all stress metrics for a day (with force refresh to bypass cache)
    private func calculateDailyStress(
        for date: Date,
        startOfDay: Date,
        endOfDay: Date,
        forceRefresh: Bool = false
    ) async throws -> (average: Double, max: Double, readings: [StressReading], timeInHigh: Double, timeInMedium: Double, timeInLow: Double) {
        
        do {
            print("  📊 Fetching stress context data from HealthKit...")
            
            // NEW: Log what we're fetching
            // Use current time if we're looking at today, otherwise use endOfDay
            let now = Date()
            let queryEndTime = Calendar.current.isDateInToday(date) ? now : endOfDay
            print("    Time range: \(startOfDay.formatted(date: .omitted, time: .shortened)) to \(queryEndTime.formatted(date: .omitted, time: .shortened))")
            
            // Fetch all context data needed for stress calculation
            let contextData = try await stressQuery.fetchStressContextData(from: startOfDay, to: queryEndTime)
            
            // NEW: Log what we got back
            print("    HRV samples: \(contextData.hrvReadings.count)")
            print("    Baseline RHR: \(contextData.baselineRestingHeartRate ?? 0)")
            print("    Baseline HRV: \(contextData.baselineHRV ?? 0)")
            
            // Check if we have baseline data
            guard contextData.baselineRestingHeartRate != nil else {
                print("  ⚠️ No baseline heart rate available for stress calculation")
                return (0, 0, [], 0, 0, 0)
            }
            
            // Calculate stress metrics for all readings
            let stressMetrics = StressCalculator.calculateDailyStress(
                from: contextData,
                date: date
            )
            
            print("    Raw stress metrics calculated: \(stressMetrics.count)")
            
            // Filter out exercise-related readings
            let nonExerciseMetrics = stressMetrics.filter { !$0.isExerciseRelated }
            
            print("    Non-exercise metrics: \(nonExerciseMetrics.count)")
            
            guard !nonExerciseMetrics.isEmpty else {
                print("  ℹ️ No valid stress readings for this day")
                return (0, 0, [], 0, 0, 0)
            }
            
            // Calculate summary statistics
            let avgStress = nonExerciseMetrics.reduce(0.0) { $0 + $1.stressLevel } / Double(nonExerciseMetrics.count)
            let maxStress = nonExerciseMetrics.map { $0.stressLevel }.max() ?? 0
            
            // Calculate time in each stress zone (assuming 5-minute intervals)
            let highStressReadings = nonExerciseMetrics.filter { $0.stressLevel >= 2.0 }
            let mediumStressReadings = nonExerciseMetrics.filter { $0.stressLevel >= 1.0 && $0.stressLevel < 2.0 }
            let lowStressReadings = nonExerciseMetrics.filter { $0.stressLevel < 1.0 }
            
            let timeInHigh = Double(highStressReadings.count * 5) / 60.0 // Convert to hours
            let timeInMedium = Double(mediumStressReadings.count * 5) / 60.0
            let timeInLow = Double(lowStressReadings.count * 5) / 60.0
            
            // Convert to lightweight StressReading objects
            let readings = nonExerciseMetrics.map { StressReading(from: $0) }
            
            // NEW: Show time range of readings
            if let firstReading = readings.first, let lastReading = readings.last {
                print("    Reading time range: \(firstReading.timestamp.formatted(date: .omitted, time: .shortened)) to \(lastReading.timestamp.formatted(date: .omitted, time: .shortened))")
            }
            
            print("  ✅ Stress calculated: \(nonExerciseMetrics.count) readings, avg=\(String(format: "%.1f", avgStress)), max=\(String(format: "%.1f", maxStress))")
            print("    Distribution - Low: \(String(format: "%.1f", timeInLow))h, Med: \(String(format: "%.1f", timeInMedium))h, High: \(String(format: "%.1f", timeInHigh))h")
            
            // Update last fetch time
            lastStressDataFetch = Date()
            userDefaults.set(lastStressDataFetch, forKey: lastStressFetchKey)
            
            return (avgStress, maxStress, readings, timeInHigh, timeInMedium, timeInLow)
            
        } catch {
            print("  ⚠️ Error calculating stress: \(error.localizedDescription)")
            // Return zero values on error but don't fail the entire sync
            return (0, 0, [], 0, 0, 0)
        }
    }

    // MARK: - Helper Methods for Other Metrics

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
        let maxStdDev = 2.0
        let consistency = max(0, min(100, (1 - standardDeviation / maxStdDev) * 100))
        
        print("  📊 Sleep consistency: \(Int(consistency))% (stddev: \(standardDeviation.formatted(.number.precision(.fractionLength(2)))) hrs)")
        
        return consistency
    }
    
    // MARK: - Workout Summary Creation
    
    private func createWorkoutSummary(_ workout: HKWorkout, hrProfile: HeartRateProfile) async throws -> WorkoutSummary {
        let workoutStrain = await StrainCalculator.calculateWorkoutStrain(
            workout: workout,
            hrProfile: hrProfile
        )
        
        let heartRateData = try await workoutQuery.fetchHeartRateData(for: workout)
        let avgHR = heartRateData.isEmpty ? nil : heartRateData.reduce(0.0, +) / Double(heartRateData.count)
        let maxHR = heartRateData.max()
        
        let intensity = avgHR.map { StrainCalculator.calculateHRIntensity(avgHR: $0, profile: hrProfile) }
        
        // Get calories
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
    
    // MARK: - Baseline Calculation
    
    private func calculateBaselinesFromSimpleMetrics(_ metrics: [SimpleDailyMetrics], forDate date: Date) -> BaselineMetrics? {
        guard !metrics.isEmpty else { return nil }
        
        let validMetrics = metrics.filter { $0.hrvAverage != nil && $0.restingHeartRate != nil }
        guard validMetrics.count >= AppConstants.Baseline.minimumDaysForBaseline else { return nil }
        
        let hrvValues = validMetrics.compactMap { $0.hrvAverage }
        let hrvBaseline = hrvValues.isEmpty ? nil : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
        let hrvStdDev = hrvValues.isEmpty ? nil : standardDeviation(hrvValues)
        
        let rhrValues = validMetrics.compactMap { $0.restingHeartRate }
        let rhrBaseline = rhrValues.isEmpty ? nil : rhrValues.reduce(0.0, +) / Double(rhrValues.count)
        let rhrStdDev = rhrValues.isEmpty ? nil : standardDeviation(rhrValues)
        
        let recentMetrics = metrics.suffix(7)
        let acuteStrain = recentMetrics.isEmpty ? nil : recentMetrics.reduce(0.0) { $0 + $1.strain } / Double(recentMetrics.count)
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
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0.0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
}
