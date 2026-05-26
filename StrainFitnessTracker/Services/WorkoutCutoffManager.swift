import Foundation
import Combine
import HealthKit

// MARK: - Pending Cutoff Model

/// Represents a workout for which the auto-cutoff algorithm detected a suspected
/// early end that still needs the user's confirmation.
struct PendingWorkoutCutoff: Identifiable, Codable, Equatable {
    /// Stable identity for SwiftUI list diffing and UserDefaults storage.
    let id: UUID
    /// The UUID of the original HKWorkout so we can re-look it up on accept.
    let workoutId: UUID
    /// Raw value of `HKWorkoutActivityType` (Codable-friendly).
    let workoutTypeRaw: UInt
    let startDate: Date
    let originalEndDate: Date
    let suggestedEndDate: Date
    let lowHRStartDate: Date

    // MARK: Computed helpers

    var workoutDate: Date { startDate.startOfDay }
    var minutesTrimmed: Int {
        max(0, Int(originalEndDate.timeIntervalSince(suggestedEndDate) / 60))
    }
    var workoutType: HKWorkoutActivityType {
        HKWorkoutActivityType(rawValue: workoutTypeRaw) ?? .other
    }
}

// MARK: - Manager

/// Central state holder for the workout auto-cutoff confirmation flow.
///
/// When `DataSyncService` detects a potential early cutoff it registers a
/// `PendingWorkoutCutoff` here (if the workout hasn't already been decided).
/// The user is then presented with a confirmation sheet from `DashboardView`.
/// Once the user accepts or rejects, the decision is persisted so the next sync
/// of the same workout applies (or skips) the trim without bothering the user again.
@MainActor
final class WorkoutCutoffManager: ObservableObject {

    static let shared = WorkoutCutoffManager()

    // MARK: - Published State

    /// Workouts waiting for a user decision.  The UI observes this to show a sheet.
    @Published private(set) var pendingCutoffs: [PendingWorkoutCutoff] = []

    // MARK: - Private Storage

    private var acceptedIds: Set<UUID> = []
    private var rejectedIds: Set<UUID> = []

    private let defaults = UserDefaults.standard
    private let pendingKey  = "workoutCutoff.pending"
    private let acceptedKey = "workoutCutoff.accepted"
    private let rejectedKey = "workoutCutoff.rejected"

    // MARK: - Init

    private init() {
        loadFromDefaults()
    }

    // MARK: - Decision Queries

    func isAccepted(_ workoutId: UUID) -> Bool { acceptedIds.contains(workoutId) }
    func isRejected(_ workoutId: UUID) -> Bool { rejectedIds.contains(workoutId) }
    func isPending (_ workoutId: UUID) -> Bool {
        pendingCutoffs.contains { $0.workoutId == workoutId }
    }
    func isUndecided(_ workoutId: UUID) -> Bool {
        !isAccepted(workoutId) && !isRejected(workoutId) && !isPending(workoutId)
    }

    // MARK: - Mutations

    /// Called by `DataSyncService` when it finds a new undecided cutoff.
    func add(_ cutoff: PendingWorkoutCutoff) {
        guard isUndecided(cutoff.workoutId) else { return }
        pendingCutoffs.append(cutoff)
        savePending()
    }

    /// User confirmed the trim — record the decision and remove from pending.
    func accept(_ cutoff: PendingWorkoutCutoff) {
        remove(cutoff)
        acceptedIds.insert(cutoff.workoutId)
        saveAccepted()
    }

    /// User rejected the trim — record the decision and remove from pending.
    func reject(_ cutoff: PendingWorkoutCutoff) {
        remove(cutoff)
        rejectedIds.insert(cutoff.workoutId)
        saveRejected()
    }

    // MARK: - Persistence

    private func remove(_ cutoff: PendingWorkoutCutoff) {
        pendingCutoffs.removeAll { $0.workoutId == cutoff.workoutId }
        savePending()
    }

    private func loadFromDefaults() {
        if let data = defaults.data(forKey: pendingKey),
           let saved = try? JSONDecoder().decode([PendingWorkoutCutoff].self, from: data) {
            pendingCutoffs = saved
        }
        acceptedIds = uuidSet(for: acceptedKey)
        rejectedIds = uuidSet(for: rejectedKey)
    }

    private func savePending() {
        if let data = try? JSONEncoder().encode(pendingCutoffs) {
            defaults.set(data, forKey: pendingKey)
        }
    }

    private func saveAccepted() {
        defaults.set(acceptedIds.map(\.uuidString), forKey: acceptedKey)
    }

    private func saveRejected() {
        defaults.set(rejectedIds.map(\.uuidString), forKey: rejectedKey)
    }

    private func uuidSet(for key: String) -> Set<UUID> {
        let strings = defaults.stringArray(forKey: key) ?? []
        return Set(strings.compactMap { UUID(uuidString: $0) })
    }
}
