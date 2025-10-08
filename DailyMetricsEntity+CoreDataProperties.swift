//
//  DailyMetricsEntity+CoreDataProperties.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//
//

public import Foundation

public typealias DailyMetricsEntityCoreDataPropertiesSet = NSSet

extension DailyMetricsEntity {


    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var strain: Double
    @NSManaged public var recovery: Double
    @NSManaged public var sleepDuration: Double
    @NSManaged public var sleepStart: Date?
    @NSManaged public var sleepEnd: Date?
    @NSManaged public var hrvAverage: Double
    @NSManaged public var restingHeartRate: Double
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var workouts: NSSet?

}

// MARK: Generated accessors for workouts
extension DailyMetricsEntity {

    @objc(addWorkoutsObject:)
    @NSManaged public func addToWorkouts(_ value: WorkoutRecordEntity)

    @objc(removeWorkoutsObject:)
    @NSManaged public func removeFromWorkouts(_ value: WorkoutRecordEntity)

    @objc(addWorkouts:)
    @NSManaged public func addToWorkouts(_ values: NSSet)

    @objc(removeWorkouts:)
    @NSManaged public func removeFromWorkouts(_ values: NSSet)

}

extension DailyMetricsEntity : Identifiable {

}
