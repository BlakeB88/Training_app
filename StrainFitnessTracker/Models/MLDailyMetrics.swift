//
//  MLDailyMetrics.swift
//  StrainFitnessTracker
//
//  ML-optimized daily metrics with rolling features
//

import Foundation

/// Enhanced daily metrics specifically designed for ML model training
struct MLDailyMetrics: Codable, Identifiable {
    let id: UUID
    let date: Date
    
    // MARK: - Target Variable
    /// Tomorrow's recovery score (this is what we're predicting)
    var tomorrowRecovery: Double?
    
    // MARK: - Today's Base Metrics
    var todayRecovery: Double?
    var todayStrain: Double
    
    // MARK: - Sleep Features (Primary Predictors)
    var sleepDuration: Double? // hours
    var sleepEfficiency: Double? // percentage
    var restorativeSleepPercentage: Double? // percentage
    var timeInBed: Double? // hours
    var sleepDebt: Double? // hours
    var sleepConsistency: Double? // percentage
    
    // MARK: - NEW: Circadian Features
    var bedtime: Date? // actual bedtime
    var wakeTime: Date?
    var bedtimeConsistency: Double? // variance from average bedtime
    var wakeTimeConsistency: Double? // variance from average wake time
    
    // MARK: - NEW: Multi-Night Sleep Patterns
    var sleepDurationLast3Nights: [Double]? // [tonight, -1, -2]
    var avgSleepLast7Days: Double?
    var sleepDebtLast7Days: Double?
    
    // MARK: - Physiological Features
    var hrvAverage: Double?
    var hrvDeviation: Double? // deviation from 7-day baseline
    var restingHeartRate: Double?
    var rhrDeviation: Double? // deviation from 7-day baseline
    var respiratoryRate: Double?
    var averageHeartRate: Double?
    
    // MARK: - Activity Features
    var steps: Int?
    var activeCalories: Double?
    var vo2Max: Double?
    
    // MARK: - Strain Features
    var daysSinceRestDay: Int?
    var avgStrainLast7Days: Double?
    var avgStrainLast3Days: Double?
    var cumulativeStrainLast7Days: Double?
    
    // MARK: - Stress Features
    var averageStress: Double?
    var maxStress: Double?
    var timeInHighStress: Double? // hours
    var stressReadingCount: Int?
    
    // MARK: - NEW: Nutrition Features
    var caloriesConsumed: Double?
    var calorieDeficit: Double? // consumed - burned
    var protein: Double?
    var carbohydrates: Double?
    var fat: Double?
    var waterIntake: Double? // fl oz
    var caffeine: Double? // mg
    var hoursSinceLastCaffeine: Double?
    
    // MARK: - NEW: Meal Timing Features
    var lastMealTime: Date?
    var hoursSinceLastMeal: Double?
    var dinnerToSleepHours: Double? // time between dinner and bed
    
    // MARK: - NEW: Environmental/Temporal Features
    var dayOfWeek: Int // 1=Sun, 7=Sat
    var isWeekend: Bool
    var isRestDay: Bool // no workout scheduled
    var daysInTrainingCycle: Int? // progressive number in mesocycle
    
    // MARK: - NEW: Rolling Averages (7-day)
    var avgRecoveryLast7Days: Double?
    var avgHRVLast7Days: Double?
    var avgRHRLast7Days: Double?
    var avgSleepEfficiencyLast7Days: Double?
    var avgStressLast7Days: Double?
    
    // MARK: - NEW: Recent Trends (3-day)
    var recoveryTrend3Day: Double? // slope of last 3 days
    var sleepTrend3Day: Double?
    var hrvTrend3Day: Double?
    
    // MARK: - Metadata
    var lastUpdated: Date
    
    // MARK: - Computed Properties
    
    var hasCompleteData: Bool {
        return sleepDuration != nil &&
               hrvAverage != nil &&
               restingHeartRate != nil &&
               todayRecovery != nil
    }
    
