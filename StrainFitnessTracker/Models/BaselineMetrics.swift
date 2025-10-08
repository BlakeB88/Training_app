//
//  BaselineMetrics.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

/// Represents baseline metrics calculated from historical data
struct BaselineMetrics {
    
    // MARK: - HRV Baseline
    let hrvBaseline: Double?
    let hrvStandardDeviation: Double?
    
    // MARK: - Resting Heart Rate Baseline
    let rhrBaseline: Double?
    let rhrStandardDeviation: Double?
    
    // MARK: - Strain Baselines
    let acuteStrain: Double? // 7-day average
    let chronicStrain: Double? // 28-day average
    
    // MARK: - Respiratory Rate Baseline
    let respiratoryRateBaseline: Double?
    
    // MARK: - Metadata
    let calculatedDate: Date
    let daysOfData: Int
    
    // MARK: - Computed Properties
    
    /// Acute to Chronic Workload Ratio
    var acwr: Double? {
        guard let acute = acuteStrain,
              let chronic = chronicStrain,
              chronic > 0 else {
            return nil
        }
        return acute / chronic
    }
    
    /// Whether baseline is established (minimum 7 days of data)
    var isEstablished: Bool {
        return daysOfData >= AppConstants.Baseline.minimumDaysForBaseline
    }
    
    /// HRV variability coefficient
    var hrvVariability: Double? {
        guard let baseline = hrvBaseline,
              let stdDev = hrvStandardDeviation,
              baseline > 0 else {
            return nil
        }
        return stdDev / baseline
    }
    
    /// RHR variability coefficient
    var rhrVariability: Double? {
        guard let baseline = rhrBaseline,
              let stdDev = rhrStandardDeviation,
              baseline > 0 else {
            return nil
        }
        return stdDev / baseline
    }
    
    // MARK: - Initialization
    init(
        hrvBaseline: Double? = nil,
        hrvStandardDeviation: Double? = nil,
        rhrBaseline: Double? = nil,
        rhrStandardDeviation: Double? = nil,
        acuteStrain: Double? = nil,
        chronicStrain: Double? = nil,
        respiratoryRateBaseline: Double? = nil,
        calculatedDate: Date = Date(),
        daysOfData: Int = 0
    ) {
        self.hrvBaseline = hrvBaseline
        self.hrvStandardDeviation = hrvStandardDeviation
        self.rhrBaseline = rhrBaseline
        self.rhrStandardDeviation = rhrStandardDeviation
        self.acuteStrain = acuteStrain
        self.chronicStrain = chronicStrain
        self.respiratoryRateBaseline = respiratoryRateBaseline
        self.calculatedDate = calculatedDate
        self.daysOfData = daysOfData
    }
    
    // MARK: - Helper Methods
    
    /// Check if HRV is significantly different from baseline
    func isHRVAbnormal(_ currentHRV: Double) -> Bool {
        guard let baseline = hrvBaseline,
              let stdDev = hrvStandardDeviation else {
            return false
        }
        
        let difference = abs(currentHRV - baseline)
        return difference > (stdDev * 2.0) // 2 standard deviations
    }
    
    /// Check if RHR is significantly different from baseline
    func isRHRAbnormal(_ currentRHR: Double) -> Bool {
        guard let baseline = rhrBaseline,
              let stdDev = rhrStandardDeviation else {
            return false
        }
        
        let difference = abs(currentRHR - baseline)
        return difference > (stdDev * 2.0) // 2 standard deviations
    }
    
    /// Get ACWR status
    func acwrStatus() -> ACWRStatus {
        guard let ratio = acwr else {
            return .unknown
        }
        
        switch ratio {
        case 0..<AppConstants.ACWR.undertrainingMax:
            return .undertraining
        case AppConstants.ACWR.optimalMin...AppConstants.ACWR.optimalMax:
            return .optimal
        case AppConstants.ACWR.optimalMax..<AppConstants.ACWR.cautionMax:
            return .caution
        default:
            return .highRisk
        }
    }
}

// MARK: - ACWR Status Enum
enum ACWRStatus: String {
    case undertraining = "Undertraining"
    case optimal = "Optimal"
    case caution = "Caution"
    case highRisk = "High Risk"
    case unknown = "Unknown"
    
    var description: String {
        switch self {
        case .undertraining:
            return "Training load is lower than usual"
        case .optimal:
            return "Training load is in the optimal range"
        case .caution:
            return "Training load is elevated - monitor recovery"
        case .highRisk:
            return "Training load is very high - increased injury risk"
        case .unknown:
            return "Not enough data to calculate"
        }
    }
}

// MARK: - Codable Conformance
extension BaselineMetrics: Codable {}

// MARK: - Equatable Conformance
extension BaselineMetrics: Equatable {}
