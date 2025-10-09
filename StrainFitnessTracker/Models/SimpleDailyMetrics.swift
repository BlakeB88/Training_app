//
//  SimpleDailyMetrics.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/9/25.
//  Simple model for persistence layer (different from dashboard DailyMetrics)
//

import Foundation

/// Simplified daily metrics model for Core Data persistence
/// This is separate from the dashboard DailyMetrics model
struct SimpleDailyMetrics: Identifiable, Codable {
    let id: UUID
    let date: Date
    
    // Strain & Recovery
    var strain: Double
    var recovery: Double?
    var recoveryComponents: RecoveryComponents?
    
    // Workouts
    var workouts: [WorkoutSummary]
    
    // Sleep Data
    var sleepDuration: Double? // in hours
    var sleepStart: Date?
    var sleepEnd: Date?
    
    // Physiological Metrics
    var hrvAverage: Double?
    var restingHeartRate: Double?
    
    // Baseline
    var baselineMetrics: BaselineMetrics?
    
    // Metadata
    var lastUpdated: Date
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date,
        strain: Double = 0.0,
        recovery: Double? = nil,
        recoveryComponents: RecoveryComponents? = nil,
        workouts: [WorkoutSummary] = [],
        sleepDuration: Double? = nil,
        sleepStart: Date? = nil,
        sleepEnd: Date? = nil,
        hrvAverage: Double? = nil,
        restingHeartRate: Double? = nil,
        baselineMetrics: BaselineMetrics? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = date.startOfDay
        self.strain = strain
        self.recovery = recovery
        self.recoveryComponents = recoveryComponents
        self.workouts = workouts
        self.sleepDuration = sleepDuration
        self.sleepStart = sleepStart
        self.sleepEnd = sleepEnd
        self.hrvAverage = hrvAverage
        self.restingHeartRate = restingHeartRate
        self.baselineMetrics = baselineMetrics
        self.lastUpdated = lastUpdated
    }
    
    // MARK: - Helper Methods
    
    /// Update with new recovery data
    func withUpdatedRecovery(_ recovery: Double, components: RecoveryComponents) -> SimpleDailyMetrics {
        return SimpleDailyMetrics(
            id: self.id,
            date: self.date,
            strain: self.strain,
            recovery: recovery,
            recoveryComponents: components,
            workouts: self.workouts,
            sleepDuration: self.sleepDuration,
            sleepStart: self.sleepStart,
            sleepEnd: self.sleepEnd,
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            baselineMetrics: self.baselineMetrics,
            lastUpdated: Date()
        )
    }
    
    /// Update with new strain data
    func withUpdatedStrain(_ strain: Double, workouts: [WorkoutSummary]) -> SimpleDailyMetrics {
        return SimpleDailyMetrics(
            id: self.id,
            date: self.date,
            strain: strain,
            recovery: self.recovery,
            recoveryComponents: self.recoveryComponents,
            workouts: workouts,
            sleepDuration: self.sleepDuration,
            sleepStart: self.sleepStart,
            sleepEnd: self.sleepEnd,
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            baselineMetrics: self.baselineMetrics,
            lastUpdated: Date()
        )
    }
    
    /// Convert to dashboard DailyMetrics (if needed)
    func toDashboardMetrics() -> DailyMetrics {
        // This would convert to the full dashboard model
        // You'll need to implement this based on your needs
        fatalError("Not yet implemented - add conversion logic as needed")
    }
}

// MARK: - Equatable
extension SimpleDailyMetrics: Equatable {
    static func == (lhs: SimpleDailyMetrics, rhs: SimpleDailyMetrics) -> Bool {
        lhs.id == rhs.id
    }
}
