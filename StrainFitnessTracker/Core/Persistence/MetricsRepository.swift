//
//  MetricsRepository.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//  Updated: 10/9/25 - Updated to use SimpleDailyMetrics
//

import Foundation
import CoreData
import HealthKit

/// Repository for managing DailyMetrics and WorkoutRecord persistence
class MetricsRepository {
    
    // MARK: - Properties
    private let coreDataStack: CoreDataStack
    
    // MARK: - Initialization
    init(coreDataStack: CoreDataStack = .shared) {
        self.coreDataStack = coreDataStack
    }
    
    // MARK: - Daily Metrics Operations
    
    /// Save or update daily metrics
    func saveDailyMetrics(_ metrics: SimpleDailyMetrics) throws {
        let context = coreDataStack.viewContext
        
        // Check if entity already exists
        let fetchRequest = NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
        fetchRequest.predicate = NSPredicate(format: "date == %@", metrics.date.startOfDay as NSDate)
        
        let entity: DailyMetricsEntity
        if let existing = try context.fetch(fetchRequest).first {
            entity = existing
        } else {
            entity = DailyMetricsEntity(context: context)
            entity.id = metrics.id
            entity.date = metrics.date.startOfDay
        }
        
        // Update properties
        entity.strain = metrics.strain
        entity.recovery = metrics.recovery ?? 0
        entity.sleepDuration = metrics.sleepDuration ?? 0
        entity.sleepStart = metrics.sleepStart ?? metrics.date
        entity.sleepEnd = metrics.sleepEnd
        entity.hrvAverage = metrics.hrvAverage ?? 0
        entity.restingHeartRate = metrics.restingHeartRate ?? 0
        entity.lastUpdated = metrics.lastUpdated
        
        // Delete existing workouts and recreate
        if let existingWorkouts = entity.workouts as? Set<WorkoutRecordEntity> {
            existingWorkouts.forEach { context.delete($0) }
        }
        
        // Add workouts
        for workout in metrics.workouts {
            let workoutEntity = WorkoutRecordEntity(context: context)
            workoutEntity.id = workout.id
            workoutEntity.workoutTypeRawValue = Int64(workout.workoutType.rawValue)
            workoutEntity.startDate = workout.startDate
            workoutEntity.endDate = workout.endDate
            workoutEntity.duration = workout.duration
            workoutEntity.distance = workout.distance ?? 0
            workoutEntity.calories = workout.calories
            workoutEntity.averageHeartRate = workout.averageHeartRate ?? 0
            workoutEntity.maxHeartRate = workout.maxHeartRate ?? 0
            workoutEntity.strain = workout.strain
            workoutEntity.heartRateIntensity = workout.heartRateIntensity ?? 0
            
            if let strokeStyle = workout.swimmingStrokeStyle {
                workoutEntity.swimmingStrokeStyleRawValue = Int32(strokeStyle.rawValue)
            }
            if let lapCount = workout.lapCount {
                workoutEntity.lapCount = Int32(lapCount)
            }
            
            workoutEntity.dailyMetrics = entity
        }
        
        coreDataStack.saveContext()
    }
    
    /// Fetch daily metrics for a specific date
    func fetchDailyMetrics(for date: Date) throws -> SimpleDailyMetrics? {
        let context = coreDataStack.viewContext
        let fetchRequest = NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
        fetchRequest.predicate = NSPredicate(format: "date == %@", date.startOfDay as NSDate)
        
        guard let entity = try context.fetch(fetchRequest).first else {
            return nil
        }
        
        return convertToSimpleDailyMetrics(entity)
    }
    
    /// Fetch daily metrics for a date range
    func fetchDailyMetrics(from startDate: Date, to endDate: Date) throws -> [SimpleDailyMetrics] {
        let context = coreDataStack.viewContext
        let fetchRequest = NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
        fetchRequest.predicate = NSPredicate(
            format: "date >= %@ AND date <= %@",
            startDate.startOfDay as NSDate,
            endDate.startOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { convertToSimpleDailyMetrics($0) }
    }
    
    /// Fetch all daily metrics
    func fetchAllDailyMetrics() throws -> [SimpleDailyMetrics] {
        let context = coreDataStack.viewContext
        let fetchRequest = NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        
        let entities = try context.fetch(fetchRequest)
        return entities.compactMap { convertToSimpleDailyMetrics($0) }
    }
    
    /// Fetch recent daily metrics (last N days)
    func fetchRecentDailyMetrics(days: Int) throws -> [SimpleDailyMetrics] {
        let endDate = Date().startOfDay
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate)!
        return try fetchDailyMetrics(from: startDate, to: endDate)
    }
    
