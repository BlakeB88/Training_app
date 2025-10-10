//
//  MonitorCardView.swift
//  StrainFitnessTracker
//
//  Health and Stress monitor cards
//

import SwiftUI

struct HealthMonitorCard: View {
    let metricsInRange: Int
    let totalMetrics: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.recoveryGreen.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.recoveryGreen)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("HEALTH MONITOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                
                Text("WITHIN RANGE")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.recoveryGreen)
                    .tracking(0.3)
                
                Text("\(metricsInRange)/\(totalMetrics) Metrics")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

struct StressMonitorCard: View {
    let currentStress: Double
    let lastUpdateTime: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Stress value box
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(stressColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Text(String(format: "%.1f", currentStress))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(stressColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text("STRESS MONITOR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                
                Text(stressLevel.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(stressColor)
                    .tracking(0.3)
                
                Text(lastUpdateTime)
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    private var stressLevel: String {
        if currentStress < 1.0 {
            return "Low"
        } else if currentStress < 2.0 {
            return "Medium"
        } else {
            return "High"
        }
    }
    
    private var stressColor: Color {
        if currentStress < 1.0 {
            return .stressLow
        } else if currentStress < 2.0 {
            return .stressMedium
        } else {
            return .stressHigh
        }
    }
}

struct DailyOutlookCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // App icon
            ZStack {
                Circle()
                    .fill(Color.cardBackground.opacity(0.5))
                    .frame(width: 44, height: 44)
                
                Text("W")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentBlue)
            }
            
            // Content
            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.warningOrange)
                
                Text("Your Daily Outlook")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}


