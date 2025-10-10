//
//  SimpleDailyMetrics.swift
//  StrainFitnessTracker
//
//  Updated to include new health metrics
//

import Foundation

/// Simplified daily metrics model for Core Data persistence
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
    var timeInBed: Double? // NEW - in hours
    var sleepEfficiency: Double? // NEW - percentage (0-100)
    var restorativeSleepPercentage: Double? // NEW - percentage (0-100)
    var restorativeSleepDuration: Double? // NEW - in hours
    var sleepDebt: Double? // NEW - in hours
    var sleepConsistency: Double? // NEW - percentage (0-100)
    
    // Physiological Metrics
    var hrvAverage: Double?
    var restingHeartRate: Double?
    var respiratoryRate: Double? // NEW
    var vo2Max: Double? // NEW
    
    // Activity Metrics
    var steps: Int? // NEW
    var activeCalories: Double? // NEW
    var averageHeartRate: Double? // NEW
    
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
        timeInBed: Double? = nil,
        sleepEfficiency: Double? = nil,
        restorativeSleepPercentage: Double? = nil,
        restorativeSleepDuration: Double? = nil,
        sleepDebt: Double? = nil,
        sleepConsistency: Double? = nil,
        hrvAverage: Double? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil,
        vo2Max: Double? = nil,
        steps: Int? = nil,
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
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
        self.timeInBed = timeInBed
        self.sleepEfficiency = sleepEfficiency
        self.restorativeSleepPercentage = restorativeSleepPercentage
        self.restorativeSleepDuration = restorativeSleepDuration
        self.sleepDebt = sleepDebt
        self.sleepConsistency = sleepConsistency
        self.hrvAverage = hrvAverage
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.vo2Max = vo2Max
        self.steps = steps
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
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
            timeInBed: self.timeInBed,
            sleepEfficiency: self.sleepEfficiency,
            restorativeSleepPercentage: self.restorativeSleepPercentage,
            restorativeSleepDuration: self.restorativeSleepDuration,
            sleepDebt: self.sleepDebt,
            sleepConsistency: self.sleepConsistency,
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            respiratoryRate: self.respiratoryRate,
            vo2Max: self.vo2Max,
            steps: self.steps,
            activeCalories: self.activeCalories,
            averageHeartRate: self.averageHeartRate,
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
            timeInBed: self.timeInBed,
            sleepEfficiency: self.sleepEfficiency,
            restorativeSleepPercentage: self.restorativeSleepPercentage,
            restorativeSleepDuration: self.restorativeSleepDuration,
            sleepDebt: self.sleepDebt,
            sleepConsistency: self.sleepConsistency,
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            respiratoryRate: self.respiratoryRate,
            vo2Max: self.vo2Max,
            steps: self.steps,
            activeCalories: self.activeCalories,
            averageHeartRate: self.averageHeartRate,
            baselineMetrics: self.baselineMetrics,
            lastUpdated: Date()
        )
    }
}

// MARK: - Equatable
extension SimpleDailyMetrics: Equatable {
    static func == (lhs: SimpleDailyMetrics, rhs: SimpleDailyMetrics) -> Bool {
        lhs.id == rhs.id
    }
}
