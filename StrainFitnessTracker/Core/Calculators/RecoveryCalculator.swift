//
//  RecoveryCalculator.swift
//  StrainFitnessTracker
//
//  Enhanced recovery calculation with activity strain, multi-night sleep,
//  personalized baselines, and dynamic weighting
//

import Foundation
import HealthKit

struct RecoveryCalculator {
    
    /// Calculate comprehensive recovery score
    /// - Parameters:
    ///   - hrvCurrent: Today's HRV
    ///   - hrvBaseline: Personal HRV baseline (14-30 day average)
    ///   - hrvStdDev: HRV standard deviation for personalization
    ///   - rhrCurrent: Today's resting heart rate
    ///   - rhrBaseline: Personal RHR baseline
    ///   - rhrStdDev: RHR standard deviation
    ///   - sleepDuration: Last night's sleep in hours
    ///   - recentSleepDurations: Last 3-4 nights of sleep for pattern analysis
    ///   - sleepEfficiency: Sleep efficiency percentage (0-100)
    ///   - sleepConsistency: Sleep consistency score (0-100)
    ///   - recentStrain: Yesterday's strain (0-21)
    ///   - acuteStrain: 7-day average strain
    ///   - chronicStrain: 28-day average strain
    ///   - respiratoryRate: Current respiratory rate
    ///   - respiratoryBaseline: Baseline respiratory rate
    /// - Returns: Recovery score (0-100)
    static func calculateRecoveryScore(
        hrvCurrent: Double?,
        hrvBaseline: Double?,
        hrvStdDev: Double?,
        rhrCurrent: Double?,
        rhrBaseline: Double?,
        rhrStdDev: Double?,
        sleepDuration: Double,
        recentSleepDurations: [Double] = [],
        sleepEfficiency: Double? = nil,
        sleepConsistency: Double? = nil,
        recentStrain: Double? = nil,
        acuteStrain: Double? = nil,
        chronicStrain: Double? = nil,
        respiratoryRate: Double? = nil,
        respiratoryBaseline: Double? = nil
    ) -> Double {
        var components: [(score: Double, weight: Double)] = []
        
        // 1. HRV Score (30-35% base weight, adjusted by availability)
        if let current = hrvCurrent,
           let baseline = hrvBaseline,
           baseline > 0 {
            let stdDev = hrvStdDev ?? (baseline * 0.15) // Default 15% if not available
            let hrvScore = calculatePersonalizedHRVScore(
                current: current,
                baseline: baseline,
                stdDev: stdDev
            )
            components.append((hrvScore, 0.35))
        }
        
        // 2. Resting HR Score (25-30% base weight)
        if let current = rhrCurrent,
           let baseline = rhrBaseline,
           baseline > 0 {
            let stdDev = rhrStdDev ?? (baseline * 0.08) // Default 8% if not available
            let rhrScore = calculatePersonalizedRHRScore(
                current: current,
                baseline: baseline,
                stdDev: stdDev
            )
            components.append((rhrScore, 0.30))
        }
        
        // 3. Multi-Night Sleep Score (20-25% weight)
        let sleepScore = calculateEnhancedSleepScore(
            lastNightDuration: sleepDuration,
            recentNights: recentSleepDurations,
            efficiency: sleepEfficiency,
            consistency: sleepConsistency
        )
        components.append((sleepScore, 0.20))
        
        // 4. Activity/Strain Impact (10-15% weight - negative factor)
        if let yesterdayStrain = recentStrain {
            let strainScore = calculateStrainRecoveryImpact(
                recentStrain: yesterdayStrain,
                acuteStrain: acuteStrain,
                chronicStrain: chronicStrain
            )
            components.append((strainScore, 0.10))
        }
        
        // 5. Respiratory Rate Score (5% weight)
        if let respRate = respiratoryRate,
           let baseline = respiratoryBaseline ?? getDefaultRespiratoryBaseline() {
            let respScore = calculateRespiratoryScore(
                rate: respRate,
                baseline: baseline
            )
            components.append((respScore, 0.05))
        }
        
        // Calculate weighted average
        let totalWeight = components.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 50.0 }
        
        let weightedSum = components.reduce(0.0) { $0 + ($1.score * $1.weight) }
        let finalScore = (weightedSum / totalWeight) * 100.0
        
