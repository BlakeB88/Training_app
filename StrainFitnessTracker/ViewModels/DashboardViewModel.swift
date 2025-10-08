//
//  DashboardViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
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
    @Published var errorMessage: String?
    @Published var healthKitAuthorized = false
    
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
        
        do {
            // Request HealthKit authorization
            try await healthKitManager.requestAuthorization()
            healthKitAuthorized = true
            
            // Load existing data from repository
            loadStoredData()
            
            // Sync with HealthKit
            await syncWithHealthKit()
            
        } catch {
            errorMessage = "Failed to initialize: \(error.localizedDescription)"
            healthKitAuthorized = false
        }
        
        isLoading = false
    }
    
    /// Refresh all data
    func refresh() async {
        isLoading = true
        errorMessage = nil
        
        await syncWithHealthKit()
        
        isLoading = false
    }
    
    /// Sync today's data with HealthKit
    func syncToday() async {
        let today = Date().startOfDay
        await syncDay(today)
    }
    
    // MARK: - Private Methods
    
    private func loadStoredData() {
        do {
            // Load today's metrics
            todayMetrics = try repository.fetchDailyMetrics(for: Date())
            
            // Load recent metrics
            recentMetrics = try repository.fetchRecentDailyMetrics(days: daysToFetch)
        } catch {
            print("Error loading stored data: \(error)")
        }
    }
    
    private func syncWithHealthKit() async {
        let endDate = Date().startOfDay
        let startDate = Calendar.current.date(byAdding: .day, value: -daysToFetch, to: endDate)!
        
        // Sync each day
        var currentDate = startDate
        while currentDate <= endDate {
            await syncDay(currentDate)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Reload data after sync
        loadStoredData()
    }
    
    private func syncDay(_ date: Date) async {
        do {
            let dayStart = date.startOfDay
            let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
            
            // Fetch workouts from HealthKit
            let hkWorkouts = try await healthKitManager.fetchWorkouts(from: dayStart, to: dayEnd)
            
            guard !hkWorkouts.isEmpty else {
                // No workouts for this day
                return
            }
            
            // Get heart rate profile
            let restingHR = try await healthKitManager.fetchRestingHeartRate() ?? 60.0
            let maxHR = 220.0 - 30.0 // Estimate, adjust based on user age
            let hrProfile = HeartRateProfile(
                maxHeartRate: maxHR,
                restingHeartRate: restingHR,
                age: 30 // You'll need to get this from user profile
            )
            
            // Calculate total daily strain
            let totalStrain = await StrainCalculator.calculateDailyStrain(
                workouts: hkWorkouts,
                hrProfile: hrProfile
            )
            
            // Create workout summaries
            var workoutSummaries: [WorkoutSummary] = []
            for hkWorkout in hkWorkouts {
                let workoutStrain = await StrainCalculator.calculateWorkoutStrain(
                    workout: hkWorkout,
                    hrProfile: hrProfile
                )
                
                let heartRateData = try await healthKitManager.fetchHeartRateData(for: hkWorkout)
                let avgHR = heartRateData.isEmpty ? nil : heartRateData.reduce(0.0, +) / Double(heartRateData.count)
                let maxHRValue = heartRateData.max()
                
                let intensity = avgHR.map { StrainCalculator.calculateHRIntensity(avgHR: $0, profile: hrProfile) }
                
                // Get calories using the new API
                let calories: Double
                if let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
                   let energyStats = hkWorkout.statistics(for: energyType),
                   let energySum = energyStats.sumQuantity() {
                    calories = energySum.doubleValue(for: .kilocalorie())
                } else {
                    calories = 0
                }
                
                let summary = WorkoutSummary(
                    id: UUID(),
                    workoutType: hkWorkout.workoutActivityType,
                    startDate: hkWorkout.startDate,
                    endDate: hkWorkout.endDate,
                    duration: hkWorkout.duration / 60.0, // Convert to minutes
                    distance: hkWorkout.totalDistance?.doubleValue(for: .meter()),
                    calories: calories,
                    averageHeartRate: avgHR,
                    maxHeartRate: maxHRValue,
                    swimmingStrokeStyle: nil, // Add swimming logic if needed
                    lapCount: nil,
                    strain: workoutStrain,
                    heartRateIntensity: intensity
                )
                
                workoutSummaries.append(summary)
            }
            
            // Fetch sleep data
            let sleepDuration = try await healthKitManager.fetchSleepDuration(from: dayStart, to: dayEnd)
            
            // Fetch HRV and resting heart rate
            let hrvReadings = try await healthKitManager.fetchHRVReadings(from: dayStart, to: dayEnd)
            let hrvAverage = hrvReadings.isEmpty ? nil : hrvReadings.reduce(0.0, +) / Double(hrvReadings.count)
            
            // Calculate recovery
            var recovery: Double?
            var recoveryComponents: RecoveryComponents?
            
            // Get baseline metrics
            let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
            if let baseline = BaselineCalculator.calculateBaselines(from: historicalMetrics, forDate: date) {
                
                let recoveryScore = RecoveryCalculator.calculateRecoveryScore(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration
                )
                
                recovery = recoveryScore
                
                recoveryComponents = RecoveryCalculator.recoveryComponents(
                    hrvCurrent: hrvAverage,
                    hrvBaseline: baseline.hrvBaseline,
                    rhrCurrent: restingHR,
                    rhrBaseline: baseline.rhrBaseline,
                    sleepDuration: sleepDuration,
                    respiratoryRate: nil
                )
            }
            
            // Create daily metrics
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
            try repository.saveDailyMetrics(dailyMetrics)
            
        } catch {
            print("Error syncing day \(date): \(error)")
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
