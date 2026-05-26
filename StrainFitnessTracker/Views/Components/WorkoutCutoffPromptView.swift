import SwiftUI
import HealthKit

// MARK: - Workout Cutoff Prompt Sheet

/// A bottom sheet that asks the user whether to trim a workout whose heart rate
/// stayed below the threshold for an extended period.
///
/// The caller is responsible for:
///  - Presenting this view as a `.sheet(item:)`
///  - Calling `WorkoutCutoffManager.shared.accept/reject` via the callbacks
struct WorkoutCutoffPromptView: View {
    let cutoff: PendingWorkoutCutoff
    /// Invoked when the user chooses to trim.  The caller should re-sync the
    /// relevant day so the trimmed strain is reflected immediately.
    var onAccept: () -> Void = {}
    /// Invoked when the user keeps the full workout.
    var onReject: () -> Void = {}
    /// Invoked when the user taps "Decide Later" (no decision stored).
    var onDismiss: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                dragHandle

                ScrollView {
                    VStack(spacing: 20) {
                        headerSection
                        workoutInfoCard
                        cutoffDetailsCard
                        actionButtons
                        decideLatButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden) // we draw our own
    }

    // MARK: - Subviews

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(white: 0.4))
            .frame(width: 36, height: 5)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            // Warning icon
            ZStack {
                Circle()
                    .fill(Color.warningOrange.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.warningOrange)
            }
            .padding(.top, 8)

            Text("Workout Ended Early?")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)

            Text("Your heart rate stayed low for an extended period near the end of this workout. It may have ended naturally before you stopped the recording.")
                .font(.system(size: 14))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }

    private var workoutInfoCard: some View {
        HStack(spacing: 14) {
            // Workout type icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.strainBlue.opacity(0.15))
                    .frame(width: 48, height: 48)

                Text(cutoff.workoutType.emoji)
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(cutoff.workoutType.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)

                Text(cutoff.startDate, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)

                Text("\(timeString(cutoff.startDate)) – \(timeString(cutoff.originalEndDate))")
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private var cutoffDetailsCard: some View {
        VStack(spacing: 14) {
            // Dividing rows
            detailRow(
                icon: "waveform.path.ecg",
                iconColor: .stressHigh,
                label: "Low HR detected at",
                value: timeString(cutoff.lowHRStartDate)
            )

            Divider().background(Color.secondaryCardBackground)

            detailRow(
                icon: "clock.badge.checkmark",
                iconColor: .recoveryGreen,
                label: "Suggested end time",
                value: timeString(cutoff.suggestedEndDate)
            )

            Divider().background(Color.secondaryCardBackground)

            detailRow(
                icon: "scissors",
                iconColor: .warningOrange,
                label: "Time that would be trimmed",
                value: "\(cutoff.minutesTrimmed) min"
            )
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary — trim
            Button {
                WorkoutCutoffManager.shared.accept(cutoff)
                dismiss()
                onAccept()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "scissors")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Yes, Trim Workout")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.warningOrange)
                .cornerRadius(14)
            }

            // Secondary — keep full
            Button {
                WorkoutCutoffManager.shared.reject(cutoff)
                dismiss()
                onReject()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Keep Full Workout")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.secondaryCardBackground)
                .cornerRadius(14)
            }
        }
    }

    private var decideLatButton: some View {
        Button {
            dismiss()
            onDismiss()
        } label: {
            Text("Decide Later")
                .font(.system(size: 14))
                .foregroundColor(.tertiaryText)
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func detailRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondaryText)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primaryText)
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
}

// MARK: - Preview

#if DEBUG
struct WorkoutCutoffPromptView_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let cutoff = PendingWorkoutCutoff(
            id: UUID(),
            workoutId: UUID(),
            workoutTypeRaw: HKWorkoutActivityType.running.rawValue,
            startDate: now.addingTimeInterval(-3600),
            originalEndDate: now,
            suggestedEndDate: now.addingTimeInterval(-900),
            lowHRStartDate: now.addingTimeInterval(-1200)
        )
        WorkoutCutoffPromptView(cutoff: cutoff)
            .preferredColorScheme(.dark)
    }
}
#endif
