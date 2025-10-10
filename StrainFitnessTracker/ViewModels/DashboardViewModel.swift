//
//  DashboardViewModel.swift (CONNECTED VERSION)
//  StrainFitnessTracker
//
//  Connects to real HealthKit data via DataSyncService
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
        
        // Note: setupObservers will be called in initialize()
    }
    
    // MARK: - Computed Properties
    var lastStressUpdate: String {
        guard let lastPoint = metrics.stressHistory.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastPoint.timestamp)
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
        
        // Initialize stress monitoring
        await stressMonitorVM.initialize()
        
        // Try to load data from repository first (might have cached data)
        await loadFromRepository()
        
        // If no data exists, do initial sync
        if metrics.date != Date().startOfDay {
            await refreshData()
        }
        
        isLoading = false
    }
    
    /// Refresh all dashboard data (triggers HealthKit sync)
    func refreshData() async {
        // Don't sync if not authorized
        guard HealthKitManager.shared.isAuthorized else {
            errorMessage = "HealthKit access required"
            needsAuthorization = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // 1. Sync with HealthKit
        await dataSyncService.quickSync()
        
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
    }
    
    /// Load data for a specific date
    func loadData(for date: Date) async {
        guard HealthKitManager.shared.isAuthorized else {
            errorMessage = "HealthKit access required"
            needsAuthorization = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Sync that specific date
        await dataSyncService.syncDate(date)
        
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
    
    /// Sync with HealthKit
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
        
        // Do full sync (last 7 days)
        await dataSyncService.fullSync(days: 7)
        
        // Load fresh data
        await loadFromRepository()
        
        isLoading = false
    }
    
    // MARK: - Private Methods
    
    private func loadFromRepository(for date: Date = Date()) async {
        // Load today's metrics
        guard let simpleDailyMetrics = try? repository.fetchDailyMetrics(for: date) else {
            // No data yet - this is normal for first launch
            print("ℹ️ No data in repository for \(date.formatted())")
            // Keep showing sample data
            return
        }
        
        // Load week data
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: date)!
        let weekMetrics = (try? repository.fetchDailyMetrics(from: weekStart, to: date)) ?? []
        
        // Convert to UI models
        let uiMetrics = convertToUIMetrics(simpleDailyMetrics)
        let uiWeekData = convertToWeekData(weekMetrics)
        
        // Update UI
        self.metrics = uiMetrics
        self.weekData = uiWeekData
        self.detailedMetrics = Self.generateDetailedMetrics(from: metrics)
        
        print("✅ Dashboard loaded with real data")
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
        
        // Observe stress updates
        stressMonitorVM.$currentStress
            .compactMap { $0 }
            .sink { [weak self] stress in
                self?.updateStress(stress)
            }
            .store(in: &cancellables)
    }
    
    private func updateStress(_ stress: StressMetrics) {
        // Update current stress
        metrics.currentStress = stress.stressLevel
        
        // Add to history
        let stressPoint = StressDataPoint(
            timestamp: stress.timestamp,
            value: stress.stressLevel,
            activity: nil // Could map from current workout
        )
        metrics.stressHistory.append(stressPoint)
        
        // Keep last 24 hours
        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
        metrics.stressHistory = metrics.stressHistory.filter { $0.timestamp >= oneDayAgo }
    }
    
    // MARK: - Conversion Methods
    
    private func convertToUIMetrics(_ simple: SimpleDailyMetrics) -> DailyMetrics {
        // Calculate sleep score (0-100 based on duration and quality)
        let sleepScore = calculateSleepScore(simple)
        
        // Convert workouts to activities
        let activities = convertWorkoutsToActivities(simple.workouts)
        
        // Add sleep activity if available
        var allActivities = activities
        if let sleepDuration = simple.sleepDuration, sleepDuration > 0 {
            let sleepActivity = Activity(
                type: .sleep,
                startTime: simple.sleepStart ?? simple.date,
                endTime: simple.sleepEnd ?? simple.date.addingTimeInterval(sleepDuration * 3600),
                strain: nil,
                duration: sleepDuration * 3600
            )
            allActivities.insert(sleepActivity, at: 0)
        }
        
        return DailyMetrics(
            date: simple.date,
            sleepScore: sleepScore,
            recoveryScore: simple.recovery ?? 0,
            strainScore: simple.strain,
            
            // Sleep Metrics - NOW USING REAL DATA
            sleepDuration: (simple.sleepDuration ?? 0) * 3600,
            restorativeSleepPercentage: simple.restorativeSleepPercentage ?? 0,
            sleepEfficiency: simple.sleepEfficiency ?? 0,
            sleepConsistency: simple.sleepConsistency ?? 0,
            timeInBed: (simple.timeInBed ?? 0) * 3600,
            sleepDebt: (simple.sleepDebt ?? 0) * 3600,
            respiratoryRate: simple.respiratoryRate ?? simple.baselineMetrics?.respiratoryRateBaseline ?? 14.0,
            
            // Activity Metrics - NOW USING REAL DATA
            calories: Int(simple.activeCalories ?? 0),
            steps: simple.steps ?? 0,
            averageHeartRate: Int(simple.averageHeartRate ?? simple.restingHeartRate ?? 60),
            restingHeartRate: Int(simple.restingHeartRate ?? 60),
            vo2Max: simple.vo2Max ?? 0,
            
            // Stress Metrics
            currentStress: stressMonitorVM.currentStressLevel,
            stressHistory: convertStressHistory(),
            
            // Activities
            activities: allActivities,
            
            // Health Monitor
            healthMetricsInRange: calculateMetricsInRange(simple),
            totalHealthMetrics: 5
        )
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
            // Penalize over-sleeping less than under-sleeping
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
        let totalMetrics = 5
        
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
    
    private func convertStressHistory() -> [StressDataPoint] {
        return stressMonitorVM.todayStressData.map { stress in
            StressDataPoint(
                timestamp: stress.timestamp,
                value: stress.stressLevel,
                activity: nil
            )
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
}

