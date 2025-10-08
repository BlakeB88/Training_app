//
//  HeartRateProfile.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

/// Represents a user's heart rate profile for intensity calculations
struct HeartRateProfile {
    
    // MARK: - Properties
    let maxHeartRate: Double
    let restingHeartRate: Double
    let age: Int?
    
    // MARK: - Computed Properties
    var heartRateReserve: Double {
        return maxHeartRate - restingHeartRate
    }
    
    // MARK: - Initialization
    init(maxHeartRate: Double? = nil, restingHeartRate: Double, age: Int? = nil) {
        self.restingHeartRate = restingHeartRate
        self.age = age
        
        // Calculate max HR if not provided
        if let maxHR = maxHeartRate {
            self.maxHeartRate = maxHR
        } else if let userAge = age {
            // Use age-based formula: 220 - age
            self.maxHeartRate = 220.0 - Double(userAge)
        } else {
            // Default fallback
            self.maxHeartRate = AppConstants.HeartRate.defaultMaxHR
        }
    }
    
    // MARK: - Heart Rate Zone Calculations
    
    /// Calculate HR intensity as percentage of max HR
    func intensityFromHeartRate(_ heartRate: Double) -> Double {
        guard heartRate > 0, maxHeartRate > 0 else { return 0.0 }
        return (heartRate / maxHeartRate).clamped(to: 0.0...1.0)
    }
    
    /// Calculate HR intensity using Heart Rate Reserve (Karvonen method)
    func intensityFromHeartRateReserve(_ heartRate: Double) -> Double {
        guard heartRateReserve > 0 else { return 0.0 }
        let intensity = (heartRate - restingHeartRate) / heartRateReserve
        return intensity.clamped(to: 0.0...1.0)
    }
    
    /// Get heart rate zone (1-5) for a given heart rate
    func heartRateZone(for heartRate: Double) -> Int {
        let intensity = intensityFromHeartRate(heartRate)
        
        switch intensity {
        case 0..<AppConstants.HeartRate.zone1Max:
            return 1 // Recovery
        case AppConstants.HeartRate.zone1Max..<AppConstants.HeartRate.zone2Max:
            return 2 // Aerobic
        case AppConstants.HeartRate.zone2Max..<AppConstants.HeartRate.zone3Max:
            return 3 // Tempo
        case AppConstants.HeartRate.zone3Max..<AppConstants.HeartRate.zone4Max:
            return 4 // Threshold
        default:
            return 5 // VO2 Max
        }
    }
    
    /// Get target heart rate for a specific zone
    func targetHeartRate(forZone zone: Int) -> ClosedRange<Double> {
        let ranges: [ClosedRange<Double>] = [
            0.50...0.60, // Zone 1
            0.60...0.70, // Zone 2
            0.70...0.80, // Zone 3
            0.80...0.90, // Zone 4
            0.90...1.00  // Zone 5
        ]
        
        guard zone >= 1 && zone <= 5 else {
            return restingHeartRate...maxHeartRate
        }
        
        let range = ranges[zone - 1]
        return (maxHeartRate * range.lowerBound)...(maxHeartRate * range.upperBound)
    }
    
    /// Get zone name
    func zoneName(for zone: Int) -> String {
        switch zone {
        case 1: return "Recovery"
        case 2: return "Aerobic"
        case 3: return "Tempo"
        case 4: return "Threshold"
        case 5: return "VO2 Max"
        default: return "Unknown"
        }
    }
}

// MARK: - Codable Conformance
extension HeartRateProfile: Codable {}

// MARK: - Equatable Conformance
extension HeartRateProfile: Equatable {}
