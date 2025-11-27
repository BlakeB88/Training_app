//
//  DataSyncService.swift - COMPLETE ENHANCED VERSION
//  StrainFitnessTracker
//
//  Updated with force refresh capability, better stress data handling,
//  and ALWAYS calculating recovery with enhanced parameters
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
    @Published var lastStressDataFetch: Date?
    
    private let healthKitManager: HealthKitManager
    private let repository: MetricsRepository
    private let workoutQuery: WorkoutQuery
    private let hrvQuery: HRVQuery
    private let sleepQuery: SleepQuery
    private let stressQuery: StressQuery
    
    private let userDefaults = UserDefaults.standard
    private let lastSyncKey = "lastSyncDate"
    private let lastStressFetchKey = "lastStressDataFetch"
    
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
            
            let metrics = try await fetchEnhancedDailyMetrics(for: date, forceRefresh: forceRefresh)
            try repository.saveDailyMetrics(metrics)
            
            lastSyncDate = Date()
            print("✅ Sync completed successfully")
            
        } catch {
            print("❌ Sync failed: \(error)")
            syncError = error
        }
        
        isSyncing = false
    }
    
    /// Force refresh stress data only (lightweight refresh)
    func refreshStressData() async {
        print("🔄 Force refreshing stress data...")
        
        do {
            let today = Date().startOfDay
            let now = Date()
            
            let stressData = try await calculateDailyStress(
                for: today,
                startOfDay: today,
                endOfDay: now,
                forceRefresh: true
            )
            
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
        let previousMetrics = try? repository.fetchDailyMetrics(for: date)
        var metrics = previousMetrics ?? SimpleDailyMetrics(date: date)
        
        // Check if we should skip fetching (unless force refresh)
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
        
        // ✅ NEW: Get multi-night sleep durations for enhanced calculation
        let recentSleepDurations = try await fetchMultiNightSleepData(for: date, numberOfNights: 3)
        
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
        
        // 6. Calculate stress metrics
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
        
        // 8. ✅ FIXED: ALWAYS Calculate recovery (with or without baselines)
        var recovery: Double?
        var recoveryComponents: RecoveryComponents?
        var baselineMetrics: BaselineMetrics?
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
        
        if !historicalMetrics.isEmpty {
            baselineMetrics = calculateBaselinesFromSimpleMetrics(historicalMetrics, forDate: date)
        }
        
        // ✅ FIX: Calculate recovery ALWAYS, with or without baselines
        let recoveryResult = calculateRecovery(
            for: date,
            hrv: hrv,
            rhr: rhr,
            sleepDuration: sleepData.totalSleepDuration / 3600,
            recentSleepDurations: recentSleepDurations,
            sleepEfficiency: sleepData.sleepEfficiency,
            sleepConsistency: sleepConsistency,
            respiratoryRate: respiratoryRate,
            baselineMetrics: baselineMetrics
        )
        
        recovery = recoveryResult.recovery
        recoveryComponents = recoveryResult.components
        
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
            // ✅ FIX: Store multi-night sleep data
            metrics.recentSleepDurations = recentSleepDurations
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
        
        // ✅ Stress metrics
        metrics.averageStress = stressData.average
        metrics.maxStress = stressData.max
        metrics.stressReadings = stressData.readings
        metrics.timeInHighStress = stressData.timeInHigh
        metrics.timeInMediumStress = stressData.timeInMedium
        metrics.timeInLowStress = stressData.timeInLow
        
        metrics.lastUpdated = Date()

        print("✅ Enhanced metrics fetched successfully")
        print("   Recovery: \(String(format: "%.1f", recovery ?? 0))")
        print("   Stress: Avg=\(String(format: "%.1f", stressData.average)), Max=\(String(format: "%.1f", stressData.max))")

        sendActivityNotificationsIfNeeded(
            previousMetrics: previousMetrics,
            updatedMetrics: metrics
        )

        return metrics
    }

    // MARK: - Activity Notifications

    private func sendActivityNotificationsIfNeeded(
        previousMetrics: SimpleDailyMetrics?,
        updatedMetrics: SimpleDailyMetrics
    ) {
        let notificationService = NotificationService.shared

        // Sleep score notification when new sleep is detected
        if let sleepEnd = updatedMetrics.sleepEnd,
           let sleepDuration = updatedMetrics.sleepDuration,
           sleepDuration > 0 {

            let previousSleepEnd = previousMetrics?.sleepEnd
            let isNewSleepSession: Bool

            if let previousSleepEnd {
                isNewSleepSession = abs(sleepEnd.timeIntervalSince(previousSleepEnd)) > 60
            } else {
                isNewSleepSession = true
            }

            if isNewSleepSession {
                let sleepScore = calculateSleepScore(for: updatedMetrics)
                notificationService.notifySleepScore(
                    score: sleepScore,
                    durationHours: sleepDuration
                )
            }
        }

        // Workout notification for newly synced activities
        let previousWorkoutStartDates = Set(previousMetrics?.workouts.map { $0.startDate } ?? [])
        let newWorkouts = updatedMetrics.workouts.filter { workout in
            !previousWorkoutStartDates.contains(workout.startDate)
        }

        if let latestWorkout = newWorkouts.sorted(by: { $0.startDate < $1.startDate }).last {
            notificationService.notifyWorkoutCompletion(
                workout: latestWorkout,
                totalStrain: updatedMetrics.strain
            )
        }
    }

    /// Mirror the UI sleep score calculation so notifications match the dashboard
    private func calculateSleepScore(for metrics: SimpleDailyMetrics) -> Double {
        guard let duration = metrics.sleepDuration else { return 0 }

        var score = 0.0
        let weights: [String: Double] = [
            "duration": 0.4,
            "efficiency": 0.3,
            "restorative": 0.2,
            "consistency": 0.1
        ]

        // Duration score (optimal: 7-9 hours)
        let durationScore: Double
        if duration >= 7 && duration <= 9 {
            durationScore = 100
        } else if duration < 7 {
            durationScore = max(0, (duration / 7.0) * 100)
        } else {
            durationScore = max(60, 100 - ((duration - 9) * 10))
        }
        score += durationScore * weights["duration"]!

        // Efficiency score
        let efficiencyScore = metrics.sleepEfficiency ?? 70
        score += efficiencyScore * weights["efficiency"]!

        // Restorative sleep score
        let restorativeScore = min(100, (metrics.restorativeSleepPercentage ?? 25) * 2.5)
        score += restorativeScore * weights["restorative"]!

        // Consistency score
        let consistencyScore = metrics.sleepConsistency ?? 50
        score += consistencyScore * weights["consistency"]!

        return min(100, max(0, score))
    }
    
    // MARK: - ✅ NEW: Recovery Calculation with Fallback
    
    /// Calculate recovery with fallback for new users
    private func calculateRecovery(
        for date: Date,
        hrv: Double?,
        rhr: Double?,
        sleepDuration: Double,
        recentSleepDurations: [Double],
        sleepEfficiency: Double?,
        sleepConsistency: Double?,
        respiratoryRate: Double?,
        baselineMetrics: BaselineMetrics?
    ) -> (recovery: Double, components: RecoveryComponents) {
        
        print("  🔋 Calculating recovery...")
        
        // Get baselines or use defaults
        let hrvBaseline = baselineMetrics?.hrvBaseline ?? (hrv.map { $0 * 0.95 })
        let hrvStdDev = baselineMetrics?.hrvStandardDeviation ?? (hrvBaseline.map { $0 * 0.15 })
        
        let rhrBaseline = baselineMetrics?.rhrBaseline ?? (rhr.map { $0 * 1.05 })
        let rhrStdDev = baselineMetrics?.rhrStandardDeviation ?? (rhrBaseline.map { $0 * 0.08 })
        
        let acuteStrain = baselineMetrics?.acuteStrain
        let chronicStrain = baselineMetrics?.chronicStrain
        
        // ✅ FIX: Get yesterday's strain if available
        let recentStrain: Double? = {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date)
            if let yesterday = yesterday {
                return (try? repository.fetchDailyMetrics(for: yesterday))?.strain
            }
            return nil
        }()
        
        // Calculate recovery with ALL enhanced parameters
        let recovery = RecoveryCalculator.calculateRecoveryScore(
            hrvCurrent: hrv,
            hrvBaseline: hrvBaseline,
            hrvStdDev: hrvStdDev,
            rhrCurrent: rhr,
            rhrBaseline: rhrBaseline,
            rhrStdDev: rhrStdDev,
            sleepDuration: sleepDuration,
            recentSleepDurations: recentSleepDurations,
            sleepEfficiency: sleepEfficiency,
            sleepConsistency: sleepConsistency,
            recentStrain: recentStrain,
            acuteStrain: acuteStrain,
            chronicStrain: chronicStrain,
            respiratoryRate: respiratoryRate,
            respiratoryBaseline: baselineMetrics?.respiratoryRateBaseline
        )
        
        // Get components for detailed breakdown
        let components = RecoveryCalculator.recoveryComponents(
            hrvCurrent: hrv,
            hrvBaseline: hrvBaseline,
            rhrCurrent: rhr,
            rhrBaseline: rhrBaseline,
            sleepDuration: sleepDuration,
            respiratoryRate: respiratoryRate
        )
        
        print("  ✅ Recovery calculated: \(String(format: "%.1f", recovery))")
        if let hrvScore = components.hrvScore, let rhrScore = components.restingHRScore, let sleepScore = components.sleepScore {
            print("    HRV: \(String(format: "%.0f", hrvScore)) | RHR: \(String(format: "%.0f", rhrScore)) | Sleep: \(String(format: "%.0f", sleepScore))")
        }
        
        return (recovery, components)
    }
    
    // MARK: - ✅ NEW: Multi-Night Sleep Fetching

    /// Fetch sleep duration for the last N nights
    private func fetchMultiNightSleepData(for date: Date, numberOfNights: Int) async throws -> [Double] {
        let calendar = Calendar.current
        var sleepDurations: [Double] = []
        
        for i in 0..<numberOfNights {
            let targetDate = calendar.date(byAdding: .day, value: -i, to: date)!
            
            if let metrics = try? repository.fetchDailyMetrics(for: targetDate),
               let duration = metrics.sleepDuration {
                sleepDurations.append(duration)
            }
        }
        
        print("  📊 Retrieved \(sleepDurations.count) nights of sleep data")
        return sleepDurations
    }
    
    // MARK: - Stress Calculation Methods

    /// Calculate all stress metrics for a day
    private func calculateDailyStress(
        for date: Date,
        startOfDay: Date,
        endOfDay: Date,
        forceRefresh: Bool = false
    ) async throws -> (average: Double, max: Double, readings: [StressReading], timeInHigh: Double, timeInMedium: Double, timeInLow: Double) {
        
        do {
            print("  📊 Fetching stress context data from HealthKit...")
            
            let now = Date()
            let queryEndTime = Calendar.current.isDateInToday(date) ? now : endOfDay
            print("    Time range: \(startOfDay.formatted(date: .omitted, time: .shortened)) to \(queryEndTime.formatted(date: .omitted, time: .shortened))")
            
            let contextData = try await stressQuery.fetchStressContextData(from: startOfDay, to: queryEndTime)
            
            print("    HRV samples: \(contextData.hrvReadings.count)")
            print("    Baseline RHR: \(contextData.baselineRestingHeartRate ?? 0)")
            print("    Baseline HRV: \(contextData.baselineHRV ?? 0)")
            
            guard contextData.baselineRestingHeartRate != nil else {
                print("  ⚠️ No baseline heart rate available for stress calculation")
                return (0, 0, [], 0, 0, 0)
            }
            
            let stressMetrics = StressCalculator.calculateDailyStress(
                from: contextData,
                date: date
            )
            
            print("    Raw stress metrics calculated: \(stressMetrics.count)")
            
            let nonExerciseMetrics = stressMetrics.filter { !$0.isExerciseRelated }
            
            print("    Non-exercise metrics: \(nonExerciseMetrics.count)")
            
            guard !nonExerciseMetrics.isEmpty else {
                print("  ℹ️ No valid stress readings for this day")
                return (0, 0, [], 0, 0, 0)
            }
            
            let avgStress = nonExerciseMetrics.reduce(0.0) { $0 + $1.stressLevel } / Double(nonExerciseMetrics.count)
            let maxStress = nonExerciseMetrics.map { $0.stressLevel }.max() ?? 0
            
            let highStressReadings = nonExerciseMetrics.filter { $0.stressLevel >= 2.0 }
            let mediumStressReadings = nonExerciseMetrics.filter { $0.stressLevel >= 1.0 && $0.stressLevel < 2.0 }
            let lowStressReadings = nonExerciseMetrics.filter { $0.stressLevel < 1.0 }
            
            let timeInHigh = Double(highStressReadings.count * 5) / 60.0
            let timeInMedium = Double(mediumStressReadings.count * 5) / 60.0
            let timeInLow = Double(lowStressReadings.count * 5) / 60.0
            
            let readings = nonExerciseMetrics.map { StressReading(from: $0) }
            
            if let firstReading = readings.first, let lastReading = readings.last {
                print("    Reading time range: \(firstReading.timestamp.formatted(date: .omitted, time: .shortened)) to \(lastReading.timestamp.formatted(date: .omitted, time: .shortened))")
            }
            
            print("  ✅ Stress calculated: avg=\(String(format: "%.1f", avgStress)), max=\(String(format: "%.1f", maxStress))")
            print("    Distribution - Low: \(String(format: "%.1f", timeInLow))h, Med: \(String(format: "%.1f", timeInMedium))h, High: \(String(format: "%.1f", timeInHigh))h")
            
            lastStressDataFetch = Date()
            userDefaults.set(lastStressDataFetch, forKey: lastStressFetchKey)
            
            return (avgStress, maxStress, readings, timeInHigh, timeInMedium, timeInLow)
            
        } catch {
            print("  ⚠️ Error calculating stress: \(error.localizedDescription)")
            return (0, 0, [], 0, 0, 0)
        }
    }

    // MARK: - Helper Methods for Other Metrics

    /// Calculate average HRV for a day
    private func calculateAverageHRV(for date: Date) async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        if let morningHRV = try? await hrvQuery.fetchMorningHRV(for: date) {
            print("  ✅ Morning HRV for \(date.formatted(.dateTime.month().day())): \(String(format: "%.1f", morningHRV)) ms")
            return morningHRV
        }
        
        let hrvReadings = try await hrvQuery.fetchHRVReadings(from: startOfDay, to: endOfDay)
        
        guard !hrvReadings.isEmpty else {
            print("  ⚠️ No HRV readings found for \(date.formatted(.dateTime.month().day()))")
            return nil
        }
        
        let average = hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
        print("  ✅ HRV average for \(date.formatted(.dateTime.month().day())): \(String(format: "%.1f", average)) ms")
        
        return average
    }

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
        let optimalSleep = 8.0
        
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        let weekMetrics = (try? repository.fetchDailyMetrics(from: weekAgo, to: date)) ?? []
        
        var totalDebt = 0.0
        for dayMetrics in weekMetrics {
            if let sleep = dayMetrics.sleepDuration {
                let dailyDebt = max(0, optimalSleep - sleep)
                totalDebt += dailyDebt
            }
        }
        
        let todayDebt = max(0, optimalSleep - currentSleep)
        totalDebt += todayDebt
        
        return totalDebt
    }

    /// Calculate sleep consistency score based on bedtime variance
    private func calculateSleepConsistency(for date: Date) async throws -> Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        let weekMetrics = (try? repository.fetchDailyMetrics(from: weekAgo, to: date)) ?? []
        
        let sleepTimes = weekMetrics.compactMap { $0.sleepStart }
        
        guard sleepTimes.count >= 3 else {
            print("  ⚠️ Not enough sleep data for consistency calculation")
            return 0
        }
        
        let avgTime = sleepTimes.reduce(0.0) { sum, time in
            let hour = Double(calendar.component(.hour, from: time))
            let minute = Double(calendar.component(.minute, from: time))
            return sum + (hour + minute / 60.0)
        } / Double(sleepTimes.count)
        
        let variance = sleepTimes.reduce(0.0) { sum, time in
            let hour = Double(calendar.component(.hour, from: time))
            let minute = Double(calendar.component(.minute, from: time))
            let timeValue = hour + minute / 60.0
            let diff = abs(timeValue - avgTime)
            return sum + (diff * diff)
        } / Double(sleepTimes.count)
        
        let standardDeviation = sqrt(variance)
        
        let maxStdDev = 2.0
        let consistency = max(0, min(100, (1 - standardDeviation / maxStdDev) * 100))
        
        print("  📊 Sleep consistency: \(Int(consistency))%")
        
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
    
    // MARK: - Updated Baseline Calculation with Outlier Filtering

    private func calculateBaselinesFromSimpleMetrics(_ metrics: [SimpleDailyMetrics], forDate date: Date) -> BaselineMetrics? {
        guard !metrics.isEmpty else { return nil }
        
        let validMetrics = metrics.filter { $0.hrvAverage != nil && $0.restingHeartRate != nil }
        guard validMetrics.count >= AppConstants.Baseline.minimumDaysForBaseline else { return nil }
        
        // ✅ NEW: Collect all HRV values and filter outliers
        let hrvValues = validMetrics.compactMap { $0.hrvAverage }
        let filteredHRV = HRVOutlierFilter.filterOutliers(hrvValues)
        
        let hrvBaseline = filteredHRV.isEmpty ? nil : filteredHRV.reduce(0.0, +) / Double(filteredHRV.count)
        let hrvStdDev = filteredHRV.isEmpty ? nil : standardDeviation(filteredHRV)
        
        // Log outlier filtering results
        if hrvValues.count != filteredHRV.count {
            let analysis = HRVOutlierFilter.analyzeOutliers(hrvValues)
            print("  📊 HRV Baseline Outlier Analysis:")
            print("    Removed: \(analysis.totalOutliers)/\(analysis.totalSamples) (\(String(format: "%.1f", analysis.outlierPercentage))%)")
            print("    Original avg: \(String(format: "%.1f", analysis.originalAverage)) ms")
            print("    Filtered avg: \(String(format: "%.1f", analysis.filteredAverage)) ms")
            print("    Impact: \(String(format: "%.1f", analysis.impactOnAverage))%")
        }
        
        // ✅ NEW: Filter RHR extreme values
        let rhrValues = validMetrics.compactMap { $0.restingHeartRate }
        let filteredRHR = rhrValues.filter { $0 >= 35 && $0 <= 120 }
        
        let rhrBaseline = filteredRHR.isEmpty ? nil : filteredRHR.reduce(0.0, +) / Double(filteredRHR.count)
        let rhrStdDev = filteredRHR.isEmpty ? nil : standardDeviation(filteredRHR)
        
        // Calculate strain baselines (no filtering needed)
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

// MARK: - Async/Await Support
extension DataSyncService {
    
    /// Async version of saveDailyMetrics
    func saveDailyMetricsAsync(_ metrics: SimpleDailyMetrics) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    try self.repository.saveDailyMetrics(metrics)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Async version of fetchDailyMetrics
    func fetchDailyMetricsAsync(for date: Date) async throws -> SimpleDailyMetrics? {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let metrics = try self.repository.fetchDailyMetrics(for: date)
                    continuation.resume(returning: metrics)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
