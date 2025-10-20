import WidgetKit
import SwiftUI

struct StrainComplicationProvider: TimelineProvider {
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
    
    private func getCurrentEntry() -> StrainComplicationEntry {
        let dataManager = DataSharingManager.shared
        
        if let metrics = dataManager.getLatestMetrics() {
            return StrainComplicationEntry(
                date: metrics.lastUpdate,
                recovery: metrics.recoveryPercentage,
                strain: metrics.strainPercentage,
                exertion: metrics.exertionPercentage
            )
        } else {
            // No data available
            return StrainComplicationEntry(
                date: Date(),
                recovery: nil,
                strain: nil,
                exertion: nil
            )
        }
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
