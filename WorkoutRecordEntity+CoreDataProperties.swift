//
//  WorkoutRecordEntity+CoreDataProperties.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//
//

public import Foundation

public typealias WorkoutRecordEntityCoreDataPropertiesSet = NSSet

extension WorkoutRecordEntity {

    @NSManaged public var averageHeartRate: Double
    @NSManaged public var calories: Double
    @NSManaged public var distance: Double
    @NSManaged public var duration: Double
    @NSManaged public var endDate: Date?
    @NSManaged public var heartRateIntensity: Double
    @NSManaged public var id: UUID?
    @NSManaged public var lapCount: Int32
    @NSManaged public var maxHeartRate: Double
    @NSManaged public var startDate: Date?
    @NSManaged public var strain: Double
    @NSManaged public var swimmingStrokeStyleRawValue: Int32
    @NSManaged public var workoutTypeRawValue: Int64
    @NSManaged public var dailyMetrics: DailyMetricsEntity?

}

extension WorkoutRecordEntity : Identifiable {

}
