import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct StrainWidgetEntry: TimelineEntry {
    let date: Date
    let recovery: Int?      // 0–100
    let strain: Int?        // 0–100 (normalized, used for ring progress)
    let strainRaw: Double?  // 0–21  (displayed as label, matches dashboard)
    let sleepScore: Int?    // 0–100 (displayed as %, matches dashboard ring)
    let sleepHours: Double? // e.g. 7.5 (fallback label if no score)
    let rank: String?       // "E", "D", "C", "B", "A", "S", "S+", "National"

    var hasData: Bool { recovery != nil || strain != nil }

    static var placeholder: StrainWidgetEntry {
        StrainWidgetEntry(
            date: Date(),
            recovery: 93, strain: 72, strainRaw: 15.1,
            sleepScore: 96, sleepHours: 7.5, rank: "S"
        )
    }

    static var empty: StrainWidgetEntry {
        StrainWidgetEntry(
            date: Date(),
            recovery: nil, strain: nil, strainRaw: nil,
            sleepScore: nil, sleepHours: nil, rank: nil
        )
    }
}

// MARK: - Timeline Provider

struct StrainWidgetProvider: TimelineProvider {
    private let groupID = "group.com.blake.StrainFitnessTracker"

    func placeholder(in context: Context) -> StrainWidgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StrainWidgetEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StrainWidgetEntry>) -> Void) {
        let entry = currentEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    // MARK: - Private

    private func currentEntry() -> StrainWidgetEntry {
        guard let defaults = UserDefaults(suiteName: groupID) else { return .empty }

        let recovery   = defaults.integer(forKey: "shared_recovery")
        let strain     = defaults.integer(forKey: "shared_strain")
        let strainRaw  = defaults.double(forKey: "shared_strain_raw")
        let sleepScore = defaults.integer(forKey: "shared_sleep_score")
        let sleepHours = defaults.double(forKey: "shared_sleep")
        let rank       = defaults.string(forKey: "shared_rank")
        let lastUpdate = defaults.object(forKey: "shared_last_update") as? Date ?? Date()

        return StrainWidgetEntry(
            date:       lastUpdate,
            recovery:   recovery   > 0 ? recovery   : nil,
            strain:     strain     > 0 ? strain     : nil,
            strainRaw:  strainRaw  > 0 ? strainRaw  : nil,
            sleepScore: sleepScore > 0 ? sleepScore : nil,
            sleepHours: sleepHours > 0 ? sleepHours : nil,
            rank:       rank
        )
    }
}
