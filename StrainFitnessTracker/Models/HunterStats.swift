import Foundation
import SwiftUI

// MARK: - Rank + Category Definitions
enum HunterRank: String, CaseIterable, Comparable, Codable {
    case E
    case D
    case C
    case B
    case A
    case S
    case SPlus

    var displayName: String {
        switch self {
        case .SPlus:
            return "S+"
        default:
            return rawValue
        }
    }

    var minimumScore: Double {
        switch self {
        case .E: return 0
        case .D: return 10
        case .C: return 25
        case .B: return 40
        case .A: return 55
        case .S: return 70
        case .SPlus: return 90
        }
    }

    var color: Color {
        switch self {
        case .E: return .dangerRed
        case .D: return .warningOrange
        case .C: return .accentBlue.opacity(0.7)
        case .B: return .accentBlue
        case .A: return .recoveryGreen
        case .S: return .recoveryGreen
        case .SPlus: return Color.purple
        }
    }

    static func rank(for score: Double) -> HunterRank {
        if score >= HunterRank.SPlus.minimumScore { return .SPlus }
        if score >= HunterRank.S.minimumScore { return .S }
        if score >= HunterRank.A.minimumScore { return .A }
        if score >= HunterRank.B.minimumScore { return .B }
        if score >= HunterRank.C.minimumScore { return .C }
        if score >= HunterRank.D.minimumScore { return .D }
        return .E
    }

    static func < (lhs: HunterRank, rhs: HunterRank) -> Bool {
        lhs.minimumScore < rhs.minimumScore
    }

    var nextRank: HunterRank? {
        let ordered: [HunterRank] = [.E, .D, .C, .B, .A, .S, .SPlus]
        guard let idx = ordered.firstIndex(of: self), idx < ordered.count - 1 else {
            return nil
        }
        return ordered[idx + 1]
    }
}

enum HunterStatCategory: String, CaseIterable, Identifiable {
    case vitality
    case strength
    case endurance
    case agility
    case physique
    case metabolicPower
    case swimMastery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vitality: return "Vitality"
        case .strength: return "Strength"
        case .endurance: return "Endurance"
        case .agility: return "Agility"
        case .physique: return "Physique"
        case .metabolicPower: return "Metabolic Power"
        case .swimMastery: return "Swim Mastery"
        }
    }

    var icon: String {
        switch self {
        case .vitality: return "heart.circle.fill"
        case .strength: return "bolt.circle.fill"
        case .endurance: return "figure.run.circle"
        case .agility: return "hare.fill"
        case .physique: return "figure.stand"
        case .metabolicPower: return "flame.fill"
        case .swimMastery: return "figure.pool.swim"
        }
    }

    var accentColor: Color {
        switch self {
        case .vitality: return .sleepBlue
        case .strength: return .strainBlue
        case .endurance: return .accentBlue
        case .agility: return .recoveryGreen
        case .physique: return .warningOrange
        case .metabolicPower: return .dangerRed
        case .swimMastery: return Color.cyan
        }
    }
}

// MARK: - Stat Models
struct HunterStat: Identifiable {
    let id = UUID()
    let category: HunterStatCategory
    let score: Double
    let rank: HunterRank
    let explanation: String
    let positives: [String]
    let negatives: [String]
    let trend: StatTrend
    let nextRankHint: String?
}

struct StatTrend {
    enum Direction {
        case up
        case down
        case flat

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .flat: return "equal"
            }
        }

        var color: Color {
            switch self {
            case .up: return .trendPositive
            case .down: return .trendNegative
            case .flat: return .trendNeutral
            }
        }
    }

    let direction: Direction
    let delta: Double
}

struct DailyModifier: Identifiable {
    enum ModifierType {
        case recoveryBuff
        case strainBuff
        case sleepBuff
        case penalty
    }

    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let modifierType: ModifierType
    let targetStat: HunterStatCategory
    let scoreImpact: Double
}

struct HunterXPState {
    var level: Int
    var currentXP: Int
    var xpToNextLevel: Int
    var earnedToday: Int

    var progress: Double {
        guard xpToNextLevel > 0 else { return 1.0 }
        return min(Double(currentXP) / Double(xpToNextLevel), 1.0)
    }
}

struct HunterStatsSnapshot {
    let statCards: [HunterStat]
    let hunterRank: HunterRank
    let xpState: HunterXPState
    let dailyModifiers: [DailyModifier]
    let swimPerformances: [SwimEventPerformance]
    let swimMasteryScore: Double
    let swimMasteryRank: HunterRank
    let overallPerformanceIndex: Double
    let consistencyStreak: Int
    let dailyScore: Double
    let awakenStateActive: Bool
}

// MARK: - Swim Models
struct SwimEventDefinition: Identifiable, Hashable {
    let distance: Double // meters
    let displayName: String
    let worldRecordSeconds: TimeInterval

    var id: Double { distance }

    static let catalog: [SwimEventDefinition] = [
        SwimEventDefinition(distance: 50, displayName: "50m Freestyle", worldRecordSeconds: 20.91),
        SwimEventDefinition(distance: 100, displayName: "100m Freestyle", worldRecordSeconds: 46.86),
        SwimEventDefinition(distance: 200, displayName: "200m Freestyle", worldRecordSeconds: 102.0),
        SwimEventDefinition(distance: 400, displayName: "400m Freestyle", worldRecordSeconds: 220.07),
        SwimEventDefinition(distance: 800, displayName: "800m Freestyle", worldRecordSeconds: 452.35),
        SwimEventDefinition(distance: 1500, displayName: "1500m Freestyle", worldRecordSeconds: 870.95)
    ]

    static func closestMatch(for distance: Double) -> SwimEventDefinition? {
        return catalog.min(by: { abs($0.distance - distance) < abs($1.distance - distance) })
    }
}

struct SwimEventInput {
    let definition: SwimEventDefinition
    let personalRecordSeconds: TimeInterval
    let recordDate: Date
}

struct SwimEventPerformance: Identifiable {
    let id = UUID()
    let definition: SwimEventDefinition
    let personalRecordSeconds: TimeInterval
    let performanceIndex: Double
    let rank: HunterRank
    let recordDate: Date
    let progressToNextRank: Double

    var displayDistance: String { definition.displayName }

    var personalRecordFormatted: String {
        personalRecordSeconds.formattedTime()
    }

    var worldRecordFormatted: String {
        definition.worldRecordSeconds.formattedTime()
    }
}

// MARK: - Body Composition Inputs
struct BodyCompositionInputs {
    var weight: Double
    var bodyFatPercentage: Double
    var visceralFat: Double
    var subcutaneousFatPercentage: Double
    var muscleMass: Double
    var fatFreeMass: Double
    var bodyWaterPercentage: Double
    var boneMass: Double
    var bmi: Double
    var bmr: Double
    var metabolicAge: Double
    var proteinPercentage: Double
}

struct HunterStatsInputs {
    let metricsHistory: [SimpleDailyMetrics]
    let bodyComposition: BodyCompositionInputs
    let swimEventPRs: [SwimEventInput]
    let xpState: HunterXPState
}

// MARK: - Helpers
extension TimeInterval {
    func formattedTime() -> String {
        let secondsInt = Int(self.rounded())
        let hours = secondsInt / 3600
        let minutes = (secondsInt % 3600) / 60
        let seconds = secondsInt % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
