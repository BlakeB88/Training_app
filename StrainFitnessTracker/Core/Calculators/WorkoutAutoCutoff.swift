import Foundation
import HealthKit

struct WorkoutAutoCutoff {
    static let lowHeartRateThreshold = 120.0
    static let sustainedLowHeartRateDuration: TimeInterval = 10 * 60
    static let recoveryBuffer: TimeInterval = 5 * 60

    static func effectiveEndDate(
        for workout: HKWorkout,
        heartRateSamples: [(date: Date, heartRate: Double)]
    ) -> Date? {
        guard !heartRateSamples.isEmpty else { return nil }

        let sortedSamples = heartRateSamples.sorted { $0.date < $1.date }
        var lowHeartRateStart: Date?

        for sample in sortedSamples {
            guard sample.date >= workout.startDate && sample.date <= workout.endDate else {
                continue
            }

            if sample.heartRate < lowHeartRateThreshold {
                if lowHeartRateStart == nil {
                    lowHeartRateStart = sample.date
                }

                if let lowHeartRateStart,
                   sample.date.timeIntervalSince(lowHeartRateStart) >= sustainedLowHeartRateDuration {
                    let bufferedEndDate = lowHeartRateStart.addingTimeInterval(recoveryBuffer)
                    guard bufferedEndDate < workout.endDate else { return nil }
                    return max(bufferedEndDate, workout.startDate)
                }
            } else {
                lowHeartRateStart = nil
            }
        }

        return nil
    }
}
