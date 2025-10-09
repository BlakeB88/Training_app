//
//  DashboardViewModel.swift
//  StrainFitnessTracker
//
//  ViewModel for dashboard - connects UI to calculators
//

import Foundation
import Combine

class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var metrics: DailyMetrics
    @Published var weekData: StrainRecoveryWeekData
    @Published var detailedMetrics: [HealthMetric] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Calculator Dependencies
    // These will be injected or initialized with your existing calculators
    // private let baselineCalculator: BaselineCalculator
    // private let recoveryCalculator: RecoveryCalculator
    // private let strainCalculator: StrainCalculator
    // private let stressCalculator: StressCalculator
    // private let healthKitManager: HealthKitManager
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        // For now, using sample data
        // In production, inject your calculators here
        self.metrics = DailyMetrics.sampleData
        self.weekData = StrainRecoveryWeekData.sampleData
        
        // Generate detailed metrics
        self.detailedMetrics = Self.generateDetailedMetrics(from: metrics)
        
        // Setup observers and data refresh
        setupObservers()
    }
    
    // MARK: - Computed Properties
    var lastStressUpdate: String {
        guard let lastPoint = metrics.stressHistory.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastPoint.timestamp)
    }
    
    // MARK: - Public Methods
    
    /// Refresh all dashboard data
    func refreshData() {
        isLoading = true
        errorMessage = nil
        
        // In production, this would fetch from your calculators:
        // Task {
        //     do {
        //         async let sleepData = healthKitManager.fetchSleepData()
        //         async let hrvData = healthKitManager.fetchHRVData()
        //         async let activityData = healthKitManager.fetchActivityData()
        //
        //         let (sleep, hrv, activity) = try await (sleepData, hrvData, activityData)
        //
        //         // Calculate metrics
        //         let recovery = await recoveryCalculator.calculate(hrv: hrv, sleep: sleep)
        //         let strain = await strainCalculator.calculate(activities: activity)
        //         let stress = await stressCalculator.getCurrentStress()
        //
        //         // Update UI on main thread
        //         await MainActor.run {
        //             self.updateMetrics(recovery: recovery, strain: strain, stress: stress)
        //             self.isLoading = false
        //         }
        //     } catch {
        //         await MainActor.run {
        //             self.errorMessage = error.localizedDescription
        //             self.isLoading = false
        //         }
        //     }
        // }
        
        // For demo, just reload sample data
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.metrics = DailyMetrics.sampleData
            self.detailedMetrics = Self.generateDetailedMetrics(from: self.metrics)
            self.isLoading = false
        }
    }
    
    /// Load data for a specific date
    func loadData(for date: Date) {
        // In production, fetch historical data for the selected date
        // For now, just refresh current data
        refreshData()
    }
    
    /// Sync with HealthKit
    func syncHealthKit() {
        isLoading = true
        
        // In production:
        // Task {
        //     do {
        //         try await healthKitManager.requestAuthorization()
        //         await refreshData()
        //     } catch {
        //         await MainActor.run {
        //             self.errorMessage = "Failed to sync with HealthKit"
        //             self.isLoading = false
        //         }
        //     }
        // }
        
        // For demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.refreshData()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // Setup any observers for calculator updates
        // Example:
        // NotificationCenter.default.publisher(for: .healthKitDataUpdated)
        //     .sink { [weak self] _ in
        //         self?.refreshData()
        //     }
        //     .store(in: &cancellables)
    }
    
    private func updateMetrics(recovery: Double, strain: Double, stress: Double) {
        // Update metrics with new calculated values
        metrics.recoveryScore = recovery
        metrics.strainScore = strain
        metrics.currentStress = stress
        
        // Regenerate detailed metrics
        detailedMetrics = Self.generateDetailedMetrics(from: metrics)
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

// MARK: - Integration Guide
/*
 
 INTEGRATION WITH EXISTING CALCULATORS
 ======================================
 
 To connect this ViewModel to your existing calculators, follow these steps:
 
 1. DEPENDENCY INJECTION
    Add your calculators as dependencies:
 
    class DashboardViewModel: ObservableObject {
        private let baselineCalculator: BaselineCalculator
        private let recoveryCalculator: RecoveryCalculator
        private let strainCalculator: StrainCalculator
        private let stressCalculator: StressCalculator
        private let healthKitManager: HealthKitManager
        
        init(
            baselineCalculator: BaselineCalculator,
            recoveryCalculator: RecoveryCalculator,
            strainCalculator: StrainCalculator,
            stressCalculator: StressCalculator,
            healthKitManager: HealthKitManager
        ) {
            self.baselineCalculator = baselineCalculator
            self.recoveryCalculator = recoveryCalculator
            self.strainCalculator = strainCalculator
            self.stressCalculator = stressCalculator
            self.healthKitManager = healthKitManager
            
            // Initialize with empty data
            self.metrics = DailyMetrics(...)
            self.weekData = StrainRecoveryWeekData(...)
            
            // Load initial data
            Task {
                await refreshData()
            }
        }
    }
 
 2. IMPLEMENT REFRESH DATA
    Update the refreshData() method to use your calculators:
 
    func refreshData() async {
        isLoading = true
        
        do {
            // Fetch from HealthKit
            let sleepData = try await healthKitManager.querySleep(for: Date())
            let hrvData = try await healthKitManager.queryHRV(for: Date())
            let workouts = try await healthKitManager.queryWorkouts(for: Date())
            
            // Calculate metrics
            let baseline = baselineCalculator.calculate(hrv: hrvData, sleep: sleepData)
            let recovery = recoveryCalculator.calculateRecovery(
                hrv: hrvData,
                sleep: sleepData,
                baseline: baseline
            )
            let strain = strainCalculator.calculateStrain(workouts: workouts)
            let stress = stressCalculator.calculateStress(hrv: hrvData)
            
            // Update UI
            await MainActor.run {
                self.updateMetrics(
                    sleepScore: sleepData.score,
                    recovery: recovery,
                    strain: strain,
                    stress: stress
                )
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
 
 3. MAP CALCULATOR OUTPUT TO DAILYMETRICS
    Create a method to convert your calculator outputs to DailyMetrics:
 
    private func createDailyMetrics(
        from sleepData: SleepData,
        recovery: RecoveryData,
        strain: StrainData,
        stress: StressData
    ) -> DailyMetrics {
        return DailyMetrics(
            date: Date(),
            sleepScore: sleepData.score,
            recoveryScore: recovery.score,
            strainScore: strain.score,
            sleepDuration: sleepData.duration,
            // ... map all other fields
        )
    }
 
 4. HANDLE REAL-TIME UPDATES
    If your calculators provide real-time updates, set up observers:
 
    private func setupObservers() {
        // Example: Observe HRV updates for real-time stress
        stressCalculator.stressUpdates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStress in
                self?.metrics.currentStress = newStress.value
                self?.metrics.stressHistory.append(newStress)
            }
            .store(in: &cancellables)
    }
 
 5. IMPLEMENT ACTIVITY LOGGING
    Add methods to log new activities:
 
    func logActivity(type: Activity.ActivityType, start: Date, end: Date) async {
        do {
            // Calculate strain for the activity
            let activityStrain = try await strainCalculator.calculateActivityStrain(
                type: type,
                duration: end.timeIntervalSince(start)
            )
            
            // Create and add activity
            let activity = Activity(
                type: type,
                startTime: start,
                endTime: end,
                strain: activityStrain,
                duration: end.timeIntervalSince(start)
            )
            
            await MainActor.run {
                self.metrics.activities.append(activity)
                self.metrics.strainScore += activityStrain
            }
        } catch {
            // Handle error
        }
    }
 
 6. EXAMPLE APP INITIALIZATION
    In your main app file:
 
    @main
    struct StrainFitnessTrackerApp: App {
        // Initialize calculators
        let healthKitManager = HealthKitManager()
        let baselineCalculator = BaselineCalculator()
        let recoveryCalculator = RecoveryCalculator()
        let strainCalculator = StrainCalculator()
        let stressCalculator = StressCalculator()
        
        var body: some Scene {
            WindowGroup {
                DashboardView()
                    .environmentObject(
                        DashboardViewModel(
                            baselineCalculator: baselineCalculator,
                            recoveryCalculator: recoveryCalculator,
                            strainCalculator: strainCalculator,
                            stressCalculator: stressCalculator,
                            healthKitManager: healthKitManager
                        )
                    )
            }
        }
    }
 
 */