        return finalScore.clamped(to: 0...100)
    }
    
    // MARK: - Personalized HRV Scoring
    
    /// Calculate HRV score using personal baseline and standard deviation
    private static func calculatePersonalizedHRVScore(
        current: Double,
        baseline: Double,
        stdDev: Double
    ) -> Double {
        // Calculate z-score (standard deviations from baseline)
        let zScore = (current - baseline) / stdDev
        
        // Convert z-score to recovery score
        // Higher HRV = better recovery
        switch zScore {
        case 1.5...: // Very high (>1.5 SD above baseline)
            return 1.0
        case 0.75..<1.5: // High (0.75-1.5 SD above)
            return 0.95
        case 0.25..<0.75: // Slightly high
            return 0.85
        case -0.25..<0.25: // Normal range
            return 0.75
        case -0.75..<(-0.25): // Slightly low
            return 0.60
        case -1.5..<(-0.75): // Low
            return 0.40
        default: // Very low (<-1.5 SD below)
            return 0.20
        }
    }
    
    // MARK: - Personalized RHR Scoring
    
    /// Calculate RHR score using personal baseline and standard deviation
    private static func calculatePersonalizedRHRScore(
        current: Double,
        baseline: Double,
        stdDev: Double
    ) -> Double {
        // Calculate z-score (standard deviations from baseline)
        let zScore = (current - baseline) / stdDev
        
        // Convert z-score to recovery score
        // Lower RHR = better recovery (inverse of HRV)
        switch zScore {
        case ...(-1.5): // Very low (>1.5 SD below baseline)
            return 1.0
        case -1.5..<(-0.75): // Low
            return 0.95
        case -0.75..<(-0.25): // Slightly low
            return 0.85
        case -0.25..<0.25: // Normal range
            return 0.75
        case 0.25..<0.75: // Slightly high
            return 0.60
        case 0.75..<1.5: // High
            return 0.40
        default: // Very high (>1.5 SD above)
            return 0.20
        }
    }
    
    // MARK: - Enhanced Sleep Scoring
    
    /// Calculate sleep score incorporating multiple nights, efficiency, and consistency
    private static func calculateEnhancedSleepScore(
        lastNightDuration: Double,
        recentNights: [Double],
        efficiency: Double?,
        consistency: Double?
    ) -> Double {
        var sleepComponents: [(score: Double, weight: Double)] = []
        
        // 1. Multi-night duration (50% of sleep score)
        let durationScore = calculateMultiNightDurationScore(
            lastNight: lastNightDuration,
            recentNights: recentNights
        )
        sleepComponents.append((durationScore, 0.50))
        
        // 2. Sleep efficiency (30% if available)
        if let eff = efficiency {
            let efficiencyScore = calculateSleepEfficiencyScore(efficiency: eff)
            sleepComponents.append((efficiencyScore, 0.30))
        }
        
        // 3. Sleep consistency (20% if available)
        if let cons = consistency {
            let consistencyScore = cons / 100.0 // Already 0-100
            sleepComponents.append((consistencyScore, 0.20))
        }
        
        // Calculate weighted sleep score
        let totalWeight = sleepComponents.reduce(0.0) { $0 + $1.weight }
        guard totalWeight > 0 else { return durationScore }
        
        let weightedSum = sleepComponents.reduce(0.0) { $0 + ($1.score * $1.weight) }
        return weightedSum / totalWeight
    }
    
    /// Calculate duration score using last 3-4 nights (smoothing)
    private static func calculateMultiNightDurationScore(
        lastNight: Double,
        recentNights: [Double]
    ) -> Double {
        // If we have recent nights, calculate average with weighted emphasis on last night
        if !recentNights.isEmpty {
            let recentAvg = recentNights.reduce(0.0, +) / Double(recentNights.count)
            // 60% last night, 40% recent average
            let smoothedDuration = (lastNight * 0.60) + (recentAvg * 0.40)
            return scoreSleepDuration(smoothedDuration)
        }
        
        // Otherwise just score last night
        return scoreSleepDuration(lastNight)
    }
    
    /// Score individual sleep duration
    private static func scoreSleepDuration(_ hours: Double) -> Double {
        switch hours {
        case 8.5...: // Optimal or more
            return 1.0
        case 7.5..<8.5: // Good
            return 0.95
        case 7.0..<7.5: // Adequate
            return 0.85
        case 6.0..<7.0: // Moderate
            return 0.70
        case 5.0..<6.0: // Low
            return 0.50
        case 4.0..<5.0: // Very low
            return 0.30
        default: // Critical
            return 0.15
        }
    }
    
    /// Score sleep efficiency
    private static func calculateSleepEfficiencyScore(efficiency: Double) -> Double {
        switch efficiency {
        case 90...: // Excellent
            return 1.0
        case 85..<90: // Very good
            return 0.95
        case 80..<85: // Good
            return 0.85
        case 75..<80: // Fair
            return 0.70
        case 70..<75: // Poor
            return 0.50
        default: // Very poor
            return 0.30
        }
    }
    
    // MARK: - Strain Recovery Impact
    
    /// Calculate how recent activity strain affects recovery
    /// Higher strain = lower recovery score (negative factor)
    private static func calculateStrainRecoveryImpact(
        recentStrain: Double,
        acuteStrain: Double?,
        chronicStrain: Double?
    ) -> Double {
        var strainImpact = 0.0
        var weight = 0.0
        
        // 1. Yesterday's strain (60% weight)
        let yesterdayImpact = calculateSingleStrainImpact(recentStrain)
        strainImpact += yesterdayImpact * 0.60
        weight += 0.60
        
        // 2. Acute/Chronic ratio (40% weight if available)
        if let acute = acuteStrain, let chronic = chronicStrain, chronic > 0 {
            let acwr = acute / chronic
            let ratioImpact = calculateACWRImpact(acwr)
            strainImpact += ratioImpact * 0.40
            weight += 0.40
        }
        
        return weight > 0 ? strainImpact / weight : yesterdayImpact
    }
    
    /// Score yesterday's strain (higher strain = lower score)
    private static func calculateSingleStrainImpact(_ strain: Double) -> Double {
        switch strain {
        case 0..<5: // Very light
            return 1.0
        case 5..<10: // Light
            return 0.95
        case 10..<14: // Moderate
            return 0.85
        case 14..<18: // High
            return 0.65
        case 18...: // All out
            return 0.40
        default:
            return 0.85
        }
    }
    
    /// Score ACWR for training load balance
    private static func calculateACWRImpact(_ acwr: Double) -> Double {
        switch acwr {
        case 0..<0.8: // Undertraining
            return 0.90
        case 0.8..<1.0: // Optimal low
            return 1.0
        case 1.0..<1.3: // Optimal high
            return 0.95
        case 1.3..<1.5: // Caution
            return 0.75
        case 1.5..<2.0: // High risk
            return 0.50
        default: // Very high risk
            return 0.30
        }
    }
    
    // MARK: - Respiratory Rate Scoring
    
    /// Score respiratory rate relative to baseline
    private static func calculateRespiratoryScore(
        rate: Double,
        baseline: Double
    ) -> Double {
        let deviation = abs(rate - baseline)
        
        switch deviation {
        case 0..<0.5: // Very close to baseline
            return 1.0
        case 0.5..<1.0: // Close
            return 0.90
        case 1.0..<1.5: // Slightly elevated
            return 0.75
        case 1.5..<2.0: // Elevated
            return 0.60
        case 2.0..<3.0: // High
            return 0.40
        default: // Very high
            return 0.20
        }
    }
    
    private static func getDefaultRespiratoryBaseline() -> Double? {
        return 14.0 // Average adult baseline
    }
    
    // MARK: - Legacy Compatibility & Helpers
    
    /// Legacy method for backward compatibility
    static func calculateRecoveryScore(
        hrvCurrent: Double?,
        hrvBaseline: Double?,
        rhrCurrent: Double?,
        rhrBaseline: Double?,
        sleepDuration: Double,
        respiratoryRate: Double? = nil
    ) -> Double {
        return calculateRecoveryScore(
            hrvCurrent: hrvCurrent,
            hrvBaseline: hrvBaseline,
            hrvStdDev: nil,
            rhrCurrent: rhrCurrent,
            rhrBaseline: rhrBaseline,
            rhrStdDev: nil,
            sleepDuration: sleepDuration,
            recentSleepDurations: [],
            sleepEfficiency: nil,
            sleepConsistency: nil,
            recentStrain: nil,
            acuteStrain: nil,
            chronicStrain: nil,
            respiratoryRate: respiratoryRate,
            respiratoryBaseline: nil
        )
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
    
    /// Enhanced recommendation with personalized context
    static func detailedRecoveryRecommendation(
        score: Double,
        hrvZScore: Double?,
        rhrZScore: Double?,
        sleepHours: Double,
        recentStrain: Double?
    ) -> String {
        let level = RecoveryLevel.from(score: score)
        var recommendation = recoveryRecommendation(for: level)
        
        // Add specific guidance based on limiting factors
        var limitingFactors: [String] = []
        
        if let hrvZ = hrvZScore, hrvZ < -1.0 {
            limitingFactors.append("HRV is significantly below your baseline")
        }
        if let rhrZ = rhrZScore, rhrZ > 1.0 {
            limitingFactors.append("Resting heart rate is elevated")
        }
        if sleepHours < 6.5 {
            limitingFactors.append("Sleep duration was insufficient")
        }
        if let strain = recentStrain, strain > 14 {
            limitingFactors.append("Yesterday's training was intense")
        }
        
        if !limitingFactors.isEmpty {
            recommendation += "\n\nKey factors: " + limitingFactors.joined(separator: ", ") + "."
        }
        
        return recommendation
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
            let stdDev = baseline * 0.15
            hrvScoreValue = calculatePersonalizedHRVScore(
                current: current,
                baseline: baseline,
                stdDev: stdDev
            ) * 100
        }
        
        var rhrScoreValue: Double? = nil
        if let current = rhrCurrent, let baseline = rhrBaseline, baseline > 0 {
            let stdDev = baseline * 0.08
            rhrScoreValue = calculatePersonalizedRHRScore(
                current: current,
                baseline: baseline,
                stdDev: stdDev
            ) * 100
        }
        
        let sleepScoreValue = scoreSleepDuration(sleepDuration) * 100
        
        var respScoreValue: Double? = nil
        if let rate = respiratoryRate, let baseline = getDefaultRespiratoryBaseline() {
            respScoreValue = calculateRespiratoryScore(
                rate: rate,
                baseline: baseline
            ) * 100
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

// MARK: - Recovery Level Extension

extension RecoveryLevel {
    static func from(score: Double) -> RecoveryLevel {
        switch score {
        case 67...100:
            return .excellent
        case 34..<67:
            return .good
        case 17..<34:
            return .fair
        default:
            return .poor
        }
    }
}
