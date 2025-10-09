//
//  DataSyncService.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
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
            try await syncDay(date.startOfDay)
            updateLastSyncDate()
        } catch {
            syncError = error
            print("Sync date error: \(error)")
        }
        
        isSyncing = false
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
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
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
        }
        
        // Create and save daily metrics
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
        
        let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
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
        }
        
        // Create metrics with zero strain
        let dailyMetrics = DailyMetrics(
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
            duration: workout.duration / 60.0,
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
}
