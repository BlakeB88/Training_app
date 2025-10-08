//
//  DailyMetrics.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

/// Represents all metrics for a single day
struct DailyMetrics {
    
    // MARK: - Identification
    let id: UUID
    let date: Date
    
    // MARK: - Primary Metrics
    let strain: Double
    let recovery: Double?
    
    // MARK: - Recovery Components
    let recoveryComponents: RecoveryComponents?
    
    // MARK: - Workouts
    let workouts: [WorkoutSummary]
    
    // MARK: - Sleep Data
    let sleepDuration: Double? // in hours
    let sleepStart: Date?
    let sleepEnd: Date?
    
    // MARK: - Heart Rate Data
    let hrvAverage: Double?
    let restingHeartRate: Double?
    
    // MARK: - Baseline Comparison
    let baselineMetrics: BaselineMetrics?
    
    // MARK: - Metadata
    let lastUpdated: Date
    
    // MARK: - Computed Properties
    
    var dateFormatted: String {
        return date.formattedRelative()
    }
    
    var strainFormatted: String {
        return strain.formattedStrain()
    }
    
    var strainLevel: String {
        return strain.strainLevel()
    }
    
    var recoveryFormatted: String? {
        guard let rec = recovery else { return nil }
        return rec.formattedRecovery()
    }
    
    var recoveryLevel: String? {
        guard let rec = recovery else { return nil }
        return rec.recoveryLevel()
    }
    
    var workoutCount: Int {
        return workouts.count
    }
    
    var totalWorkoutDuration: TimeInterval {
        return workouts.reduce(0) { $0 + $1.duration }
    }
    
    var totalCalories: Double {
        return workouts.reduce(0) { $0 + $1.calories }
    }
    
    var totalDistance: Double? {
        let distances = workouts.compactMap { $0.distance }
        guard !distances.isEmpty else { return nil }
        return distances.reduce(0, +)
    }
    
    var hasRecoveryData: Bool {
        return recovery != nil
    }
    
    var hasWorkouts: Bool {
        return !workouts.isEmpty
    }
    
    var isComplete: Bool {
        return hasWorkouts && hasRecoveryData
    }
    
    var acwr: Double? {
        return baselineMetrics?.acwr
    }
    
    var acwrFormatted: String? {
        guard let ratio = acwr else { return nil }
        return ratio.formattedACWR()
    }
    
    var acwrStatus: ACWRStatus? {
        return baselineMetrics?.acwrStatus()
    }
    
    // MARK: - Initialization
    init(
        id: UUID = UUID(),
        date: Date,
        strain: Double,
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
    
    /// Get workouts by type
    func workouts(ofType type: HKWorkoutActivityType) -> [WorkoutSummary] {
        return workouts.filter { $0.workoutType == type }
    }
    
    /// Get swimming workouts
    var swimmingWorkouts: [WorkoutSummary] {
        return workouts(ofType: .swimming)
    }
    
    /// Get workout breakdown by type
    func workoutBreakdown() -> [(type: String, count: Int, totalStrain: Double)] {
        let grouped = Dictionary(grouping: workouts) { $0.workoutType }
        return grouped.map { type, workouts in
            let totalStrain = workouts.reduce(0) { $0 + $1.strain }
            return (type.name, workouts.count, totalStrain)
        }.sorted { $0.totalStrain > $1.totalStrain }
    }
    
    /// Create a copy with updated recovery
    func withUpdatedRecovery(_ recovery: Double, components: RecoveryComponents) -> DailyMetrics {
        return DailyMetrics(
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
    
    /// Create a copy with updated baseline
    func withUpdatedBaseline(_ baseline: BaselineMetrics) -> DailyMetrics {
        return DailyMetrics(
            id: self.id,
            date: self.date,
            strain: self.strain,
            recovery: self.recovery,
            recoveryComponents: self.recoveryComponents,
            workouts: self.workouts,
            sleepDuration: self.sleepDuration,
            sleepStart: self.sleepStart,
            sleepEnd: self.sleepEnd,
            hrvAverage: self.hrvAverage,
            restingHeartRate: self.restingHeartRate,
            baselineMetrics: baseline,
            lastUpdated: Date()
        )
    }
}

// MARK: - Codable Conformance
extension DailyMetrics: Codable {}

// MARK: - Identifiable Conformance
extension DailyMetrics: Identifiable {}

// MARK: - Equatable Conformance
extension DailyMetrics: Equatable {}

// MARK: - Comparable Conformance (for sorting by date)
extension DailyMetrics: Comparable {
    static func < (lhs: DailyMetrics, rhs: DailyMetrics) -> Bool {
        return lhs.date < rhs.date
    }
}
