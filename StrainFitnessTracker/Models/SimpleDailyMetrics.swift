//
//  SimpleDailyMetrics.swift
//  StrainFitnessTracker
//
//  Updated to include stress monitoring data and multi-night sleep tracking
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
    var timeInBed: Double? // in hours
    var sleepEfficiency: Double? // percentage (0-100)
    var restorativeSleepPercentage: Double? // percentage (0-100)
    var restorativeSleepDuration: Double? // in hours
    var sleepDebt: Double? // in hours
    var sleepConsistency: Double? // percentage (0-100)
    
    // ✅ NEW: Multi-night sleep data for enhanced recovery calculation
    var recentSleepDurations: [Double]? // Last 3-4 nights in hours
    
    // Physiological Metrics
    var hrvAverage: Double?
    var restingHeartRate: Double?
    var respiratoryRate: Double?
    var vo2Max: Double?
    
    // Activity Metrics
    var steps: Int?
    var activeCalories: Double?
    var averageHeartRate: Double?
    
    // Stress Metrics
    var averageStress: Double? // 0-3 scale
    var maxStress: Double? // 0-3 scale
    var stressReadings: [StressReading]? // Individual readings throughout the day
    var timeInHighStress: Double? // in hours
    var timeInMediumStress: Double? // in hours
    var timeInLowStress: Double? // in hours
    
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
        recentSleepDurations: [Double]? = nil,
        hrvAverage: Double? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil,
        vo2Max: Double? = nil,
        steps: Int? = nil,
        activeCalories: Double? = nil,
        averageHeartRate: Double? = nil,
        averageStress: Double? = nil,
        maxStress: Double? = nil,
        stressReadings: [StressReading]? = nil,
        timeInHighStress: Double? = nil,
        timeInMediumStress: Double? = nil,
        timeInLowStress: Double? = nil,
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
        self.recentSleepDurations = recentSleepDurations // ✅ NEW
        self.hrvAverage = hrvAverage
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.vo2Max = vo2Max
        self.steps = steps
        self.activeCalories = activeCalories
        self.averageHeartRate = averageHeartRate
        self.averageStress = averageStress
        self.maxStress = maxStress
        self.stressReadings = stressReadings
        self.timeInHighStress = timeInHighStress
        self.timeInMediumStress = timeInMediumStress
        self.timeInLowStress = timeInLowStress
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
            recentSleepDurations: self.recentSleepDurations, // ✅ NEW
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            respiratoryRate: self.respiratoryRate,
            vo2Max: self.vo2Max,
            steps: self.steps,
            activeCalories: self.activeCalories,
            averageHeartRate: self.averageHeartRate,
            averageStress: self.averageStress,
            maxStress: self.maxStress,
            stressReadings: self.stressReadings,
            timeInHighStress: self.timeInHighStress,
            timeInMediumStress: self.timeInMediumStress,
            timeInLowStress: self.timeInLowStress,
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
            recentSleepDurations: self.recentSleepDurations, // ✅ NEW
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            respiratoryRate: self.respiratoryRate,
            vo2Max: self.vo2Max,
            steps: self.steps,
            activeCalories: self.activeCalories,
            averageHeartRate: self.averageHeartRate,
            averageStress: self.averageStress,
            maxStress: self.maxStress,
            stressReadings: self.stressReadings,
            timeInHighStress: self.timeInHighStress,
            timeInMediumStress: self.timeInMediumStress,
            timeInLowStress: self.timeInLowStress,
            baselineMetrics: self.baselineMetrics,
            lastUpdated: Date()
        )
    }
    
    /// Update with new stress data
    func withUpdatedStress(
        average: Double,
        max: Double,
        readings: [StressReading],
        timeInHigh: Double,
        timeInMedium: Double,
        timeInLow: Double
    ) -> SimpleDailyMetrics {
        return SimpleDailyMetrics(
            id: self.id,
            date: self.date,
            strain: self.strain,
            recovery: self.recovery,
            recoveryComponents: self.recoveryComponents,
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
            recentSleepDurations: self.recentSleepDurations, // ✅ NEW
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            respiratoryRate: self.respiratoryRate,
            vo2Max: self.vo2Max,
            steps: self.steps,
            activeCalories: self.activeCalories,
            averageHeartRate: self.averageHeartRate,
            averageStress: average,
            maxStress: max,
            stressReadings: readings,
            timeInHighStress: timeInHigh,
            timeInMediumStress: timeInMedium,
            timeInLowStress: timeInLow,
            baselineMetrics: self.baselineMetrics,
            lastUpdated: Date()
        )
    }
}

// MARK: - StressReading Model (Simplified for Persistence)

/// Lightweight stress reading for persistence in SimpleDailyMetrics
struct StressReading: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stressLevel: Double // 0-3 scale
    let heartRate: Double
    let isExerciseRelated: Bool
    
    init(id: UUID = UUID(), timestamp: Date, stressLevel: Double, heartRate: Double, isExerciseRelated: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.stressLevel = min(max(stressLevel, 0.0), 3.0) // Clamp to 0-3
        self.heartRate = heartRate
        self.isExerciseRelated = isExerciseRelated
    }
    
    /// Convert from full StressMetrics
    init(from metrics: StressMetrics) {
        self.id = metrics.id
        self.timestamp = metrics.timestamp
        self.stressLevel = metrics.stressLevel
        self.heartRate = metrics.heartRate
        self.isExerciseRelated = metrics.isExerciseRelated
    }
}

// MARK: - Equatable
extension SimpleDailyMetrics: Equatable {
    static func == (lhs: SimpleDailyMetrics, rhs: SimpleDailyMetrics) -> Bool {
        lhs.id == rhs.id
    }
}
