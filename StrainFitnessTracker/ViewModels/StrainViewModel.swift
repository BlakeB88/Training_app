//
//  StrainViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import Combine
import HealthKit

@MainActor
class StrainViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedDate: Date = Date()
    @Published var dailyMetrics: DailyMetrics?
    @Published var weeklyMetrics: [DailyMetrics] = []
    @Published var monthlyMetrics: [DailyMetrics] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var currentStrain: Double {
        dailyMetrics?.strain ?? 0
    }
    
    var strainLevel: String {
        dailyMetrics?.strainLevel ?? "No Data"
    }
    
    var workouts: [WorkoutSummary] {
        dailyMetrics?.workouts ?? []
    }
    
    var workoutBreakdown: [(type: String, count: Int, totalStrain: Double)] {
        dailyMetrics?.workoutBreakdown() ?? []
    }
    
    var weeklyAverageStrain: Double? {
        guard !weeklyMetrics.isEmpty else { return nil }
        return weeklyMetrics.reduce(0.0) { $0 + $1.strain } / Double(weeklyMetrics.count)
    }
    
    var monthlyAverageStrain: Double? {
        guard !monthlyMetrics.isEmpty else { return nil }
        return monthlyMetrics.reduce(0.0) { $0 + $1.strain } / Double(monthlyMetrics.count)
    }
    
    var acwr: Double? {
        dailyMetrics?.acwr
    }
    
    var acwrStatus: ACWRStatus? {
        dailyMetrics?.acwrStatus
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
            
            // Load weekly metrics (7 days)
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: selectedDate)!
            weeklyMetrics = try repository.fetchDailyMetrics(from: weekStart, to: selectedDate)
            
            // Load monthly metrics (28 days)
            let monthStart = Calendar.current.date(byAdding: .day, value: -27, to: selectedDate)!
            monthlyMetrics = try repository.fetchDailyMetrics(from: monthStart, to: selectedDate)
            
            // Calculate baseline if we have enough data
            if let metrics = dailyMetrics, monthlyMetrics.count >= 7 {
                if let baseline = BaselineCalculator.calculateBaselines(
                    from: monthlyMetrics,
                    forDate: selectedDate
                ) {
                    let updatedMetrics = metrics.withUpdatedBaseline(baseline)
                    try repository.saveDailyMetrics(updatedMetrics)
                    dailyMetrics = updatedMetrics
                }
            }
            
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
extension StrainViewModel {
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var weeklyChartData: [ChartDataPoint] {
        weeklyMetrics.map { ChartDataPoint(date: $0.date, value: $0.strain) }
    }
    
    var monthlyChartData: [ChartDataPoint] {
        monthlyMetrics.map { ChartDataPoint(date: $0.date, value: $0.strain) }
    }
}


