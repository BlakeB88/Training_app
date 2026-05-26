import WidgetKit
import SwiftUI


struct StrainComplicationProvider: TimelineProvider {
    // ✅ FIX: Direct UserDefaults access for complications
    private let groupID = "group.com.blake.StrainFitnessTracker"
    
    func placeholder(in context: Context) -> StrainComplicationEntry {
        print("🟡 [Complication] placeholder() called — family: \(context.family)")
        return StrainComplicationEntry(date: Date(), recovery: 75, strain: 60, strainRaw: 12.7, exertion: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (StrainComplicationEntry) -> Void) {
        print("🟡 [Complication] getSnapshot() called — family: \(context.family), isPreview: \(context.isPreview)")
        let entry: StrainComplicationEntry
        if context.isPreview {
            entry = StrainComplicationEntry(date: Date(), recovery: 75, strain: 60, strainRaw: 12.7, exertion: nil)
        } else {
            entry = getCurrentEntry()
        }
        print("🟡 [Complication] getSnapshot() returning: hasData=\(entry.hasData) R=\(entry.recovery ?? -1) S=\(entry.strainRaw ?? -1)")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StrainComplicationEntry>) -> Void) {
        print("🟡 [Complication] getTimeline() called — family: \(context.family)")
        let currentEntry = getCurrentEntry()
        print("🟡 [Complication] getTimeline() entry: hasData=\(currentEntry.hasData) R=\(currentEntry.recovery ?? -1) S=\(currentEntry.strain ?? -1)")
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getCurrentEntry() -> StrainComplicationEntry {
        print("🔧 [Complication] Fetching current entry...")

        guard let sharedDefaults = UserDefaults(suiteName: groupID) else {
            print("⚠️ [Complication] Failed to access shared UserDefaults")
            return noDataEntry()
        }

        let recovery  = sharedDefaults.double(forKey: "shared_recovery")
        let strain    = sharedDefaults.double(forKey: "shared_strain")     // 0–100 %
        let strainRaw = sharedDefaults.double(forKey: "shared_strain_raw") // 0–21
        let lastUpdate = sharedDefaults.object(forKey: "shared_last_update") as? Date

        print("📊 [Complication] Read values: R=\(recovery) S_pct=\(strain) S_raw=\(strainRaw)")

        guard recovery > 0 || strain > 0, let updateDate = lastUpdate else {
            print("⚠️ [Complication] No valid data found")
            return noDataEntry()
        }

        let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
        if updateDate < threeHoursAgo {
            print("⚠️ [Complication] Data is stale (updated \(updateDate.formatted()))")
        }

        print("✅ [Complication] Returning entry with data")

        return StrainComplicationEntry(
            date: updateDate,
            recovery:  recovery  > 0 ? Int(recovery.rounded())  : nil,
            strain:    strain    > 0 ? Int(strain.rounded())    : nil,
            strainRaw: strainRaw > 0 ? strainRaw               : nil,
            exertion:  nil
        )
    }

    private func noDataEntry() -> StrainComplicationEntry {
        StrainComplicationEntry(date: Date(), recovery: nil, strain: nil, strainRaw: nil, exertion: nil)
    }
}

struct StrainComplicationEntry: TimelineEntry {
    let date: Date
    let recovery: Int?
    let strain: Int?       // 0–100 percentage (used to fill the ring arc)
    let strainRaw: Double? // 0–21 raw value (displayed as text, e.g. "12.7")
    let exertion: Int?

    var hasData: Bool {
        recovery != nil && strain != nil
    }
}
