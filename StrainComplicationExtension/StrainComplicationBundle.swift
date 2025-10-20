import WidgetKit
import SwiftUI

@main
struct StrainComplicationBundle: WidgetBundle {
    var body: some Widget {
        StrainRecoveryComplication()
    }
}

struct StrainRecoveryComplication: Widget {
    let kind: String = "StrainRecoveryComplication"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StrainComplicationProvider()) { entry in
            StrainComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Strain & Recovery")
        .description("View your current strain and recovery metrics")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