    /// Delete daily metrics for a specific date
    func deleteDailyMetrics(for date: Date) throws {
        let context = coreDataStack.viewContext
        let fetchRequest = NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
        fetchRequest.predicate = NSPredicate(format: "date == %@", date.startOfDay as NSDate)
        
        if let entity = try context.fetch(fetchRequest).first {
            context.delete(entity)
            coreDataStack.saveContext()
        }
    }
    
    /// Delete all daily metrics
    func deleteAllDailyMetrics() throws {
        try coreDataStack.deleteAllData()
    }
    
    // MARK: - Workout Operations
    
    /// Fetch workouts for a specific date
    func fetchWorkouts(for date: Date) throws -> [WorkoutSummary] {
        guard let dailyMetrics = try fetchDailyMetrics(for: date) else {
            return []
        }
        return dailyMetrics.workouts
    }
    
    /// Fetch workouts for a date range
    func fetchWorkouts(from startDate: Date, to endDate: Date) throws -> [WorkoutSummary] {
        let dailyMetrics = try fetchDailyMetrics(from: startDate, to: endDate)
        return dailyMetrics.flatMap { $0.workouts }
    }
    
    /// Fetch workouts by type
    func fetchWorkouts(ofType type: HKWorkoutActivityType, from startDate: Date, to endDate: Date) throws -> [WorkoutSummary] {
        let workouts = try fetchWorkouts(from: startDate, to: endDate)
        return workouts.filter { $0.workoutType == type }
    }
    
    // MARK: - Statistics Operations
    
    /// Calculate average strain over a period
    func calculateAverageStrain(from startDate: Date, to endDate: Date) throws -> Double? {
        let metrics = try fetchDailyMetrics(from: startDate, to: endDate)
        guard !metrics.isEmpty else { return nil }
        
        let totalStrain = metrics.reduce(0.0) { $0 + $1.strain }
        return totalStrain / Double(metrics.count)
    }
    
    /// Calculate average recovery over a period
    func calculateAverageRecovery(from startDate: Date, to endDate: Date) throws -> Double? {
        let metrics = try fetchDailyMetrics(from: startDate, to: endDate)
        let metricsWithRecovery = metrics.compactMap { $0.recovery }
        guard !metricsWithRecovery.isEmpty else { return nil }
        
        let totalRecovery = metricsWithRecovery.reduce(0.0, +)
        return totalRecovery / Double(metricsWithRecovery.count)
    }
    
    /// Get total workout count for a period
    func getTotalWorkoutCount(from startDate: Date, to endDate: Date) throws -> Int {
        let workouts = try fetchWorkouts(from: startDate, to: endDate)
        return workouts.count
    }
    
    /// Get total calories burned for a period
    func getTotalCalories(from startDate: Date, to endDate: Date) throws -> Double {
        let workouts = try fetchWorkouts(from: startDate, to: endDate)
        return workouts.reduce(0.0) { $0 + $1.calories }
    }
    
    /// Get total distance for a period
    func getTotalDistance(from startDate: Date, to endDate: Date) throws -> Double {
        let workouts = try fetchWorkouts(from: startDate, to: endDate)
        return workouts.compactMap { $0.distance }.reduce(0.0, +)
    }
    
    /// Get workout breakdown by type
    func getWorkoutBreakdown(from startDate: Date, to endDate: Date) throws -> [(type: String, count: Int, totalStrain: Double)] {
        let workouts = try fetchWorkouts(from: startDate, to: endDate)
        let grouped = Dictionary(grouping: workouts) { $0.workoutType }
        
        return grouped.map { type, workouts in
            let totalStrain = workouts.reduce(0.0) { $0 + $1.strain }
            return (type.name, workouts.count, totalStrain)
        }.sorted { $0.totalStrain > $1.totalStrain }
    }
    
    // MARK: - Batch Operations
    
    /// Save multiple daily metrics
    func saveDailyMetrics(_ metricsArray: [SimpleDailyMetrics]) throws {
        for metrics in metricsArray {
            try saveDailyMetrics(metrics)
        }
    }
    
