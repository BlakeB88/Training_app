//
//  SleepHoursVsNeedView.swift
//  StrainFitnessTracker
//
//  WHOOP-style "Hours vs. Need" sleep chart.
//  Used on the dashboard and in the sleep detail view.
//

import SwiftUI
import Charts

// MARK: - Data Model

struct SleepWeekEntry: Identifiable {
    let id = UUID()
    let date: Date
    let hoursSlept: Double
    let hoursNeeded: Double

    var dayAbbrev: String { date.formatted(.dateTime.weekday(.abbreviated)) }
    var dayNumber:  String { date.formatted(.dateTime.day()) }

    var formattedSlept:  String { formatHours(hoursSlept) }
    var formattedNeeded: String { formatHours(hoursNeeded) }

    private func formatHours(_ h: Double) -> String {
        let hrs  = Int(h)
        let mins = Int((h - Double(hrs)) * 60)
        return "\(hrs):\(String(format: "%02d", mins))"
    }

    /// Research-backed sleep need estimate.
    /// Base 7.5 h + partial debt recovery + strain bonus (max 9.5 h).
    static func sleepNeeded(debt: Double, strain: Double) -> Double {
        let base        = 7.5
        let debtBonus   = min(debt, 3.0) * 0.20    // up to +36 min for 3 h of debt
        let strainBonus = (strain / 21.0) * 0.75   // up to +45 min at max strain
        return min(base + debtBonus + strainBonus, 9.5)
    }
}

// MARK: - Chart View

struct SleepHoursVsNeedView: View {

    let entries: [SleepWeekEntry]

    // Y-axis domain with padding so annotation labels aren't clipped
    private var yMin: Double {
        let vals = entries.flatMap { [$0.hoursSlept, $0.hoursNeeded] }
        return (vals.min() ?? 6.0) - 0.8
    }
    private var yMax: Double {
        let vals = entries.flatMap { [$0.hoursSlept, $0.hoursNeeded] }
        return (vals.max() ?? 9.0) + 0.8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Title
            Text("HOURS VS. NEED")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primaryText)
                .tracking(0.6)

            // Legend
            HStack(spacing: 20) {
                legendDot(color: Color(white: 0.55), label: "HOURS OF SLEEP")
                legendDot(color: .green,             label: "SLEEP NEEDED")
            }

            if entries.isEmpty {
                Text("Not enough data yet")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    // ── Slept line ──
                    ForEach(entries) { e in
                        LineMark(
                            x: .value("Day", e.date, unit: .day),
                            y: .value("Hours", e.hoursSlept),
                            series: .value("Series", "slept")
                        )
                        .foregroundStyle(Color(white: 0.50))
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                        PointMark(
                            x: .value("Day", e.date, unit: .day),
                            y: .value("Hours", e.hoursSlept)
                        )
                        .foregroundStyle(Color(white: 0.55))
                        .symbolSize(50)
                        .annotation(
                            position: e.hoursSlept >= e.hoursNeeded ? .top : .bottom,
                            spacing: 3
                        ) {
                            Text(e.formattedSlept)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Color(white: 0.75))
                        }
                    }

                    // ── Sleep-needed line ──
                    ForEach(entries) { e in
                        LineMark(
                            x: .value("Day", e.date, unit: .day),
                            y: .value("Hours", e.hoursNeeded),
                            series: .value("Series", "needed")
                        )
                        .foregroundStyle(Color.green)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))

                        PointMark(
                            x: .value("Day", e.date, unit: .day),
                            y: .value("Hours", e.hoursNeeded)
                        )
                        .foregroundStyle(Color.green)
                        .symbolSize(50)
                        .annotation(
                            position: e.hoursNeeded > e.hoursSlept ? .top : .bottom,
                            spacing: 3
                        ) {
                            Text(e.formattedNeeded)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                }
                .chartYScale(domain: yMin...yMax)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 1)) { value in
                        AxisGridLine().foregroundStyle(Color.clear)
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                VStack(spacing: 1) {
                                    Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                        .font(.system(size: 10))
                                    Text(date.formatted(.dateTime.day()))
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.secondaryText)
                            }
                        }
                    }
                }
                // Extra vertical padding so the top annotation labels aren't clipped
                .padding(.top, 18)
                .frame(height: 170)
            }
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(color, lineWidth: 1.5)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.3)
        }
    }
}
