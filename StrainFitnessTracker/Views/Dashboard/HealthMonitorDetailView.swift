//
//  HealthMonitorDetailView.swift
//  StrainFitnessTracker
//
//  Detail view for the Health Monitor card.
//  Shows only the 5 metrics that feed the "x/5 in range" score.
//

import SwiftUI

struct HealthMonitorDetailView: View {
    let metricsInRange: Int
    let totalMetrics: Int
    /// Exactly the 5 metrics that were evaluated by calculateMetricsInRange.
    let metrics: [HealthMetric]

    private var fraction: Double {
        guard totalMetrics > 0 else { return 0 }
        return Double(metricsInRange) / Double(totalMetrics)
    }

    private var statusColor: Color {
        if fraction >= 0.8 { return .recoveryGreen }
        else if fraction >= 0.6 { return .warningOrange }
        else { return .stressHigh }
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    metricsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Health Monitor")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primaryText)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("METRICS IN RANGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondaryText)
                        .tracking(1)

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(metricsInRange)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)

                        Text("/ \(totalMetrics)")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.secondaryText)
                    }

                    Text(statusLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusColor)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.secondaryCardBackground, lineWidth: 10)

                    Circle()
                        .trim(from: 0, to: CGFloat(fraction))
                        .stroke(
                            statusColor,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut, value: fraction)

                    Text("\(Int(fraction * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                }
                .frame(width: 72, height: 72)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondaryCardBackground)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(statusColor)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                        .animation(.easeOut, value: fraction)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Metrics Section

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TRACKED METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(1)

            VStack(spacing: 10) {
                ForEach(metrics) { metric in
                    inRangeMetricRow(metric)
                }
            }
        }
    }

    /// Wraps a MetricCardView with a colored left border:
    ///   green  = in range (positive trend)
    ///   red    = out of range (negative trend)
    ///   gray   = cannot evaluate yet (.stable / no baseline)
    @ViewBuilder
    private func inRangeMetricRow(_ metric: HealthMetric) -> some View {
        let borderColor: Color = {
            switch metric.trend {
            case .up(let pos), .down(let pos): return pos ? .recoveryGreen : .stressHigh
            case .stable: return Color(white: 0.35) // neutral — baseline not yet established
            }
        }()

        HStack(spacing: 0) {
            // Left border pill
            RoundedRectangle(cornerRadius: 2)
                .fill(borderColor)
                .frame(width: 4)

            MetricCardView(metric: metric)
                // Override the card's own corner radius on the left so the pill sits flush
                .clipShape(
                    RoundedCornerShape(
                        radius: 16,
                        corners: [.topRight, .bottomRight]
                    )
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private var statusLabel: String {
        if metricsInRange == totalMetrics { return "All tracked metrics in range" }
        else if fraction >= 0.6 { return "Most metrics look good" }
        else { return "Several metrics need attention" }
    }
}

// MARK: - Helper Shape

/// A `Shape` that applies corner radius only to specific corners.
private struct RoundedCornerShape: Shape {
    let radius: CGFloat
    let corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
