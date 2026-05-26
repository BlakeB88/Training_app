//
//  MonitorCardView.swift
//  StrainFitnessTracker
//
//  Health and Stress monitor cards — full-width, tappable
//

import SwiftUI

// MARK: - Health Monitor Card

struct HealthMonitorCard: View {
    let metricsInRange: Int
    let totalMetrics: Int

    private var fraction: Double {
        guard totalMetrics > 0 else { return 0 }
        return Double(metricsInRange) / Double(totalMetrics)
    }

    private var statusText: String {
        if metricsInRange == totalMetrics { return "ALL IN RANGE" }
        else if fraction >= 0.6 { return "MOSTLY NORMAL" }
        else { return "NEEDS ATTENTION" }
    }

    private var statusColor: Color {
        if fraction >= 0.8 { return .recoveryGreen }
        else if fraction >= 0.6 { return .warningOrange }
        else { return .stressHigh }
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: fraction >= 0.8 ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(statusColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("HEALTH MONITOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.8)

                Text(statusText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(statusColor)

                Text("\(metricsInRange) of \(totalMetrics) metrics in range")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }

            Spacer()

            // Progress ring + chevron
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.secondaryCardBackground, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(fraction))
                        .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: fraction)
                }
                .frame(width: 28, height: 28)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

// MARK: - Stress Monitor Card

struct StressMonitorCard: View {
    let currentStress: Double
    let lastUpdateTime: String

    var body: some View {
        HStack(spacing: 16) {
            // Stress value box
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(stressColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Text(String(format: "%.1f", currentStress))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(stressColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("STRESS MONITOR")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.8)

                Text(stressLevel.uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(stressColor)

                Text(lastUpdateTime.isEmpty ? "Tap to view details" : "Updated \(lastUpdateTime)")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            // Stacked bar indicator + chevron
            VStack(spacing: 6) {
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(barColor(for: i))
                            .frame(width: 6, height: 10 + CGFloat(i) * 5)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private var stressLevel: String {
        if currentStress < 1.0 { return "Low" }
        else if currentStress < 2.0 { return "Medium" }
        else { return "High" }
    }

    private var stressColor: Color {
        if currentStress < 1.0 { return .stressLow }
        else if currentStress < 2.0 { return .stressMedium }
        else { return .stressHigh }
    }

    private func barColor(for index: Int) -> Color {
        let level = currentStress
        switch index {
        case 0: return level >= 0 ? (level < 1.0 ? stressColor : .stressLow.opacity(0.25)) : .stressLow.opacity(0.25)
        case 1: return level >= 1.0 ? (level < 2.0 ? stressColor : .stressMedium.opacity(0.25)) : .stressMedium.opacity(0.25)
        default: return level >= 2.0 ? stressColor : .stressHigh.opacity(0.25)
        }
    }
}

// MARK: - Daily Outlook Card

struct DailyOutlookCard: View {
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.cardBackground.opacity(0.5))
                    .frame(width: 44, height: 44)

                Text("W")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentBlue)
            }

            HStack(spacing: 8) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.warningOrange)

                Text("Your Daily Outlook")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}
