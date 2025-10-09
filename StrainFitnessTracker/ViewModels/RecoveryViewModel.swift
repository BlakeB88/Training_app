//
//  RecoveryViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//  Updated: 10/9/25 - Fixed to use SimpleDailyMetrics from repository
//

import Foundation
import Combine

@MainActor
class RecoveryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedDate: Date = Date()
    @Published var dailyMetrics: SimpleDailyMetrics?
    @Published var weeklyMetrics: [SimpleDailyMetrics] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var currentRecovery: Double? {
        dailyMetrics?.recovery
    }
    
    var recoveryLevel: String? {
        guard let recovery = currentRecovery else { return nil }
        return recovery.recoveryLevel()
    }
    
    var recoveryComponents: RecoveryComponents? {
        dailyMetrics?.recoveryComponents
    }
    
    var sleepDuration: Double? {
        dailyMetrics?.sleepDuration
    }
    
    var sleepFormatted: String? {
        guard let duration = sleepDuration else { return nil }
        let hours = Int(duration)
        let minutes = Int((duration - Double(hours)) * 60)
        return String(format: "%dh %dm", hours, minutes)
    }
    
    var hrvAverage: Double? {
        dailyMetrics?.hrvAverage
    }
    
    var restingHeartRate: Double? {
        dailyMetrics?.restingHeartRate
    }
    
    var hasRecoveryData: Bool {
        dailyMetrics?.recovery != nil
    }
    
    var weeklyAverageRecovery: Double? {
        let recoveries = weeklyMetrics.compactMap { $0.recovery }
        guard !recoveries.isEmpty else { return nil }
        return recoveries.reduce(0.0, +) / Double(recoveries.count)
    }
    
    // MARK: - Dependencies
    private let repository: MetricsRepository
    
    // MARK: - Initialization
    init(repository: MetricsRepository? = nil) {
        self.repository = repository ?? MetricsRepository()
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load daily metrics
            dailyMetrics = try repository.fetchDailyMetrics(for: selectedDate)
            
            // Load weekly metrics
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: selectedDate)!
            weeklyMetrics = try repository.fetchDailyMetrics(from: weekStart, to: selectedDate)
            
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectDate(_ date: Date) async {
        selectedDate = date
        await loadData()
    }
    
    func previousDay() async {
        let previous = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        await selectDate(previous)
    }
    
    func nextDay() async {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        await selectDate(next)
    }
    
    func goToToday() async {
        await selectDate(Date())
    }
}

// MARK: - Chart Data
extension RecoveryViewModel {
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var weeklyRecoveryChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let recovery = metrics.recovery else { return nil }
            return ChartDataPoint(date: metrics.date, value: recovery)
        }
    }
    
    var weeklySleepChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let sleep = metrics.sleepDuration else { return nil }
            return ChartDataPoint(date: metrics.date, value: sleep)
        }
    }
    
    var weeklyHRVChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let hrv = metrics.hrvAverage else { return nil }
            return ChartDataPoint(date: metrics.date, value: hrv)
        }
    }
}