    var trainingLoad: String {
        switch todayStrain {
        case 0..<5: return "light"
        case 5..<10: return "moderate"
        case 10..<15: return "hard"
        default: return "very_hard"
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        date: Date,
        tomorrowRecovery: Double? = nil,
        todayRecovery: Double? = nil,
        todayStrain: Double = 0,
        
        // Sleep
        sleepDuration: Double? = nil,
        sleepEfficiency: Double? = nil,
        restorativeSleepPercentage: Double? = nil,
        timeInBed: Double? = nil,
        sleepDebt: Double? = nil,
        sleepConsistency: Double? = nil,
        bedtime: Date? = nil,
        wakeTime: Date? = nil,
        bedtimeConsistency: Double? = nil,
        wakeTimeConsistency: Double? = nil,
        sleepDurationLast3Nights: [Double]? = nil,
        avgSleepLast7Days: Double? = nil,
        sleepDebtLast7Days: Double? = nil,
        
        // Physiological
        hrvAverage: Double? = nil,
        hrvDeviation: Double? = nil,
        restingHeartRate: Double? = nil,
        rhrDeviation: Double? = nil,
        respiratoryRate: Double? = nil,
        averageHeartRate: Double? = nil,
        
        // Activity
        steps: Int? = nil,
        activeCalories: Double? = nil,
        vo2Max: Double? = nil,
        
        // Strain
        daysSinceRestDay: Int? = nil,
        avgStrainLast7Days: Double? = nil,
        avgStrainLast3Days: Double? = nil,
        cumulativeStrainLast7Days: Double? = nil,
        
        // Stress
        averageStress: Double? = nil,
        maxStress: Double? = nil,
        timeInHighStress: Double? = nil,
        stressReadingCount: Int? = nil,
        
        // Nutrition
        caloriesConsumed: Double? = nil,
        calorieDeficit: Double? = nil,
        protein: Double? = nil,
        carbohydrates: Double? = nil,
        fat: Double? = nil,
        waterIntake: Double? = nil,
        caffeine: Double? = nil,
        hoursSinceLastCaffeine: Double? = nil,
        lastMealTime: Date? = nil,
        hoursSinceLastMeal: Double? = nil,
        dinnerToSleepHours: Double? = nil,
        
        // Environmental
        dayOfWeek: Int? = nil,
        isWeekend: Bool = false,
        isRestDay: Bool = false,
        daysInTrainingCycle: Int? = nil,
        
        // Rolling averages
        avgRecoveryLast7Days: Double? = nil,
        avgHRVLast7Days: Double? = nil,
        avgRHRLast7Days: Double? = nil,
        avgSleepEfficiencyLast7Days: Double? = nil,
        avgStressLast7Days: Double? = nil,
        
        // Trends
        recoveryTrend3Day: Double? = nil,
        sleepTrend3Day: Double? = nil,
        hrvTrend3Day: Double? = nil,
        
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = date.startOfDay
        self.tomorrowRecovery = tomorrowRecovery
        self.todayRecovery = todayRecovery
        self.todayStrain = todayStrain
        
        // Sleep
        self.sleepDuration = sleepDuration
        self.sleepEfficiency = sleepEfficiency
        self.restorativeSleepPercentage = restorativeSleepPercentage
        self.timeInBed = timeInBed
        self.sleepDebt = sleepDebt
        self.sleepConsistency = sleepConsistency
        self.bedtime = bedtime
        self.wakeTime = wakeTime
        self.bedtimeConsistency = bedtimeConsistency
        self.wakeTimeConsistency = wakeTimeConsistency
        self.sleepDurationLast3Nights = sleepDurationLast3Nights
        self.avgSleepLast7Days = avgSleepLast7Days
        self.sleepDebtLast7Days = sleepDebtLast7Days
        
        // Physiological
        self.hrvAverage = hrvAverage
        self.hrvDeviation = hrvDeviation
        self.restingHeartRate = restingHeartRate
        self.rhrDeviation = rhrDeviation
        self.respiratoryRate = respiratoryRate
        self.averageHeartRate = averageHeartRate
        
        // Activity
        self.steps = steps
        self.activeCalories = activeCalories
        self.vo2Max = vo2Max
        
        // Strain
        self.daysSinceRestDay = daysSinceRestDay
        self.avgStrainLast7Days = avgStrainLast7Days
        self.avgStrainLast3Days = avgStrainLast3Days
        self.cumulativeStrainLast7Days = cumulativeStrainLast7Days
        
        // Stress
        self.averageStress = averageStress
        self.maxStress = maxStress
        self.timeInHighStress = timeInHighStress
        self.stressReadingCount = stressReadingCount
        
        // Nutrition
        self.caloriesConsumed = caloriesConsumed
        self.calorieDeficit = calorieDeficit
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.waterIntake = waterIntake
        self.caffeine = caffeine
        self.hoursSinceLastCaffeine = hoursSinceLastCaffeine
        self.lastMealTime = lastMealTime
        self.hoursSinceLastMeal = hoursSinceLastMeal
        self.dinnerToSleepHours = dinnerToSleepHours
        
        // Environmental
        let calendar = Calendar.current
        self.dayOfWeek = dayOfWeek ?? calendar.component(.weekday, from: date)
        self.isWeekend = isWeekend || [1, 7].contains(self.dayOfWeek)
        self.isRestDay = isRestDay
        self.daysInTrainingCycle = daysInTrainingCycle
        
        // Rolling averages
        self.avgRecoveryLast7Days = avgRecoveryLast7Days
        self.avgHRVLast7Days = avgHRVLast7Days
        self.avgRHRLast7Days = avgRHRLast7Days
        self.avgSleepEfficiencyLast7Days = avgSleepEfficiencyLast7Days
        self.avgStressLast7Days = avgStressLast7Days
        
        // Trends
        self.recoveryTrend3Day = recoveryTrend3Day
        self.sleepTrend3Day = sleepTrend3Day
        self.hrvTrend3Day = hrvTrend3Day
        
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Conversion from SimpleDailyMetrics

extension MLDailyMetrics {
    
    /// Convert SimpleDailyMetrics to MLDailyMetrics (populated with rolling features separately)
    init(from simple: SimpleDailyMetrics) {
        self.init(
            id: simple.id,
            date: simple.date,
            todayRecovery: simple.recovery,
            todayStrain: simple.strain,
            
            // Sleep
            sleepDuration: simple.sleepDuration,
            sleepEfficiency: simple.sleepEfficiency,
            restorativeSleepPercentage: simple.restorativeSleepPercentage,
            timeInBed: simple.timeInBed,
            sleepDebt: simple.sleepDebt,
            sleepConsistency: simple.sleepConsistency,
            bedtime: simple.sleepStart,
            wakeTime: simple.sleepEnd,
            sleepDurationLast3Nights: simple.recentSleepDurations,
            
            // Physiological
            hrvAverage: simple.hrvAverage,
            restingHeartRate: simple.restingHeartRate,
            respiratoryRate: simple.respiratoryRate,
            averageHeartRate: simple.averageHeartRate,
            
            // Activity
            steps: simple.steps,
            activeCalories: simple.activeCalories,
            vo2Max: simple.vo2Max,
            
            // Stress
            averageStress: simple.averageStress,
            maxStress: simple.maxStress,
            timeInHighStress: simple.timeInHighStress,
            stressReadingCount: simple.stressReadings?.count,
            
            lastUpdated: simple.lastUpdated
        )
    }
}
