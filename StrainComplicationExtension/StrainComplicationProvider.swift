import WidgetKit
import SwiftUI

struct StrainComplicationProvider: TimelineProvider {
    // ✅ FIX: Direct UserDefaults access for complications
    private let groupID = "group.com.blake.StrainFitnessTracker"
    
    func placeholder(in context: Context) -> StrainComplicationEntry {
        StrainComplicationEntry(
            date: Date(),
            recovery: 75,
            strain: 45,
            exertion: 66
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StrainComplicationEntry) -> Void) {
        let entry: StrainComplicationEntry
        
        if context.isPreview {
            entry = StrainComplicationEntry(
                date: Date(),
                recovery: 75,
                strain: 45,
                exertion: 66
            )
        } else {
            entry = getCurrentEntry()
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StrainComplicationEntry>) -> Void) {
        let currentEntry = getCurrentEntry()
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // ✅ FIX: Direct UserDefaults access instead of DataSharingManager
    private func getCurrentEntry() -> StrainComplicationEntry {
        print("🔧 [Complication] Fetching current entry...")
        
        guard let sharedDefaults = UserDefaults(suiteName: groupID) else {
            print("⚠️ [Complication] Failed to access shared UserDefaults")
            return noDataEntry()
        }
        
        // Read directly from UserDefaults
        let recovery = sharedDefaults.double(forKey: "latestRecovery")
        let strain = sharedDefaults.double(forKey: "latestStrain")
        let exertion = sharedDefaults.double(forKey: "latestExertion")
        let lastUpdate = sharedDefaults.object(forKey: "lastMetricsUpdate") as? Date
        
        print("📊 [Complication] Read values: R=\(recovery) S=\(strain) E=\(exertion)")
        
        // Check if we have valid data
        guard recovery > 0 || strain > 0, let updateDate = lastUpdate else {
            print("⚠️ [Complication] No valid data found")
            return noDataEntry()
        }
        
        // Check if data is stale (older than 3 hours)
        let threeHoursAgo = Date().addingTimeInterval(-3 * 60 * 60)
        if updateDate < threeHoursAgo {
            print("⚠️ [Complication] Data is stale (updated \(updateDate.formatted()))")
        }
        
        print("✅ [Complication] Returning entry with data")
        
        return StrainComplicationEntry(
            date: updateDate,
            recovery: recovery > 0 ? Int(recovery.rounded()) : nil,
            strain: strain > 0 ? Int(strain.rounded()) : nil,
            exertion: exertion > 0 ? Int(exertion.rounded()) : nil
        )
    }
    
    private func noDataEntry() -> StrainComplicationEntry {
        return StrainComplicationEntry(
            date: Date(),
            recovery: nil,
            strain: nil,
            exertion: nil
        )
    }
}

struct StrainComplicationEntry: TimelineEntry {
    let date: Date
    let recovery: Int?
    let strain: Int?
    let exertion: Int?
    
    var hasData: Bool {
        recovery != nil && strain != nil
    }
}
