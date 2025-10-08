//
//  WorkoutHistoryViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import Combine
import HealthKit

@MainActor
class WorkoutHistoryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var workouts: [WorkoutSummary] = []
    @Published var filteredWorkouts: [WorkoutSummary] = []
    @Published var selectedWorkoutType: HKWorkoutActivityType?
    @Published var dateRange: DateRange = .week
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Computed Properties
    var totalWorkouts: Int {
        filteredWorkouts.count
    }
    
    var totalStrain: Double {
        filteredWorkouts.reduce(0.0) { $0 + $1.strain }
    }
    
    var totalCalories: Double {
        filteredWorkouts.reduce(0.0) { $0 + $1.calories }
    }
    
    var totalDistance: Double? {
        let distances = filteredWorkouts.compactMap { $0.distance }
        guard !distances.isEmpty else { return nil }
        return distances.reduce(0.0, +)
    }
    
    var totalDuration: TimeInterval {
        filteredWorkouts.reduce(0.0) { $0 + $1.duration }
    }
    
    var averageStrain: Double? {
        guard !filteredWorkouts.isEmpty else { return nil }
        return totalStrain / Double(filteredWorkouts.count)
    }
    
    var workoutTypes: [HKWorkoutActivityType] {
        Array(Set(workouts.map { $0.workoutType })).sorted { $0.name < $1.name }
    }
    
    var workoutBreakdown: [(type: String, count: Int, totalStrain: Double)] {
        let grouped = Dictionary(grouping: filteredWorkouts) { $0.workoutType }
        return grouped.map { type, workouts in
            let totalStrain = workouts.reduce(0.0) { $0 + $1.strain }
            return (type.name, workouts.count, totalStrain)
        }.sorted { $0.totalStrain > $1.totalStrain }
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
            let (startDate, endDate) = dateRange.dateInterval
            workouts = try repository.fetchWorkouts(from: startDate, to: endDate)
            applyFilters()
        } catch {
            errorMessage = "Failed to load workouts: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectWorkoutType(_ type: HKWorkoutActivityType?) {
        selectedWorkoutType = type
        applyFilters()
    }
    
    func selectDateRange(_ range: DateRange) async {
        dateRange = range
        await loadData()
    }
    
    func clearFilters() {
        selectedWorkoutType = nil
        applyFilters()
    }
    
    // MARK: - Private Methods
    
    private func applyFilters() {
        if let type = selectedWorkoutType {
            filteredWorkouts = workouts.filter { $0.workoutType == type }
        } else {
            filteredWorkouts = workouts
        }
    }
}

// MARK: - Date Range
extension WorkoutHistoryViewModel {
    
    enum DateRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case threeMonths = "3 Months"
        case year = "Year"
        case all = "All Time"
        
        var dateInterval: (start: Date, end: Date) {
            let end = Date()
            let start: Date
            
            switch self {
            case .week:
                start = Calendar.current.date(byAdding: .day, value: -7, to: end)!
            case .month:
                start = Calendar.current.date(byAdding: .month, value: -1, to: end)!
            case .threeMonths:
                start = Calendar.current.date(byAdding: .month, value: -3, to: end)!
            case .year:
                start = Calendar.current.date(byAdding: .year, value: -1, to: end)!
            case .all:
                start = Calendar.current.date(byAdding: .year, value: -10, to: end)!
            }
            
            return (start, end)
        }
    }
}

// MARK: - Grouped Workouts
extension WorkoutHistoryViewModel {
    
    struct WorkoutGroup: Identifiable {
        let id = UUID()
        let date: Date
        let workouts: [WorkoutSummary]
        
        var totalStrain: Double {
            workouts.reduce(0.0) { $0 + $1.strain }
        }
    }
    
    var groupedByDate: [WorkoutGroup] {
        let grouped = Dictionary(grouping: filteredWorkouts) { $0.startDate.startOfDay }
        return grouped.map { WorkoutGroup(date: $0.key, workouts: $0.value) }
            .sorted { $0.date > $1.date }
    }
}
