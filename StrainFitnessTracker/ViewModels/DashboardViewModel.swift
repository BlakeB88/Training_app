//
//  DashboardViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//  Enhanced with detailed error logging
//

import Foundation
import Combine
import HealthKit

@MainActor
class DashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var todayMetrics: DailyMetrics?
    @Published var recentMetrics: [DailyMetrics] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var errorMessage: String?
    @Published var healthKitAuthorized = false
    @Published var lastSyncDate: Date?
    
    // MARK: - Computed Properties
    var todayStrain: Double {
        todayMetrics?.strain ?? 0
    }
    
    var todayRecovery: Double? {
        todayMetrics?.recovery
    }
    
    var todayWorkoutCount: Int {
        todayMetrics?.workoutCount ?? 0
    }
    
    var hasDataForToday: Bool {
        todayMetrics != nil
    }
    
    var weeklyAverageStrain: Double? {
        guard !recentMetrics.isEmpty else { return nil }
        let total = recentMetrics.reduce(0.0) { $0 + $1.strain }
        return total / Double(recentMetrics.count)
    }
    
    var weeklyAverageRecovery: Double? {
        let recoveries = recentMetrics.compactMap { $0.recovery }
        guard !recoveries.isEmpty else { return nil }
        return recoveries.reduce(0.0, +) / Double(recoveries.count)
    }
    
    // MARK: - Dependencies
    private let healthKitManager: HealthKitManager
    private let repository: MetricsRepository
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let daysToFetch = 7
    
    // MARK: - Initialization
    init(
        healthKitManager: HealthKitManager? = nil,
        repository: MetricsRepository? = nil
    ) {
        self.healthKitManager = healthKitManager ?? HealthKitManager.shared
        self.repository = repository ?? MetricsRepository()
    }
    
    // MARK: - Public Methods
    
    /// Initial setup - request authorization and load data
    func initialize() async {
        isLoading = true
        errorMessage = nil
        
        print("🚀 ========== INITIALIZATION STARTED ==========")
        
        do {
            // Step 1: HealthKit Authorization
            print("📱 Step 1: Requesting HealthKit authorization...")
            try await healthKitManager.requestAuthorization()
            healthKitAuthorized = true
            print("✅ HealthKit authorized successfully")
            
            // Step 2: Load existing data
            print("💾 Step 2: Loading stored data from CoreData...")
            loadStoredData()
            print("✅ Stored data loaded")
            print("   - Today's metrics: \(todayMetrics != nil ? "Found" : "None")")
            print("   - Recent metrics count: \(recentMetrics.count)")
            
            // Step 3: Sync with HealthKit
            print("🔄 Step 3: Starting HealthKit sync...")
            await syncWithHealthKit()
            lastSyncDate = Date()
            print("✅ HealthKit sync completed")
            
            print("🎉 ========== INITIALIZATION COMPLETE ==========")
            
        } catch {
            print("❌❌❌ ========== INITIALIZATION FAILED ========== ❌❌❌")
            print("Error type: \(type(of: error))")
            print("Error description: \(error)")
            print("Localized description: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("NSError details:")
                print("  - Domain: \(nsError.domain)")
                print("  - Code: \(nsError.code)")
                print("  - UserInfo: \(nsError.userInfo)")
            }
            
            if let hkError = error as? HealthKitError {
                print("HealthKit Error: \(hkError.errorDescription ?? "Unknown")")
            }
            
            errorMessage = "Failed to initialize: \(error.localizedDescription)"
            healthKitAuthorized = false
            print("❌❌❌ ========================================== ❌❌❌")
        }
        
        isLoading = false
        print("🏁 Initialize method completed (isLoading: false)")
    }
    
    /// Refresh all data
    func refresh() async {
        print("🔄 ========== REFRESH STARTED ==========")
        isLoading = true
        errorMessage = nil
        
        await syncWithHealthKit()
        lastSyncDate = Date()
        
        isLoading = false
        print("🏁 ========== REFRESH COMPLETE ==========")
    }
    
    /// Sync today's data with HealthKit
    func syncToday() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        print("🔄 Syncing today's data...")
        let today = Date().startOfDay
        await syncDay(today)
        loadStoredData()
        lastSyncDate = Date()
        isSyncing = false
        print("✅ Today's sync complete")
    }
    
    // MARK: - Private Methods
    
    private func loadStoredData() {
        do {
            print("   📖 Loading today's metrics...")
            todayMetrics = try repository.fetchDailyMetrics(for: Date())
            if let metrics = todayMetrics {
                print("   ✓ Today's metrics found: Strain=\(metrics.strain), Recovery=\(metrics.recovery ?? -1)")
            } else {
                print("   ℹ️ No metrics found for today")
            }
            
            print("   📖 Loading recent metrics (last \(daysToFetch) days)...")
            recentMetrics = try repository.fetchRecentDailyMetrics(days: daysToFetch)
            print("   ✓ Loaded \(recentMetrics.count) days of metrics")
            
        } catch {
            print("   ❌ Error loading stored data: \(error)")
            print("   Error type: \(type(of: error))")
            if let nsError = error as NSError? {
                print("   NSError - Domain: \(nsError.domain), Code: \(nsError.code)")
            }
        }
    }
    
    private func syncWithHealthKit() async {
        let endDate = Date().startOfDay
        let startDate = Calendar.current.date(byAdding: .day, value: -daysToFetch, to: endDate)!
        
        print("   🔄 Syncing \(daysToFetch) days from \(startDate.formatted()) to \(endDate.formatted())")
        
        // Sync each day
        var currentDate = startDate
        var dayCount = 0
        while currentDate <= endDate {
            dayCount += 1
            print("   📅 Processing day \(dayCount)/\(daysToFetch + 1): \(currentDate.formatted(.dateTime.month().day()))")
            await syncDay(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        print("   🔄 Reloading data after sync...")
        loadStoredData()
        print("   ✅ Sync complete - Final data loaded")
    }
    
    private func syncDay(_ date: Date) async {
        let dayStart = date.startOfDay
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        
        print("      🔍 Syncing: \(dayStart.formatted(.dateTime.month().day().year()))")
        
        do {
            // Fetch workouts
            print("      ├─ Fetching workouts...")
            let hkWorkouts = try await healthKitManager.fetchWorkouts(from: dayStart, to: dayEnd)
            print("      ├─ Found \(hkWorkouts.count) workout(s)")
            
            guard !hkWorkouts.isEmpty else {
                print("      └─ ⊘ No workouts, skipping")
                return
            }
            
            // Get heart rate profile
            print("      ├─ Fetching resting heart rate...")
            let restingHR = try await healthKitManager.fetchRestingHeartRate() ?? 60.0
            print("      ├─ Resting HR: \(restingHR) bpm")
            
            let maxHR = 220.0 - 30.0 // TODO: Get from user profile
            let hrProfile = HeartRateProfile(
                maxHeartRate: maxHR,
                restingHeartRate: restingHR,
                age: 30
            )
            
            // Calculate daily strain
            print("      ├─ Calculating strain...")
            let totalStrain = await StrainCalculator.calculateDailyStrain(
                workouts: hkWorkouts,
                hrProfile: hrProfile
            )
            print("      ├─ Total strain: \(String(format: "%.1f", totalStrain))")
            
            // Create workout summaries
            print("      ├─ Creating workout summaries...")
            var workoutSummaries: [WorkoutSummary] = []
            for (index, hkWorkout) in hkWorkouts.enumerated() {
                print("      │  ├─ Workout \(index + 1): \(hkWorkout.workoutActivityType.name)")
                
                let workoutStrain = await StrainCalculator.calculateWorkoutStrain(
                    workout: hkWorkout,
                    hrProfile: hrProfile
                )
                
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: hkWorkout)
                let avgHR = heartRateData.isEmpty ? nil : heartRateData.reduce(0.0, +) / Double(heartRateData.count)
                let maxHRValue = heartRateData.max()
                
                let intensity = avgHR.map { StrainCalculator.calculateHRIntensity(avgHR: $0, profile: hrProfile) }
                
                // Get calories
                let calories: Double
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                   let energyStats = hkWorkout.statistics(for: energyType),
                   let energySum = energyStats.sumQuantity() {
                    calories = energySum.doubleValue(for: .kilocalorie())
                } else {
                    calories = 0
                }
                
                print("      │  └─ Strain: \(String(format: "%.1f", workoutStrain)), Calories: \(Int(calories))")
                
                let summary = WorkoutSummary(
                    id: UUID(),
                    workoutType: hkWorkout.workoutActivityType,
                    startDate: hkWorkout.startDate,
                    endDate: hkWorkout.endDate,
                    duration: hkWorkout.duration / 60.0,
                    distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                    calories: calories,
                    averageHeartRate: avgHR,
                    maxHeartRate: maxHRValue,
                    swimmingStrokeStyle: nil,
                    lapCount: nil,
                    strain: workoutStrain,
                    heartRateIntensity: intensity
                )
                
                workoutSummaries.append(summary)
            }
            print("      ├─ Created \(workoutSummaries.count) workout summary(ies)")
            
            // Fetch sleep data
            print("      ├─ Fetching sleep data...")
            let sleepDuration = try await healthKitManager.fetchSleepDuration(from: dayStart, to: dayEnd)
            print("      ├─ Sleep: \(String(format: "%.1f", sleepDuration))h")
            
            // Fetch HRV
            print("      ├─ Fetching HRV...")
            let hrvReadings = try await healthKitManager.fetchHRVReadings(from: dayStart, to: dayEnd)
            let hrvAverage = hrvReadings.isEmpty ? nil : hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
            print("      ├─ HRV: \(hrvAverage.map { String(format: "%.1f", $0) } ?? "N/A") ms")
            
            // Calculate recovery
            print("      ├─ Calculating recovery...")
            var recovery: Double?
            var recoveryComponents: RecoveryComponents?
            
            let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
            print("      ├─ Historical data: \(historicalMetrics.count) days")
            
            if let baseline = BaselineCalculator.calculateBaselines(from: historicalMetrics, forDate: date) {
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
                print("      ├─ Recovery: \(recovery.map { String(format: "%.0f", $0) } ?? "N/A")%")
            } else {
                print("      ├─ Recovery: N/A (insufficient baseline data)")
            }
            
            // Create daily metrics
            print("      ├─ Creating daily metrics object...")
            let dailyMetrics = DailyMetrics(
                date: dayStart,
                strain: totalStrain,
                recovery: recovery,
                recoveryComponents: recoveryComponents,
                workouts: workoutSummaries,
                sleepDuration: sleepDuration > 0 ? sleepDuration : nil,
                sleepStart: nil,
                sleepEnd: nil,
                hrvAverage: hrvAverage,
                restingHeartRate: restingHR
            )
            
            // Save to repository
            print("      ├─ Saving to CoreData...")
            try repository.saveDailyMetrics(dailyMetrics)
            print("      └─ ✅ Day saved successfully")
            
        } catch {
            print("      └─ ❌ Error syncing day: \(error)")
            print("         Error type: \(type(of: error))")
            print("         Description: \(error.localizedDescription)")
            
            if let nsError = error as NSError? {
                print("         NSError - Domain: \(nsError.domain), Code: \(nsError.code)")
                print("         UserInfo: \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Helper Extensions
extension DashboardViewModel {
    
    /// Get metrics for a specific date
    func getMetrics(for date: Date) -> DailyMetrics? {
        if date.startOfDay == Date().startOfDay {
            return todayMetrics
        }
        return recentMetrics.first { $0.date.startOfDay == date.startOfDay }
    }
    
    /// Check if data exists for a date
    func hasData(for date: Date) -> Bool {
        getMetrics(for: date) != nil
    }
}
