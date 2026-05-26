import Foundation
import HealthKit

// MARK: - Detection Result

/// Returned when the auto-cutoff algorithm finds a sustained low-HR period.
struct CutoffDetection {
    /// The recommended workout end time (5 min after HR first dropped).
    let suggestedEndDate: Date
    /// The timestamp when heart rate first fell below the threshold.
    let lowHRStartDate: Date
}

// MARK: - Auto Cutoff

struct WorkoutAutoCutoff {
    /// Heart rate below this value (bpm) is considered "low" for this workout type.
    static let lowHeartRateThreshold = 95.0
    /// How long HR must stay below the threshold before a cutoff is suggested.
    static let sustainedLowHeartRateDuration: TimeInterval = 10 * 60  // 10 min
    /// Buffer added after the low-HR start to produce the suggested end time.
    static let recoveryBuffer: TimeInterval = 5 * 60                   // 5 min

    /// Returns a `CutoffDetection` if a sustained low-HR period is found,
    /// `nil` if the full workout duration looks legitimate.
    static func detectCutoff(
        for workout: HKWorkout,
        heartRateSamples: [(date: Date, heartRate: Double)]
    ) -> CutoffDetection? {
        guard !heartRateSamples.isEmpty else { return nil }

        let sortedSamples = heartRateSamples.sorted { $0.date < $1.date }
        var lowHRStart: Date?

        for sample in sortedSamples {
            guard sample.date >= workout.startDate && sample.date <= workout.endDate else { continue }

            if sample.heartRate < lowHeartRateThreshold {
                if lowHRStart == nil { lowHRStart = sample.date }

                if let start = lowHRStart,
                   sample.date.timeIntervalSince(start) >= sustainedLowHeartRateDuration {
                    let suggested = start.addingTimeInterval(recoveryBuffer)
                    guard suggested < workout.endDate else { return nil }
                    return CutoffDetection(
                        suggestedEndDate: max(suggested, workout.startDate),
                        lowHRStartDate: start
                    )
                }
            } else {
                lowHRStart = nil
            }
        }
        return nil
    }
}
