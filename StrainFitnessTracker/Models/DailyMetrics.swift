//
//  DailyMetrics.swift
//  StrainFitnessTracker
//
//  Data models for dashboard metrics
//

import Foundation
import SwiftUI

// MARK: - Core Metrics
struct DailyMetrics: Identifiable {
    let id = UUID()
    let date: Date
    
    // Primary Metrics
    var sleepScore: Double // 0-100
    var recoveryScore: Double // 0-100
    var strainScore: Double // 0-21
    
    // Sleep Metrics
    var sleepDuration: TimeInterval // in seconds
    var restorativeSleepPercentage: Double // 0-100
    var sleepEfficiency: Double // 0-100
    var sleepConsistency: Double // 0-100
    var timeInBed: TimeInterval
    var sleepDebt: TimeInterval
    var respiratoryRate: Double // breaths per minute
    
    // Activity Metrics
    var calories: Int
    var steps: Int
    var averageHeartRate: Int
    var restingHeartRate: Int
    var vo2Max: Double
    
    // Stress
    var currentStress: Double // 0-3
    var stressHistory: [StressDataPoint]
    
    // Activities
    var activities: [Activity]
    
    // Health Monitor Status
    var healthMetricsInRange: Int
    var totalHealthMetrics: Int
}

struct Activity: Identifiable {
    let id: UUID
    let type: ActivityType
    let startTime: Date
    let endTime: Date
    let strain: Double?
    let duration: TimeInterval
    
    // Default initializer with auto-generated ID
    init(type: ActivityType, startTime: Date, endTime: Date, strain: Double?, duration: TimeInterval) {
        self.id = UUID()
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.strain = strain
        self.duration = duration
    }
    
    // Initializer with explicit ID (for workout mapping)
    init(id: UUID, type: ActivityType, startTime: Date, endTime: Date, strain: Double?, duration: TimeInterval) {
        self.id = id
        self.type = type
        self.startTime = startTime
        self.endTime = endTime
        self.strain = strain
        self.duration = duration
    }
    
    enum ActivityType: String {
        case sleep = "SLEEP"
        case swimming = "SWIMMING"
        case running = "RUNNING"
        case cycling = "CYCLING"
        case workout = "WORKOUT"
        case walking = "WALKING"
        
        var icon: String {
            switch self {
            case .sleep: return "moon.fill"
            case .swimming: return "figure.pool.swim"
            case .running: return "figure.run"
            case .cycling: return "figure.outdoor.cycle"
            case .workout: return "figure.strengthtraining.traditional"
            case .walking: return "figure.walk"
            }
        }
        
        var color: Color {
            switch self {
            case .sleep: return .sleepBlue
            case .swimming: return .accentBlue
            case .running, .cycling, .workout, .walking: return .strainBlue
            }
        }
    }
    
    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
    
    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: startTime)
        let end = formatter.string(from: endTime)
        
        let calendar = Calendar.current
        let startDay = calendar.component(.day, from: startTime)
        let endDay = calendar.component(.day, from: endTime)
        
        if startDay != endDay {
            formatter.dateFormat = "EEE"
            let dayPrefix = "[\(formatter.string(from: startTime))] "
            return "\(dayPrefix)\(start) - \(end)"
        } else {
            return "\(start) - \(end)"
        }
    }
}

// MARK: - Stress Data
struct StressDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double // 0-3
    let activity: Activity?
    
    var stressLevel: StressLevel {
        switch value {
        case 0..<1.0: return .low
        case 1.0..<2.0: return .medium
        case 2.0...3.0: return .high
        default: return .medium
        }
    }
    
    enum StressLevel: String {
        case low = "LOW"
        case medium = "MEDIUM"
        case high = "HIGH"
        
        var color: Color {
            switch self {
            case .low: return .stressLow
            case .medium: return .stressMedium
            case .high: return .stressHigh
            }
        }
    }
}

