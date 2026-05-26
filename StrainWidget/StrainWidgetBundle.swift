//
//  StrainWidgetBundle.swift
//  StrainWidget
//
//  Created by Blake Burnley on 5/21/26.
//

import WidgetKit
import SwiftUI

@main
struct StrainWidgetBundle: WidgetBundle {
    var body: some Widget {
        StrainWidget()
    }
}

struct StrainWidget: Widget {
    let kind: String = "StrainHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StrainWidgetProvider()) { entry in
            StrainWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Strain Fitness")
        .description("Recovery, sleep, strain and rank at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
