//
//  DailyMetricsEntity+CoreDataProperties.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/10/25.
//
//

public import Foundation
public import CoreData


public typealias DailyMetricsEntityCoreDataPropertiesSet = NSSet

extension DailyMetricsEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DailyMetricsEntity> {
        return NSFetchRequest<DailyMetricsEntity>(entityName: "DailyMetricsEntity")
    }

    @NSManaged public var date: Date?
    @NSManaged public var hrvAverage: Double
    @NSManaged public var id: UUID?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var recovery: Double
    @NSManaged public var restingHeartRate: Double
    @NSManaged public var sleepDuration: Double
    @NSManaged public var sleepEnd: Date?
    @NSManaged public var sleepStart: Date?
    @NSManaged public var strain: Double
    @NSManaged public var baselineData: Data?
    @NSManaged public var recoveryComponentsData: Data?
    @NSManaged public var respiratoryRate: Double
    @NSManaged public var timeInBed: Double
    @NSManaged public var sleepEfficiency: Double
    @NSManaged public var restorativeSleepPercentage: Double
    @NSManaged public var sleepDebt: Double
    @NSManaged public var sleepConsistency: Double
    @NSManaged public var vo2Max: Double
    @NSManaged public var steps: Int32
    @NSManaged public var activeCalories: Double
    @NSManaged public var averageHeartRate: Double
    @NSManaged public var averageStress: Double
    @NSManaged public var maxStress: Double
    @NSManaged public var stressReadingsData: Data?
    @NSManaged public var timeInHighStress: Double
    @NSManaged public var timeInMediumStress: Double
    @NSManaged public var timeInLowStress: Double
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