// MARK: - Strain & Recovery Weekly Data
struct StrainRecoveryWeekData: Identifiable {
    let id = UUID()
    let weekDays: [DayData]
    
    struct DayData: Identifiable {
        let id = UUID()
        let date: Date
        let strain: Double
        let recovery: Double
        
        var dayLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d"
            return formatter.string(from: date)
        }
        
        var recoveryZone: RecoveryZone {
            switch recovery {
            case 67...100: return .green
            case 34..<67: return .yellow
            case 0..<34: return .red
            default: return .yellow
            }
        }
        
        enum RecoveryZone {
            case green, yellow, red
            
            var color: Color {
                switch self {
                case .green: return .recoveryZoneGreen
                case .yellow: return .recoveryZoneYellow
                case .red: return .recoveryZoneRed
                }
            }
        }
    }
}

// MARK: - Health Metric
struct HealthMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let comparisonValue: String
    let trend: Trend
    let icon: String
    
    enum Trend {
        case up(isPositive: Bool)
        case down(isPositive: Bool)
        case stable
        
        var arrow: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .up(let isPositive), .down(let isPositive):
                return isPositive ? .trendPositive : .trendNegative
            case .stable:
                return .trendNeutral
            }
        }
    }
}

// MARK: - Sample Data
extension DailyMetrics {
    static var sampleData: DailyMetrics {
        let now = Date()
        let calendar = Calendar.current
        
        // Create sample sleep activity
        let sleepStart = calendar.date(byAdding: .hour, value: -11, to: now)!
        let sleepEnd = calendar.date(byAdding: .hour, value: -2, to: now)!
        let sleepActivity = Activity(
            type: .sleep,
            startTime: sleepStart,
            endTime: sleepEnd,
            strain: nil,
            duration: sleepEnd.timeIntervalSince(sleepStart)
        )
        
        // Create sample swimming activity
        let swimStart = calendar.date(byAdding: .hour, value: -1, to: now)!
        let swimEnd = now
        let swimActivity = Activity(
            type: .swimming,
            startTime: swimStart,
            endTime: swimEnd,
            strain: 10.1,
            duration: swimEnd.timeIntervalSince(swimStart)
        )
        
        // Create stress history
        var stressHistory: [StressDataPoint] = []
        for i in stride(from: -720, to: 0, by: 30) {
            let timestamp = calendar.date(byAdding: .minute, value: i, to: now)!
            let hour = calendar.component(.hour, from: timestamp)
            
            // Lower stress during sleep (midnight to 8am)
            let baseStress: Double
            if hour >= 0 && hour < 8 {
                baseStress = Double.random(in: 0.2...0.8)
            } else if hour >= 9 && hour < 11 {
                // Higher during swimming
                baseStress = Double.random(in: 1.8...2.5)
            } else {
                baseStress = Double.random(in: 0.8...1.5)
            }
            
            stressHistory.append(StressDataPoint(
                timestamp: timestamp,
                value: baseStress,
                activity: (hour >= 9 && hour < 11) ? swimActivity : nil
            ))
        }
        
        return DailyMetrics(
            date: now,
            sleepScore: 77,
            recoveryScore: 82,
            strainScore: 10.2,
            sleepDuration: 8 * 3600 + 33 * 60, // 8:33
            restorativeSleepPercentage: 32,
            sleepEfficiency: 76,
            sleepConsistency: 81,
            timeInBed: 11 * 3600 + 18 * 60, // 11:18
            sleepDebt: 16 * 60, // 0:16
            respiratoryRate: 14.0,
            calories: 1625,
            steps: 2140,
            averageHeartRate: 59,
            restingHeartRate: 49,
            vo2Max: 60,
            currentStress: 1.4,
            stressHistory: stressHistory,
            activities: [sleepActivity, swimActivity],
            healthMetricsInRange: 5,
            totalHealthMetrics: 5
        )
    }
}
