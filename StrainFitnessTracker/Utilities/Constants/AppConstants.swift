//
//  AppConstants.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

struct AppConstants {
    
    // MARK: - Strain Constants
    struct Strain {
        static let minValue: Double = 0.0
        static let maxValue: Double = 21.0
        
        // Strain level thresholds
        static let lightMax: Double = 5.0
        static let moderateMax: Double = 10.0
        static let hardMax: Double = 15.0
        // 16-21 is Very Hard
        
        // Calculation constants
        static let calorieWeight: Double = 0.3
        static let baseMultiplier: Double = 3.0
    }
    
    // MARK: - Recovery Constants
    struct Recovery {
        static let minValue: Double = 0.0
        static let maxValue: Double = 100.0
        
        // Component weights
        static let hrvWeight: Double = 0.40
        static let restingHRWeight: Double = 0.30
        static let sleepWeight: Double = 0.20
        static let respiratoryRateWeight: Double = 0.10
        
        // Recovery level thresholds
        static let excellentMin: Double = 85.0
        static let goodMin: Double = 70.0
        static let fairMin: Double = 50.0
        // 0-49 is Poor
        
        // Sleep targets
        static let optimalSleepHours: Double = 8.0
        static let minimumSleepHours: Double = 6.0
    }
    
    // MARK: - ACWR Constants
    struct ACWR {
        static let acutePeriodDays: Int = 7
        static let chronicPeriodDays: Int = 28
        
        // ACWR zones
        static let undertrainingMax: Double = 0.8
        static let optimalMin: Double = 0.8
        static let optimalMax: Double = 1.3
        static let cautionMax: Double = 1.5
        // > 1.5 is High Risk
    }
    
    // MARK: - Baseline Constants
    struct Baseline {
        static let minimumDaysForBaseline: Int = 7
        static let baselinePeriodDays: Int = 7
        static let hrvVariabilityThreshold: Double = 0.15 // 15% variation
        static let rhrVariabilityThreshold: Double = 0.10 // 10% variation
    }
    
    // MARK: - Swimming Constants
    struct Swimming {
        // Stroke multipliers for strain calculation
        static let strokeMultipliers: [String: Double] = [
            "Freestyle": 1.0,
            "Backstroke": 1.1,
            "Breaststroke": 1.2,
            "Butterfly": 1.4,
            "Mixed": 1.2
        ]
        
        // Pace thresholds (seconds per 100m)
        static let easyPaceThreshold: Double = 120.0 // 2:00/100m
        static let moderatePaceThreshold: Double = 90.0 // 1:30/100m
        // < 90s is hard pace
    }
    
    // MARK: - Heart Rate Constants
    struct HeartRate {
        static let defaultMaxHR: Double = 220.0
        static let defaultRestingHR: Double = 60.0
        
        // HR zones (as percentage of max HR)
        static let zone1Max: Double = 0.60 // Recovery
        static let zone2Max: Double = 0.70 // Aerobic
        static let zone3Max: Double = 0.80 // Tempo
        static let zone4Max: Double = 0.90 // Threshold
        // > 90% is Zone 5 (VO2 Max)
    }
    
    // MARK: - Data Retention
    struct DataRetention {
        static let maximumDaysToKeep: Int = 90
        static let cleanupIntervalDays: Int = 7
    }
    
    // MARK: - Background Tasks
    struct BackgroundTasks {
        static let morningRecoveryTaskID = "com.straintracker.morningrecovery"
        static let dailyBaselineTaskID = "com.straintracker.dailybaseline"
        static let workoutProcessingTaskID = "com.straintracker.workoutprocessing"
        
        static let morningRecoveryHour: Int = 7 // 7 AM
        static let baselineUpdateHour: Int = 0 // Midnight
    }
    
    // MARK: - Notifications
    struct Notifications {
        static let recoveryReadyID = "recovery_ready"
        static let highStrainWarningID = "high_strain_warning"
        static let lowRecoveryWarningID = "low_recovery_warning"
        static let acwrWarningID = "acwr_warning"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let chartDaysDefault: Int = 7
        static let chartDaysExtended: Int = 28
        static let animationDuration: Double = 0.3
        static let ringLineWidth: CGFloat = 20.0
    }
    
    static let geminiAPIKey = "AIzaSyCPS5qp4k26TJjg6cLUMC3OgMepR4U4GCQ"
}
