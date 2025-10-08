//
//  RecoveryCardView.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import SwiftUI

struct RecoveryCardView: View {
    let recovery: Double?
    let components: RecoveryComponents?
    let compact: Bool

    init(
        recovery: Double?,
        components: RecoveryComponents? = nil,
        compact: Bool = false
    ) {
        self.recovery = recovery
        self.components = components
        self.compact = compact
    }

    private var recoveryColor: Color {
        guard let recovery = recovery else { return .gray }

        switch recovery {
        case AppConstants.Recovery.excellentMin...:
            return .green
        case AppConstants.Recovery.goodMin..<AppConstants.Recovery.excellentMin:
            return .blue
        case AppConstants.Recovery.fairMin..<AppConstants.Recovery.goodMin:
            return .yellow
        default:
            return .red
        }
    }

    private var recoveryLevel: String {
        guard let recovery = recovery else { return "No Data" }

        switch recovery {
        case AppConstants.Recovery.excellentMin...:
            return "Excellent"
        case AppConstants.Recovery.goodMin..<AppConstants.Recovery.excellentMin:
            return "Good"
        case AppConstants.Recovery.fairMin..<AppConstants.Recovery.goodMin:
            return "Fair"
        default:
            return "Poor"
        }
    }

    private var recoveryIcon: String {
        guard let recovery = recovery else { return "heart.slash" }

        switch recovery {
        case AppConstants.Recovery.excellentMin...:
            return "heart.circle.fill"
        case AppConstants.Recovery.goodMin..<AppConstants.Recovery.excellentMin:
            return "heart.fill"
        case AppConstants.Recovery.fairMin..<AppConstants.Recovery.goodMin:
            return "heart"
        default:
            return "heart.slash.fill"
        }
    }

    var body: some View {
        if compact {
            compactView
        } else {
            fullView
        }
    }

    // MARK: - Compact View
    private var compactView: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: recoveryIcon)
                .font(.title2)
                .foregroundColor(recoveryColor)
                .frame(width: 40, height: 40)
                .background(recoveryColor.opacity(0.1))
                .clipShape(Circle())

            // Recovery info
            VStack(alignment: .leading, spacing: 2) {
                Text("Recovery")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let recovery = recovery {
                    Text("\(Int(recovery))%")
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                } else {
                    Text("--")
                        .font(.title3.bold())
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Level badge
            Text(recoveryLevel)
                .font(.caption.bold())
                .foregroundColor(recoveryColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(recoveryColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Full View
    private var fullView: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recovery")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if let recovery = recovery {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(recovery))")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)

                            Text("%")
                                .font(.title2.bold())
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status indicator
                VStack(spacing: 8) {
                    Image(systemName: recoveryIcon)
                        .font(.system(size: 40))
                        .foregroundColor(recoveryColor)

                    Text(recoveryLevel)
                        .font(.caption.bold())
                        .foregroundColor(recoveryColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(recoveryColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }

            // Progress bar
            if let recovery = recovery {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))

                        // Progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(recoveryColor)
                            .frame(width: geometry.size.width * (recovery / 100))
                            .animation(.easeInOut(duration: 0.5), value: recovery)
                    }
                }
                .frame(height: 8)
            }

            // Components breakdown
            if let components = components {
                Divider()

                VStack(spacing: 12) {
                    ComponentRow(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        score: components.hrvScore ?? 0,
                        color: scoreColor(components.hrvScore ?? 0)
                    )

                    ComponentRow(
                        icon: "heart.fill",
                        label: "Resting HR",
                        score: components.restingHRScore ?? 0,
                        color: scoreColor(components.restingHRScore ?? 0)
                    )

                    ComponentRow(
                        icon: "bed.double.fill",
                        label: "Sleep",
                        score: components.sleepScore ?? 0,
                        color: scoreColor(components.sleepScore ?? 0)
                    )

                    if let rrScore = components.respiratoryRateScore {
                        ComponentRow(
                            icon: "lungs.fill",
                            label: "Respiratory",
                            score: rrScore,
                            color: scoreColor(rrScore)
                        )
                    }
                }
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: - Helper Views
    private struct ComponentRow: View {
        let icon: String
        let label: String
        let score: Double
        let color: Color

        var body: some View {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.gray.opacity(0.2))

                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * (score / 100))
                    }
                }
                .frame(width: 60, height: 6)

                Text("\(Int(score))")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 80...:
            return .green
        case 60..<80:
            return .blue
        case 40..<60:
            return .yellow
        default:
            return .red
        }
    }
}

// MARK: - Preview
#Preview("Recovery Card Variations") {
    ScrollView {
        VStack(spacing: 20) {
            // Compact versions
            VStack(spacing: 12) {
                RecoveryCardView(recovery: 92, compact: true)
                RecoveryCardView(recovery: 75, compact: true)
                RecoveryCardView(recovery: 55, compact: true)
                RecoveryCardView(recovery: 35, compact: true)
                RecoveryCardView(recovery: nil, compact: true)
            }
            .padding()

            Divider()

            // Full version with components
            RecoveryCardView(
                recovery: 85,
                components: RecoveryComponents(
                    hrvScore: 88,
                    restingHRScore: 82,
                    sleepScore: 90,
                    respiratoryRateScore: 75
                )
            )
            .padding()

            // Full version without components
            RecoveryCardView(recovery: 72)
                .padding()

            // No data
            RecoveryCardView(recovery: nil)
                .padding()
        }
    }
    .background(Color(red: 0.95, green: 0.95, blue: 0.97))
}