    /// Update strain for a specific date
    func updateStrain(_ strain: Double, for date: Date) throws {
        guard let metrics = try fetchDailyMetrics(for: date) else {
            throw RepositoryError.metricsNotFound
        }
        
        let updatedMetrics = SimpleDailyMetrics(
            id: metrics.id,
            date: metrics.date,
            strain: strain,
            recovery: metrics.recovery,
            recoveryComponents: metrics.recoveryComponents,
            workouts: metrics.workouts,
            sleepDuration: metrics.sleepDuration,
            sleepStart: metrics.sleepStart,
            sleepEnd: metrics.sleepEnd,
            hrvAverage: metrics.hrvAverage,
            restingHeartRate: metrics.restingHeartRate,
            baselineMetrics: metrics.baselineMetrics,
            lastUpdated: Date()
        )
        
        try saveDailyMetrics(updatedMetrics)
    }
    
    /// Update recovery for a specific date
    func updateRecovery(_ recovery: Double, components: RecoveryComponents, for date: Date) throws {
        guard let metrics = try fetchDailyMetrics(for: date) else {
            throw RepositoryError.metricsNotFound
        }
        
        let updatedMetrics = metrics.withUpdatedRecovery(recovery, components: components)
        try saveDailyMetrics(updatedMetrics)
    }
    
    // MARK: - Helper Methods
    
    private func convertToSimpleDailyMetrics(_ entity: DailyMetricsEntity) -> SimpleDailyMetrics? {
        guard let id = entity.id, let date = entity.date else {
            return nil
        }
        
        // Convert workouts
        let workoutEntities = (entity.workouts as? Set<WorkoutRecordEntity>) ?? []
        let workouts = workoutEntities.compactMap { convertToWorkoutSummary($0) }
            .sorted { $0.startDate < $1.startDate }
        
        return SimpleDailyMetrics(
            id: id,
            date: date,
            strain: entity.strain,
            recovery: entity.recovery > 0 ? entity.recovery : nil,
            recoveryComponents: nil, // Not stored in Core Data
            workouts: workouts,
            sleepDuration: entity.sleepDuration > 0 ? entity.sleepDuration : nil,
            sleepStart: entity.sleepStart,
            sleepEnd: entity.sleepEnd,
            hrvAverage: entity.hrvAverage > 0 ? entity.hrvAverage : nil,
            restingHeartRate: entity.restingHeartRate > 0 ? entity.restingHeartRate : nil,
            baselineMetrics: nil, // Not stored in Core Data
            lastUpdated: entity.lastUpdated ?? Date()
        )
    }
    
    private func convertToWorkoutSummary(_ entity: WorkoutRecordEntity) -> WorkoutSummary? {
        guard let id = entity.id,
              let startDate = entity.startDate,
              let endDate = entity.endDate else {
            return nil
        }
        
        let workoutType = HKWorkoutActivityType(rawValue: UInt(entity.workoutTypeRawValue)) ?? .other
        
        var swimmingStroke: HKSwimmingStrokeStyle?
        if entity.swimmingStrokeStyleRawValue > 0 {
            swimmingStroke = HKSwimmingStrokeStyle(rawValue: Int(entity.swimmingStrokeStyleRawValue))
        }
        
        return WorkoutSummary(
            id: id,
            workoutType: workoutType,
            startDate: startDate,
            endDate: endDate,
            duration: entity.duration,
            distance: entity.distance > 0 ? entity.distance : nil,
            calories: entity.calories,
            averageHeartRate: entity.averageHeartRate > 0 ? entity.averageHeartRate : nil,
            maxHeartRate: entity.maxHeartRate > 0 ? entity.maxHeartRate : nil,
            swimmingStrokeStyle: swimmingStroke,
            lapCount: entity.lapCount > 0 ? Int(entity.lapCount) : nil,
            strain: entity.strain,
            heartRateIntensity: entity.heartRateIntensity > 0 ? entity.heartRateIntensity : nil
        )
    }
}

// MARK: - Repository Error
enum RepositoryError: Error {
    case metricsNotFound
    case invalidData
    case saveFailed
    
    var localizedDescription: String {
        switch self {
        case .metricsNotFound:
            return "Daily metrics not found for the specified date"
        case .invalidData:
            return "Invalid data provided"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}

// MARK: - Async/Await Support
extension MetricsRepository {
    
    /// Async version of saveDailyMetrics
    func saveDailyMetricsAsync(_ metrics: SimpleDailyMetrics) async throws {
        try await withCheckedThrowingContinuation { continuation in
            coreDataStack.performBackgroundTask { _ in
                do {
                    try self.saveDailyMetrics(metrics)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Async version of fetchDailyMetrics
    func fetchDailyMetricsAsync(for date: Date) async throws -> SimpleDailyMetrics? {
        try await withCheckedThrowingContinuation { continuation in
            coreDataStack.performBackgroundTask { _ in
                do {
                    let metrics = try self.fetchDailyMetrics(for: date)
                    continuation.resume(returning: metrics)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
