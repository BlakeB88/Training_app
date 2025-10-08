//
//  RecoveryCalculator.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import HealthKit

struct RecoveryCalculator {
    
    static func calculateRecoveryScore(
        hrvCurrent: Double?,
        hrvBaseline: Double?,
        rhrCurrent: Double?,
        rhrBaseline: Double?,
        sleepDuration: Double,
        respiratoryRate: Double? = nil
    ) -> Double {
        var totalScore = 0.0
        var totalWeight = 0.0
        
        // HRV Score (40% weight)
        if let current = hrvCurrent, let baseline = hrvBaseline, baseline > 0 {
            let hrvScore = calculateHRVScore(current: current, baseline: baseline)
            totalScore += hrvScore * 0.4
            totalWeight += 0.4
        }
        
        // Resting HR Score (30% weight)
        if let current = rhrCurrent, let baseline = rhrBaseline, baseline > 0 {
            let rhrScore = calculateRHRScore(current: current, baseline: baseline)
            totalScore += rhrScore * 0.3
            totalWeight += 0.3
        }
        
        // Sleep Score (20% weight)
        let sleepScore = calculateSleepScore(duration: sleepDuration)
        totalScore += sleepScore * 0.2
        totalWeight += 0.2
        
        // Respiratory Rate Score (10% weight)
        if let respRate = respiratoryRate {
            let respScore = calculateRespiratoryScore(rate: respRate)
            totalScore += respScore * 0.1
            totalWeight += 0.1
        }
        
        guard totalWeight > 0 else { return 50.0 }
        
        return (totalScore / totalWeight) * 100.0
    }
    
    private static func calculateHRVScore(current: Double, baseline: Double) -> Double {
        let percentChange = ((current - baseline) / baseline) * 100.0
        
        switch percentChange {
        case 10...:
            return 1.0
        case 5..<10:
            return 0.9
        case -5..<5:
            return 0.75
        case -10..<(-5):
            return 0.6
        case -20..<(-10):
            return 0.4
        default:
            return 0.2
        }
    }
    
    private static func calculateRHRScore(current: Double, baseline: Double) -> Double {
        let percentChange = ((current - baseline) / baseline) * 100.0
        
        switch percentChange {
        case ...(-5):
            return 1.0
        case -5..<(-2):
            return 0.9
        case -2..<2:
            return 0.75
        case 2..<5:
            return 0.6
        case 5..<10:
            return 0.4
        default:
            return 0.2
        }
    }
    
    private static func calculateSleepScore(duration: Double) -> Double {
        switch duration {
        case 8...:
            return 1.0
        case 7..<8:
            return 0.9
        case 6..<7:
            return 0.7
        case 5..<6:
            return 0.5
        case 4..<5:
            return 0.3
        default:
            return 0.1
        }
    }
    
    private static func calculateRespiratoryScore(rate: Double) -> Double {
        switch rate {
        case 12...16:
            return 1.0
        case 10..<12, 16..<18:
            return 0.8
        case 8..<10, 18..<20:
            return 0.6
        default:
            return 0.4
        }
    }
    
    static func recoveryRecommendation(for level: RecoveryLevel) -> String {
        switch level {
        case .excellent:
            return "You're well recovered! Great day for a hard workout."
        case .good:
            return "Good recovery. You can train normally today."
        case .fair:
            return "Moderate recovery. Consider a lighter workout or active recovery."
        case .poor:
            return "Low recovery. Rest or very light activity recommended."
        }
    }
    
    static func recoveryComponents(
        hrvCurrent: Double?,
        hrvBaseline: Double?,
        rhrCurrent: Double?,
        rhrBaseline: Double?,
        sleepDuration: Double,
        respiratoryRate: Double?
    ) -> RecoveryComponents {
        var hrvScoreValue: Double? = nil
        if let current = hrvCurrent, let baseline = hrvBaseline, baseline > 0 {
            hrvScoreValue = calculateHRVScore(current: current, baseline: baseline) * 100
        }
        
        var rhrScoreValue: Double? = nil
        if let current = rhrCurrent, let baseline = rhrBaseline, baseline > 0 {
            rhrScoreValue = calculateRHRScore(current: current, baseline: baseline) * 100
        }
        
        let sleepScoreValue = calculateSleepScore(duration: sleepDuration) * 100
        
        var respScoreValue: Double? = nil
        if let rate = respiratoryRate {
            respScoreValue = calculateRespiratoryScore(rate: rate) * 100
        }
        
        return RecoveryComponents(
            hrvScore: hrvScoreValue,
            restingHRScore: rhrScoreValue,
            sleepScore: sleepScoreValue,
            respiratoryRateScore: respScoreValue,
            hrvValue: hrvCurrent,
            restingHRValue: rhrCurrent,
            sleepDuration: sleepDuration,
            respiratoryRateValue: respiratoryRate,
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            date: Date()
        )
    }
}
