//
//  StressMetrics.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import Foundation

/// Represents stress data for a specific time period
struct StressMetrics: Codable, Identifiable, Equatable {
    
    // MARK: - Identification
    let id: UUID
    let timestamp: Date
    
    // MARK: - Stress Measurements
    let stressLevel: Double // 0.0 - 3.0 scale (like Whoop)
    let heartRate: Double
    let baselineHeartRate: Double
    let hrv: Double?
    let baselineHRV: Double?
    
    // MARK: - Context
    let isExerciseRelated: Bool // Filter out workout stress
    let confidence: Double // 0.0 - 1.0, how confident we are in this reading
    
    // MARK: - Computed Properties
    
    var stressZone: StressZone {
        switch stressLevel {
        case 0.0..<1.0:
            return .low
        case 1.0..<2.0:
            return .medium
        case 2.0...3.0:
            return .high
        default:
            return .medium
        }
    }
    
    var stressZoneDescription: String {
        stressZone.description
    }
    
    var stressZoneColor: String {
        stressZone.colorHex
    }
    
    var heartRateElevation: Double {
        heartRate - baselineHeartRate
    }
    
    var heartRateElevationPercent: Double {
        guard baselineHeartRate > 0 else { return 0 }
        return (heartRateElevation / baselineHeartRate) * 100
    }
    
    var hrvDepressionPercent: Double? {
        guard let hrv = hrv, let baseline = baselineHRV, baseline > 0 else { return nil }
        return ((baseline - hrv) / baseline) * 100
    }
    
    var isHighStress: Bool {
        stressLevel >= 2.0
    }
    
    var isMediumStress: Bool {
        stressLevel >= 1.0 && stressLevel < 2.0
    }
    
    var isLowStress: Bool {
        stressLevel < 1.0
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date,
        stressLevel: Double,
        heartRate: Double,
        baselineHeartRate: Double,
        hrv: Double? = nil,
        baselineHRV: Double? = nil,
        isExerciseRelated: Bool = false,
        confidence: Double = 1.0
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stressLevel = min(max(stressLevel, 0.0), 3.0) // Clamp to 0-3 range
        self.heartRate = heartRate
        self.baselineHeartRate = baselineHeartRate
        self.hrv = hrv
        self.baselineHRV = baselineHRV
        self.isExerciseRelated = isExerciseRelated
        self.confidence = min(max(confidence, 0.0), 1.0) // Clamp to 0-1 range
    }
    
    // MARK: - Formatting
    
    func formattedStressLevel() -> String {
        return String(format: "%.1f", stressLevel)
    }
    
    func formattedHeartRate() -> String {
        return String(format: "%.0f bpm", heartRate)
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

// MARK: - Stress Zone Enum

enum StressZone: String, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var description: String {
        rawValue
    }
    
    var colorHex: String {
        switch self {
        case .low:
            return "#00D9A5" // Green
        case .medium:
            return "#FFC700" // Yellow
        case .high:
            return "#FF6B6B" // Red/Orange
        }
    }
    
    var range: String {
        switch self {
        case .low:
            return "0.0 - 1.0"
        case .medium:
            return "1.0 - 2.0"
        case .high:
            return "2.0 - 3.0"
        }
    }
}

// MARK: - Daily Stress Summary

struct DailyStressSummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    let stressReadings: [StressMetrics]
    
    // MARK: - Computed Properties
    
    var averageStress: Double {
        guard !stressReadings.isEmpty else { return 0 }
        let validReadings = stressReadings.filter { !$0.isExerciseRelated }
        guard !validReadings.isEmpty else { return 0 }
        return validReadings.reduce(0.0) { $0 + $1.stressLevel } / Double(validReadings.count)
    }
    
    var maxStress: Double {
        stressReadings.map { $0.stressLevel }.max() ?? 0
    }
    
    var timeInHighStress: TimeInterval {
        let highStressPeriods = stressReadings.filter { $0.isHighStress && !$0.isExerciseRelated }
        return TimeInterval(highStressPeriods.count * 5 * 60) // Assuming 5-min intervals
    }
    
    var timeInMediumStress: TimeInterval {
        let mediumStressPeriods = stressReadings.filter { $0.isMediumStress && !$0.isExerciseRelated }
        return TimeInterval(mediumStressPeriods.count * 5 * 60)
    }
    
    var timeInLowStress: TimeInterval {
        let lowStressPeriods = stressReadings.filter { $0.isLowStress && !$0.isExerciseRelated }
        return TimeInterval(lowStressPeriods.count * 5 * 60)
    }
    
    var dominantStressZone: StressZone {
        let times = [
            (StressZone.high, timeInHighStress),
            (StressZone.medium, timeInMediumStress),
            (StressZone.low, timeInLowStress)
        ]
        return times.max(by: { $0.1 < $1.1 })?.0 ?? .medium
    }
    
    var longestHighStressPeriod: (start: Date, duration: TimeInterval)? {
        let highStressReadings = stressReadings.filter { $0.isHighStress && !$0.isExerciseRelated }
        guard !highStressReadings.isEmpty else { return nil }
        
        // Find consecutive high stress periods
        var currentStart: Date?
        var currentDuration: TimeInterval = 0
        var longestStart: Date?
        var longestDuration: TimeInterval = 0
        
        for (index, reading) in highStressReadings.enumerated() {
            if currentStart == nil {
                currentStart = reading.timestamp
                currentDuration = 5 * 60 // 5 minutes
            } else if index > 0 {
                let timeSinceLast = reading.timestamp.timeIntervalSince(highStressReadings[index - 1].timestamp)
                if timeSinceLast <= 10 * 60 { // Within 10 minutes
                    currentDuration += 5 * 60
                } else {
                    // Period ended
                    if currentDuration > longestDuration {
                        longestDuration = currentDuration
                        longestStart = currentStart
                    }
                    currentStart = reading.timestamp
                    currentDuration = 5 * 60
                }
            }
        }
        
        // Check final period
        if currentDuration > longestDuration {
            longestDuration = currentDuration
            longestStart = currentStart
        }
        
        guard let start = longestStart else { return nil }
        return (start, longestDuration)
    }
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(), date: Date, stressReadings: [StressMetrics]) {
        self.id = id
        self.date = date.startOfDay
        self.stressReadings = stressReadings.sorted { $0.timestamp < $1.timestamp }
    }
}

// MARK: - Comparable
extension DailyStressSummary: Comparable {
    static func < (lhs: DailyStressSummary, rhs: DailyStressSummary) -> Bool {
        lhs.date < rhs.date
    }
}

extension DailyStressSummary: Equatable {
    static func == (lhs: DailyStressSummary, rhs: DailyStressSummary) -> Bool {
        lhs.id == rhs.id
    }
}
