//
//  DashboardViewModel.swift - ENHANCED VERSION
//  StrainFitnessTracker
//
//  Now with better time tracking and force refresh capability
//

import Foundation
import Combine
import HealthKit

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var metrics: DailyMetrics
    @Published var weekData: StrainRecoveryWeekData
    @Published var detailedMetrics: [HealthMetric] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var needsAuthorization: Bool = false
    
    // MARK: - Dependencies
    private let dataSyncService: DataSyncService
    private let repository: MetricsRepository
    private let stressMonitorVM: StressMonitorViewModel
    
    private var cancellables = Set<AnyCancellable>()
    private var hasInitialized = false
    
    // MARK: - Initialization
    init(
        dataSyncService: DataSyncService,
        repository: MetricsRepository,
        stressMonitorVM: StressMonitorViewModel
    ) {
        self.dataSyncService = dataSyncService
        self.repository = repository
        self.stressMonitorVM = stressMonitorVM
        
        // Start with sample data (will be replaced on first load)
        self.metrics = DailyMetrics.sampleData
        self.weekData = StrainRecoveryWeekData.sampleData
        self.detailedMetrics = Self.generateDetailedMetrics(from: metrics)
    }
    
    // MARK: - Computed Properties for Time Display
    
    /// Shows when the data was last synced from HealthKit
    var lastSyncTime: String {
        if let syncDate = dataSyncService.lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: syncDate)
        }
        return "Never"
    }
    
    /// Shows the timestamp of the most recent stress reading
    var lastStressReadingTime: String {
        if let lastReading = metrics.stressHistory.last {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: lastReading.timestamp)
        }
        return "No data"
    }
    
    /// Combined display showing both reading time and sync time
    var lastStressUpdate: String {
        if let lastReading = metrics.stressHistory.last {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let readingTime = formatter.string(from: lastReading.timestamp)
            
            // Show sync time if significantly different from reading time
            if let syncDate = dataSyncService.lastSyncDate,
               abs(syncDate.timeIntervalSince(lastReading.timestamp)) > 60 { // More than 1 min difference
                let syncTime = formatter.string(from: syncDate)
                return "\(readingTime) (synced \(syncTime))"
            }
            
            return readingTime
        }
        
        // If no readings, show when we last tried to sync
        if let syncDate = dataSyncService.lastSyncDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "Synced \(formatter.string(from: syncDate))"
        }
        
        return "No data"
    }
    
    /// Simple display for cards - just the reading time
    var lastStressUpdateSimple: String {
        if let lastReading = metrics.stressHistory.last {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: lastReading.timestamp)
        }
        return ""
    }
    
    // MARK: - Public Methods
    
    /// Initialize the dashboard - request authorization and load data
    func initialize() async {
        guard !hasInitialized else { return }
        hasInitialized = true
        
        // Setup observers now that we're initialized
        setupObservers()
        
        isLoading = true
        errorMessage = nil
        
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            isLoading = false
            return
        }
        
        // Request authorization if needed
        if !HealthKitManager.shared.isAuthorized {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                needsAuthorization = false
            } catch {
                errorMessage = "Please grant HealthKit access in Settings to use this app"
                needsAuthorization = true
                isLoading = false
                return
            }
        }
        
        // Initialize stress monitoring (for real-time updates)
        await stressMonitorVM.initialize()
        
        // Try to load data from repository first (might have cached data)
        await loadFromRepository()
        
        // If no data exists or data is old, do initial sync with force refresh
        let shouldForceRefresh = shouldRefreshData()
        if metrics.date != Date().startOfDay || shouldForceRefresh {
            await refreshData(forceRefresh: shouldForceRefresh)
        }
        
        isLoading = false
    }
    
    /// Refresh all dashboard data (triggers HealthKit sync)
    func refreshData(forceRefresh: Bool = true) async {
        // Don't sync if not authorized
        guard HealthKitManager.shared.isAuthorized else {
            errorMessage = "HealthKit access required"
            needsAuthorization = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        print("🔄 Dashboard refresh requested (force: \(forceRefresh))")
        
        // 1. Sync with HealthKit (now includes force refresh option!)
        await dataSyncService.quickSync(forceRefresh: forceRefresh)
        
        // 2. Check for errors
        if let syncError = dataSyncService.syncError {
            // Don't show error if it's just "no data yet"
            if syncError.localizedDescription.contains("No data") {
                print("ℹ️ No data available yet")
            } else {
                errorMessage = syncError.localizedDescription
                print("❌ Dashboard refresh error: \(syncError)")
            }
        }
        
        // 3. Load synced data from repository
        await loadFromRepository()
        
        isLoading = false
        
        print("✅ Dashboard refresh completed")
    }
    
    /// Quick refresh of just stress data (lightweight)
    func refreshStressData() async {
        print("🔄 Refreshing stress data only...")
        
        await dataSyncService.refreshStressData()
        await loadFromRepository()
        
        print("✅ Stress data refresh completed")
    }
    
    /// Load data for a specific date
    func loadData(for date: Date, forceRefresh: Bool = false) async {
        guard HealthKitManager.shared.isAuthorized else {
            errorMessage = "HealthKit access required"
            needsAuthorization = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Sync that specific date
        await dataSyncService.syncDate(date, forceRefresh: forceRefresh)
        
        // Check for sync errors
        if let syncError = dataSyncService.syncError {
            if !syncError.localizedDescription.contains("No data") {
                errorMessage = syncError.localizedDescription
            }
        }
        
        // Load from repository
        await loadFromRepository(for: date)
        
        isLoading = false
    }
    
    /// Sync with HealthKit (full sync with force refresh)
    func syncHealthKit() async {
        isLoading = true
        
        // Request authorization if needed
        if !HealthKitManager.shared.isAuthorized {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                needsAuthorization = false
            } catch {
                errorMessage = "Failed to authorize HealthKit"
                needsAuthorization = true
                isLoading = false
                return
            }
        }
        
        // Do full sync (last 7 days) with force refresh
        await dataSyncService.fullSync(days: 7, forceRefresh: true)
        
        // Load fresh data
        await loadFromRepository()
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    /// Check if we should force refresh data
    private func shouldRefreshData() -> Bool {
        // Force refresh if no sync yet
        guard let lastSync = dataSyncService.lastSyncDate else {
            print("  ⚠️ No previous sync - will force refresh")
            return true
        }
        
        // Force refresh if last sync was more than 5 minutes ago
        let minutesSinceSync = Date().timeIntervalSince(lastSync) / 60
        if minutesSinceSync > 5 {
            print("  ⚠️ Last sync was \(Int(minutesSinceSync)) minutes ago - will force refresh")
            return true
        }
        
        // Force refresh if we have no stress data
        if metrics.stressHistory.isEmpty {
            print("  ⚠️ No stress history - will force refresh")
            return true
        }
        
        // Check if stress data is stale (last reading > 15 minutes ago)
        if let lastReading = metrics.stressHistory.last {
            let minutesSinceReading = Date().timeIntervalSince(lastReading.timestamp) / 60
            if minutesSinceReading > 15 {
                print("  ⚠️ Last stress reading was \(Int(minutesSinceReading)) minutes ago - will force refresh")
                return true
            }
        }
        
        return false
    }
    
    private func loadFromRepository(for date: Date = Date()) async {
        print("📂 Loading from repository for \(date.formatted())...")
        
        // Load today's metrics
        guard let simpleDailyMetrics = try? repository.fetchDailyMetrics(for: date) else {
            // No data yet - this is normal for first launch
            print("⚠️ No data in repository for \(date.formatted())")
            // Keep showing sample data
            return
        }
        
        print("✅ Found metrics in repository:")
        print("  Date: \(simpleDailyMetrics.date.formatted())")
        print("  Sleep Duration: \(simpleDailyMetrics.sleepDuration ?? 0) hours")
        print("  Steps: \(simpleDailyMetrics.steps ?? 0)")
        print("  Calories: \(simpleDailyMetrics.activeCalories ?? 0)")
        print("  Strain: \(simpleDailyMetrics.strain)")
        print("  Recovery: \(simpleDailyMetrics.recovery ?? 0)")
        
        // ✨ Detailed stress logging
        print("  📊 STRESS METRICS:")
        print("    Average Stress: \(simpleDailyMetrics.averageStress ?? 0)")
        print("    Max Stress: \(simpleDailyMetrics.maxStress ?? 0)")
        print("    Stress Readings: \(simpleDailyMetrics.stressReadings?.count ?? 0)")
        print("    Time in High Stress: \(simpleDailyMetrics.timeInHighStress ?? 0)h")
        print("    Time in Medium Stress: \(simpleDailyMetrics.timeInMediumStress ?? 0)h")
        print("    Time in Low Stress: \(simpleDailyMetrics.timeInLowStress ?? 0)h")
        
        let lastUpdated = simpleDailyMetrics.lastUpdated
        let minutesAgo = Int(Date().timeIntervalSince(lastUpdated) / 60)
        print("    Last Updated: \(lastUpdated.formatted(date: .omitted, time: .shortened)) (\(minutesAgo) min ago)")
        
        // Load week data
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: date)!
        let weekMetrics = (try? repository.fetchDailyMetrics(from: weekStart, to: date)) ?? []
        print("  📊 Loaded \(weekMetrics.count) days of week data")
        
        // Convert to UI models
        let uiMetrics = convertToUIMetrics(simpleDailyMetrics)
        let uiWeekData = convertToWeekData(weekMetrics)
        
        // Update UI
        self.metrics = uiMetrics
        self.weekData = uiWeekData
        self.detailedMetrics = Self.generateDetailedMetrics(from: metrics)
        
        print("✅ Dashboard UI updated with real data")
        print("  UI Stress History Count: \(self.metrics.stressHistory.count)")
        print("  UI Current Stress: \(self.metrics.currentStress)")
        
        // Debug data freshness
        debugStressDataFreshness()
    }
    
    private func setupObservers() {
        // Observe sync completion
        dataSyncService.$lastSyncDate
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadFromRepository()
                }
            }
            .store(in: &cancellables)
        
        // ✨ Only use real-time stress for current reading updates
        // Historical stress comes from repository now
        stressMonitorVM.$currentStress
            .compactMap { $0 }
            .sink { [weak self] stress in
                // Only update current stress value, not history
                self?.metrics.currentStress = stress.stressLevel
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Conversion Methods
    
    private func convertToUIMetrics(_ simple: SimpleDailyMetrics) -> DailyMetrics {
        print("🔄 Converting SimpleDailyMetrics to DailyMetrics...")
        
        // Calculate sleep score
        let sleepScore = calculateSleepScore(simple)
        
        // Convert workouts to activities
        let activities = convertWorkoutsToActivities(simple.workouts)
        
        // Add sleep activity if available
        var allActivities = activities
        if let sleepDuration = simple.sleepDuration,
           sleepDuration > 0,
           let sleepStart = simple.sleepStart {  // ← Add this condition
            
            // Now sleepStart is safely unwrapped
            let sleepEnd = simple.sleepEnd ?? sleepStart.addingTimeInterval(sleepDuration * 3600)
            
            let sleepActivity = Activity(
                type: .sleep,
                startTime: sleepStart,  // ← No need for ?? now
                endTime: sleepEnd,      // ← No need for ?? now
                strain: nil,
                duration: sleepDuration * 3600
            )
            allActivities.insert(sleepActivity, at: 0)
        }
        
        // ✨ Convert stress readings from persisted data
        let stressHistory = convertStressReadings(simple.stressReadings ?? [], activities: allActivities)
        
        // ✨ Use persisted stress or fall back to real-time
        let currentStress = simple.averageStress ?? stressMonitorVM.currentStressLevel
        
        print("  📊 Converted stress data:")
        print("    Stress history points: \(stressHistory.count)")
        print("    Current stress: \(currentStress)")
        
        let metrics = DailyMetrics(
            date: simple.date,
            sleepScore: sleepScore,
            recoveryScore: simple.recovery ?? 0,
            strainScore: simple.strain,
            
            // Sleep Metrics
            sleepDuration: (simple.sleepDuration ?? 0) * 3600,
            restorativeSleepPercentage: simple.restorativeSleepPercentage ?? 0,
            sleepEfficiency: simple.sleepEfficiency ?? 0,
            sleepConsistency: simple.sleepConsistency ?? 0,
            timeInBed: (simple.timeInBed ?? 0) * 3600,
            sleepDebt: (simple.sleepDebt ?? 0) * 3600,
            respiratoryRate: simple.respiratoryRate ?? simple.baselineMetrics?.respiratoryRateBaseline ?? 14.0,
            
            // Activity Metrics
            calories: Int(simple.activeCalories ?? 0),
            steps: simple.steps ?? 0,
            averageHeartRate: Int(simple.averageHeartRate ?? simple.restingHeartRate ?? 60),
            restingHeartRate: Int(simple.restingHeartRate ?? 60),
            vo2Max: simple.vo2Max ?? 0,
            
            // ✨ Stress Metrics (from persisted data!)
            currentStress: currentStress,
            stressHistory: stressHistory,
            
            // Activities
            activities: allActivities,
            
            // Health Monitor
            healthMetricsInRange: calculateMetricsInRange(simple),
            totalHealthMetrics: 5
        )
        
        return metrics
    }

    /// ✨ Convert persisted StressReading objects to StressDataPoint for UI
    private func convertStressReadings(_ readings: [StressReading], activities: [Activity]) -> [StressDataPoint] {
        return readings.map { reading in
            // Try to match with an activity
            let matchingActivity = activities.first { activity in
                reading.timestamp >= activity.startTime &&
                reading.timestamp <= activity.endTime
            }
            
            return StressDataPoint(
                timestamp: reading.timestamp,
                value: reading.stressLevel,
                activity: matchingActivity
            )
        }
    }

    /// Improved sleep score calculation using multiple factors
    private func calculateSleepScore(_ metrics: SimpleDailyMetrics) -> Double {
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

    /// Improved metrics in range calculation
    private func calculateMetricsInRange(_ metrics: SimpleDailyMetrics) -> Int {
        var inRange = 0
        
        // 1. Check HRV (within 15% of baseline)
        if let hrv = metrics.hrvAverage,
           let baseline = metrics.baselineMetrics?.hrvBaseline {
            let percentDiff = abs(hrv - baseline) / baseline
            if percentDiff < 0.15 {
                inRange += 1
            }
        }
        
        // 2. Check RHR (within 5 bpm of baseline)
        if let rhr = metrics.restingHeartRate,
           let baseline = metrics.baselineMetrics?.rhrBaseline {
            if abs(rhr - baseline) < 5 {
                inRange += 1
            }
        }
        
        // 3. Check Sleep Duration (7+ hours)
        if let sleep = metrics.sleepDuration, sleep >= 7 {
            inRange += 1
        }
        
        // 4. Check Recovery (70%+ is good)
        if let recovery = metrics.recovery, recovery >= 70 {
            inRange += 1
        }
        
        // 5. Check Strain (not overtraining - below 18)
        if metrics.strain < 18 {
            inRange += 1
        }
        
        return inRange
    }
    
    private func convertWorkoutsToActivities(_ workouts: [WorkoutSummary]) -> [Activity] {
        return workouts.map { workout in
            Activity(
                type: mapWorkoutType(workout.workoutType),
                startTime: workout.startDate,
                endTime: workout.endDate,
                strain: workout.strain,
                duration: workout.duration
            )
        }
    }
    
    private func mapWorkoutType(_ hkType: HKWorkoutActivityType) -> Activity.ActivityType {
        switch hkType {
        case .swimming: return .swimming
        case .running: return .running
        case .cycling: return .cycling
        case .walking: return .walking
        default: return .workout
        }
    }
    
    private func convertToWeekData(_ weekMetrics: [SimpleDailyMetrics]) -> StrainRecoveryWeekData {
        let dayData = weekMetrics.map { metrics in
            StrainRecoveryWeekData.DayData(
                date: metrics.date,
                strain: metrics.strain,
                recovery: metrics.recovery ?? 0
            )
        }
        
        return StrainRecoveryWeekData(weekDays: dayData)
    }
    
    private static func generateDetailedMetrics(from metrics: DailyMetrics) -> [HealthMetric] {
        return [
            .steps(value: metrics.steps, baseline: 7332),
            .restingHeartRate(value: metrics.restingHeartRate, baseline: 49),
            .calories(value: metrics.calories, baseline: 2786),
            .hoursOfSleep(value: metrics.sleepDuration, baseline: 7 * 3600 + 48 * 60),
            .restorativeSleep(value: metrics.restorativeSleepPercentage, baseline: 39),
            .respiratoryRate(value: metrics.respiratoryRate, baseline: 14.3),
            .sleepEfficiency(value: metrics.sleepEfficiency, baseline: 86),
            .sleepConsistency(value: metrics.sleepConsistency, baseline: 69),
            .timeInBed(value: metrics.timeInBed, baseline: 9 * 3600 + 45 * 60),
            .sleepDebt(value: metrics.sleepDebt, baseline: 44 * 60),
            .vo2Max(value: metrics.vo2Max, baseline: 60),
            .averageHeartRate(value: metrics.averageHeartRate, baseline: 68)
        ]
    }
    
    // MARK: - Debug Methods
    
    /// Debug info about stress data freshness
    func debugStressDataFreshness() {
        print("\n🕐 === STRESS DATA FRESHNESS ===")
        print("Current time: \(Date().formatted(date: .omitted, time: .shortened))")
        
        if let syncDate = dataSyncService.lastSyncDate {
            let minutesAgo = Int(Date().timeIntervalSince(syncDate) / 60)
            print("Last sync: \(syncDate.formatted(date: .omitted, time: .shortened)) (\(minutesAgo) min ago)")
        } else {
            print("Last sync: Never")
        }
        
        if let stressFetch = dataSyncService.lastStressDataFetch {
            let minutesAgo = Int(Date().timeIntervalSince(stressFetch) / 60)
            print("Last stress fetch: \(stressFetch.formatted(date: .omitted, time: .shortened)) (\(minutesAgo) min ago)")
        } else {
            print("Last stress fetch: Never")
        }
        
        if let lastReading = metrics.stressHistory.last {
            let minutesAgo = Int(Date().timeIntervalSince(lastReading.timestamp) / 60)
            print("Last stress reading: \(lastReading.timestamp.formatted(date: .omitted, time: .shortened)) (\(minutesAgo) min ago)")
            print("Reading value: \(String(format: "%.2f", lastReading.value))")
        } else {
            print("Last stress reading: None")
        }
        
        print("Total readings today: \(metrics.stressHistory.count)")
        
        // Check if we have recent readings
        let recentReadings = metrics.stressHistory.filter {
            Date().timeIntervalSince($0.timestamp) < 15 * 60 // Last 15 minutes
        }
        print("Readings in last 15 min: \(recentReadings.count)")
        
        print("================================\n")
    }
}
