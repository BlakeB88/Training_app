//
//  RecoveryComponents.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

/// Represents the individual components that make up the recovery score
struct RecoveryComponents {
    
    // MARK: - Component Scores (0-100)
    let hrvScore: Double?
    let restingHRScore: Double?
    let sleepScore: Double?
    let respiratoryRateScore: Double?
    
    // MARK: - Raw Values
    let hrvValue: Double?
    let restingHRValue: Double?
    let sleepDuration: Double? // in hours
    let respiratoryRateValue: Double?
    
    // MARK: - Baseline Comparisons
    let hrvBaseline: Double?
    let rhrBaseline: Double?
    
    // MARK: - Metadata
    let date: Date
    
    // MARK: - Computed Properties
    
    /// Overall recovery score (weighted average)
    var overallScore: Double {
        var totalScore: Double = 0.0
        var totalWeight: Double = 0.0
        
        if let hrv = hrvScore {
            totalScore += hrv * AppConstants.Recovery.hrvWeight
            totalWeight += AppConstants.Recovery.hrvWeight
        }
        
        if let rhr = restingHRScore {
            totalScore += rhr * AppConstants.Recovery.restingHRWeight
            totalWeight += AppConstants.Recovery.restingHRWeight
        }
        
        if let sleep = sleepScore {
            totalScore += sleep * AppConstants.Recovery.sleepWeight
            totalWeight += AppConstants.Recovery.sleepWeight
        }
        
        if let resp = respiratoryRateScore {
            totalScore += resp * AppConstants.Recovery.respiratoryRateWeight
            totalWeight += AppConstants.Recovery.respiratoryRateWeight
        }
        
        guard totalWeight > 0 else { return 0.0 }
        
        // Normalize to 0-100 scale
        return (totalScore / totalWeight).clamped(to: 0.0...100.0)
    }
    
    /// HRV change from baseline (percentage)
    var hrvChange: Double? {
        guard let current = hrvValue,
              let baseline = hrvBaseline,
              baseline > 0 else {
            return nil
        }
        return ((current - baseline) / baseline) * 100.0
    }
    
    /// RHR change from baseline (absolute)
    var rhrChange: Double? {
        guard let current = restingHRValue,
              let baseline = rhrBaseline else {
            return nil
        }
        return current - baseline
    }
    
    /// Whether recovery data is complete
    var isComplete: Bool {
        return hrvScore != nil && restingHRScore != nil && sleepScore != nil
    }
    
    /// Recovery level
    var recoveryLevel: RecoveryLevel {
        let score = overallScore
        
        switch score {
        case AppConstants.Recovery.excellentMin...AppConstants.Recovery.maxValue:
            return .excellent
        case AppConstants.Recovery.goodMin..<AppConstants.Recovery.excellentMin:
            return .good
        case AppConstants.Recovery.fairMin..<AppConstants.Recovery.goodMin:
            return .fair
        default:
            return .poor
        }
    }
    
    // MARK: - Initialization
    init(
        hrvScore: Double? = nil,
        restingHRScore: Double? = nil,
        sleepScore: Double? = nil,
        respiratoryRateScore: Double? = nil,
        hrvValue: Double? = nil,
        restingHRValue: Double? = nil,
        sleepDuration: Double? = nil,
        respiratoryRateValue: Double? = nil,
        hrvBaseline: Double? = nil,
        rhrBaseline: Double? = nil,
        date: Date = Date()
    ) {
        self.hrvScore = hrvScore
        self.restingHRScore = restingHRScore
        self.sleepScore = sleepScore
        self.respiratoryRateScore = respiratoryRateScore
        self.hrvValue = hrvValue
        self.restingHRValue = restingHRValue
        self.sleepDuration = sleepDuration
        self.respiratoryRateValue = respiratoryRateValue
        self.hrvBaseline = hrvBaseline
        self.rhrBaseline = rhrBaseline
        self.date = date
    }
    
    // MARK: - Helper Methods
    
    /// Get component breakdown as array for display
    func componentBreakdown() -> [(name: String, score: Double?, weight: Double)] {
        return [
            ("HRV", hrvScore, AppConstants.Recovery.hrvWeight),
            ("Resting HR", restingHRScore, AppConstants.Recovery.restingHRWeight),
            ("Sleep", sleepScore, AppConstants.Recovery.sleepWeight),
            ("Respiratory Rate", respiratoryRateScore, AppConstants.Recovery.respiratoryRateWeight)
        ]
    }
    
    /// Get recommendations based on recovery components
    func recommendations() -> [String] {
        var recommendations: [String] = []
        
        if let hrvScore = hrvScore, hrvScore < 50 {
            recommendations.append("HRV is low - consider a rest day or light activity")
        }
        
        if let rhrScore = restingHRScore, rhrScore < 50 {
            recommendations.append("Elevated resting heart rate - may indicate stress or overtraining")
        }
        
        if let sleepScore = sleepScore, sleepScore < 70 {
            recommendations.append("Sleep quality/duration is suboptimal - prioritize rest tonight")
        }
        
        if overallScore >= AppConstants.Recovery.excellentMin {
            recommendations.append("Excellent recovery - good day for high-intensity training")
        } else if overallScore < AppConstants.Recovery.fairMin {
            recommendations.append("Poor recovery - consider active recovery or rest")
        }
        
        return recommendations
    }
}

// MARK: - Recovery Level Enum
enum RecoveryLevel: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "yellow-green"
        case .fair: return "yellow"
        case .poor: return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .excellent: return "💪"
        case .good: return "👍"
        case .fair: return "😐"
        case .poor: return "😴"
        }
    }
}

// MARK: - Codable Conformance
extension RecoveryComponents: Codable {}

// MARK: - Equatable Conformance
extension RecoveryComponents: Equatable {}
