//
//  Double+Formatting.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

extension Double {
    
    // MARK: - Strain Formatting
    func formattedStrain() -> String {
        return String(format: "%.1f", self)
    }
    
    func strainLevel() -> String {
        switch self {
        case 0..<AppConstants.Strain.lightMax:
            return "Light"
        case AppConstants.Strain.lightMax..<AppConstants.Strain.moderateMax:
            return "Moderate"
        case AppConstants.Strain.moderateMax..<AppConstants.Strain.hardMax:
            return "Hard"
        case AppConstants.Strain.hardMax...AppConstants.Strain.maxValue:
            return "Very Hard"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - Recovery Formatting
    func formattedRecovery() -> String {
        return String(format: "%.0f%%", self)
    }
    
    func recoveryLevel() -> String {
        switch self {
        case AppConstants.Recovery.excellentMin...AppConstants.Recovery.maxValue:
            return "Excellent"
        case AppConstants.Recovery.goodMin..<AppConstants.Recovery.excellentMin:
            return "Good"
        case AppConstants.Recovery.fairMin..<AppConstants.Recovery.goodMin:
            return "Fair"
        case AppConstants.Recovery.minValue..<AppConstants.Recovery.fairMin:
            return "Poor"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - ACWR Formatting
    func formattedACWR() -> String {
        return String(format: "%.2f", self)
    }
    
    func acwrZone() -> String {
        switch self {
        case 0..<AppConstants.ACWR.undertrainingMax:
            return "Undertraining"
        case AppConstants.ACWR.optimalMin...AppConstants.ACWR.optimalMax:
            return "Optimal"
        case AppConstants.ACWR.optimalMax..<AppConstants.ACWR.cautionMax:
            return "Caution"
        case AppConstants.ACWR.cautionMax...:
            return "High Risk"
        default:
            return "Unknown"
        }
    }
    
    // MARK: - Heart Rate Formatting
    func formattedHeartRate() -> String {
        return String(format: "%.0f bpm", self)
    }
    
    func formattedHRV() -> String {
        return String(format: "%.0f ms", self)
    }
    
    // MARK: - Duration Formatting
    func formattedDuration() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    func formattedDurationShort() -> String {
        let hours = Int(self) / 3600
        let minutes = Int(self) / 60 % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Distance Formatting
    func formattedDistance(unit: DistanceUnit = .meters) -> String {
        switch unit {
        case .meters:
            if self >= 1000 {
                return String(format: "%.2f km", self / 1000)
            } else {
                return String(format: "%.0f m", self)
            }
        case .shortCourseMeters:
            if self >= 1000 {
                return String(format: "%.2f km (SC)", self / 1000)
            } else {
                return String(format: "%.0f m (SC)", self)
            }
        case .miles:
            return String(format: "%.2f mi", self)
        case .yards:
            return String(format: "%.0f yd", self)
        }
    }
    
    // MARK: - Calories Formatting
    func formattedCalories() -> String {
        return String(format: "%.0f cal", self)
    }
    
    // MARK: - Percentage Formatting
    func formattedPercentage(decimals: Int = 0) -> String {
        return String(format: "%.\(decimals)f%%", self)
    }
    
    // MARK: - General Number Formatting
    func formatted(decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f", self)
    }
    
    // MARK: - Clamping
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Distance Unit Enum
enum DistanceUnit: String, Codable, CaseIterable {
    case meters
    case shortCourseMeters
    case miles
    case yards

    var sortOrder: Int {
        switch self {
        case .meters: return 0
        case .shortCourseMeters: return 1
        case .yards: return 2
        case .miles: return 3
        }
    }
}
