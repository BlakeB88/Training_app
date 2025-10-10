//
//  MetricCardView.swift
//  StrainFitnessTracker
//
//  Reusable metric card component
//

import SwiftUI

struct MetricCardView: View {
    let metric: HealthMetric
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: metric.icon)
                .font(.system(size: 24))
                .foregroundColor(.secondaryText)
                .frame(width: 40, height: 40)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.name.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(metric.value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                    
                    Text(metric.comparisonValue)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            // Trend indicator
            VStack {
                Image(systemName: metric.trend.arrow)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(metric.trend.color))
            }
            .frame(width: 30)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Convenience Initializers
extension HealthMetric {
    static func respiratoryRate(value: Double, baseline: Double) -> HealthMetric {
        _ = value < baseline // Lower is better for respiratory rate
        let trend: Trend = value < baseline ? .down(isPositive: true) :
                          value > baseline ? .up(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Respiratory Rate",
            value: String(format: "%.1f", value),
            comparisonValue: String(format: "%.1f", baseline),
            trend: trend,
            icon: "lungs.fill"
        )
    }
    
    static func sleepEfficiency(value: Double, baseline: Double) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Sleep Efficiency",
            value: "\(Int(value))%",
            comparisonValue: "\(Int(baseline))%",
            trend: trend,
            icon: "chart.bar.fill"
        )
    }
    
    static func sleepConsistency(value: Double, baseline: Double) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Sleep Consistency",
            value: "\(Int(value))%",
            comparisonValue: "\(Int(baseline))%",
            trend: trend,
            icon: "circle.hexagonpath.fill"
        )
    }
    
    static func timeInBed(value: TimeInterval, baseline: TimeInterval) -> HealthMetric {
        let hours = Int(value) / 3600
        let minutes = (Int(value) % 3600) / 60
        let baselineHours = Int(baseline) / 3600
        let baselineMinutes = (Int(baseline) % 3600) / 60
        
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Time in Bed",
            value: "\(hours):\(String(format: "%02d", minutes))",
            comparisonValue: "\(baselineHours):\(String(format: "%02d", baselineMinutes))",
            trend: trend,
            icon: "bed.double.fill"
        )
    }
    
    static func sleepDebt(value: TimeInterval, baseline: TimeInterval) -> HealthMetric {
        let hours = Int(value) / 3600
        let minutes = (Int(value) % 3600) / 60
        let baselineHours = Int(baseline) / 3600
        let baselineMinutes = (Int(baseline) % 3600) / 60
        
        _ = value < baseline // Lower debt is better
        let trend: Trend = value < baseline ? .down(isPositive: true) :
                          value > baseline ? .up(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Sleep Debt",
            value: "\(hours):\(String(format: "%02d", minutes))",
            comparisonValue: "\(baselineHours):\(String(format: "%02d", baselineMinutes))",
            trend: trend,
            icon: "moon.zzz.fill"
        )
    }
    
    static func restorativeSleep(value: Double, baseline: Double) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Restorative Sleep (%)",
            value: "\(Int(value))%",
            comparisonValue: "\(Int(baseline))%",
            trend: trend,
            icon: "moon.circle.fill"
        )
    }
    
    static func vo2Max(value: Double, baseline: Double) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "VO₂ Max",
            value: "\(Int(value))",
            comparisonValue: "\(Int(baseline))",
            trend: trend,
            icon: "wind"
        )
    }
    
    static func averageHeartRate(value: Int, baseline: Int) -> HealthMetric {
        let trend: Trend = value > baseline ? .up(isPositive: false) :
                          value < baseline ? .down(isPositive: true) : .stable
        
        return HealthMetric(
            name: "Average Heart Rate",
            value: "\(value)",
            comparisonValue: "\(baseline)",
            trend: trend,
            icon: "heart.fill"
        )
    }
    
    static func steps(value: Int, baseline: Int) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Steps (Beta)",
            value: "\(value)",
            comparisonValue: "\(baseline)",
            trend: trend,
            icon: "figure.walk"
        )
    }
    
    static func restingHeartRate(value: Int, baseline: Int) -> HealthMetric {
        let trend: Trend = value > baseline ? .up(isPositive: false) :
                          value < baseline ? .down(isPositive: true) : .stable
        
        return HealthMetric(
            name: "Resting Heart Rate",
            value: "\(value)",
            comparisonValue: "\(baseline)",
            trend: trend,
            icon: "heart.circle.fill"
        )
    }
    
    static func calories(value: Int, baseline: Int) -> HealthMetric {
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Calories",
            value: "\(value)",
            comparisonValue: "\(baseline)",
            trend: trend,
            icon: "flame.fill"
        )
    }
    
    static func hoursOfSleep(value: TimeInterval, baseline: TimeInterval) -> HealthMetric {
        let hours = Int(value) / 3600
        let minutes = (Int(value) % 3600) / 60
        let baselineHours = Int(baseline) / 3600
        let baselineMinutes = (Int(baseline) % 3600) / 60
        
        _ = value > baseline
        let trend: Trend = value > baseline ? .up(isPositive: true) :
                          value < baseline ? .down(isPositive: false) : .stable
        
        return HealthMetric(
            name: "Hours of Sleep",
            value: "\(hours):\(String(format: "%02d", minutes))",
            comparisonValue: "\(baselineHours):\(String(format: "%02d", baselineMinutes))",
            trend: trend,
            icon: "moon.stars.fill"
        )
    }
}



