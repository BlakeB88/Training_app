//
//  PerformanceWidgetView.swift
//  StrainFitnessTracker
//
//  Large dashboard widget highlighting the day's primary metrics and hunter rank
//

import SwiftUI

struct PerformanceWidgetView: View {
    let metrics: DailyMetrics
    let hunterRank: HunterRank?
    let hunterScore: Double?
    let lastUpdatedText: String

    fileprivate struct RingMetric: Identifiable {
        let id = UUID()
        let title: String
        let value: Double
        let maxValue: Double
        let color: Color
        let showsPercentage: Bool
    }

    private var ringMetrics: [RingMetric] {
        [
            RingMetric(title: "Sleep", value: metrics.sleepScore, maxValue: 100, color: .sleepBlue, showsPercentage: true),
            RingMetric(title: "Recovery", value: metrics.recoveryScore, maxValue: 100, color: .recoveryGreen, showsPercentage: true),
            RingMetric(title: "Strain", value: metrics.strainScore, maxValue: AppConstants.Strain.maxValue, color: .strainBlue, showsPercentage: false)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PERFORMANCE SNAPSHOT")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .tracking(1.2)
                Spacer()
                Text("Updated \(lastUpdatedText)")
                    .font(.footnote)
                    .foregroundColor(.tertiaryText)
            }

            HStack(alignment: .center, spacing: 18) {
                HStack(spacing: 18) {
                    ForEach(ringMetrics) { metric in
                        PerformanceRingMetricView(metric: metric)
                    }
                }

                Spacer(minLength: 12)

                rankView
            }

            Text(rankDescription)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primaryText)

            Text(scoreDescription)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color.secondaryCardBackground, Color.cardBackground.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 0, y: 10)
    }

    private var rankView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(rankColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Circle()
                            .stroke(rankColor.opacity(0.6), lineWidth: 4)
                    )

                Text(rankDisplay)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
            }

            Text("Hunter rank")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondaryText)
        }
    }
}

private extension PerformanceWidgetView {
    var rankDisplay: String {
        hunterRank?.displayName ?? "--"
    }

    var rankColor: Color {
        hunterRank?.color ?? Color.secondaryText
    }

    var rankDescription: String {
        hunterRank?.tagline ?? "Sync hunter stats to reveal your rank."
    }

    var scoreDescription: String {
        if let score = hunterScore {
            return "Hunter score \(Int(score.rounded()))"
        }
        return "Hunter score unavailable"
    }
}

private struct PerformanceRingMetricView: View {
    let metric: PerformanceWidgetView.RingMetric

    private var progress: Double {
        guard metric.maxValue > 0 else { return 0 }
        return min(max(metric.value / metric.maxValue, 0), 1)
    }

    private var displayValue: String {
        if metric.showsPercentage {
            return "\(Int(metric.value))%"
        }
        return String(format: "%.1f", metric.value)
    }

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 10)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        metric.color,
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.easeInOut(duration: 0.8), value: progress)

                Text(displayValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
            }

            Text(metric.title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondaryText)
                .tracking(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) score")
        .accessibilityValue(displayValue)
    }
}
