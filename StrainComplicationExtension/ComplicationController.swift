import ClockKit
import Foundation

final class ComplicationController: NSObject, CLKComplicationDataSource {
    private let groupID = "group.com.blake.StrainFitnessTracker"

    private struct Metrics {
        let recovery: Int
        let strain: Int
        let lastUpdated: Date
    }

    // MARK: - Descriptor

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptor = CLKComplicationDescriptor(
            identifier: "strainRecovery",
            displayName: "Strain & Recovery",
            supportedFamilies: [
                .modularSmall,
                .modularLarge,
                .utilitarianSmall,
                .utilitarianLarge
            ]
        )
        handler([descriptor])
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // No-op. Required by protocol but not used.
    }

    // MARK: - Timeline

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        with handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // We only have one data point (current metrics). Allow the system to refresh on its own schedule.
        handler([])
    }

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        let metrics = loadMetrics()
        guard let template = template(for: complication.family, metrics: metrics) else {
            handler(nil)
            return
        }

        let entryDate = metrics?.lastUpdated ?? Date()
        handler(CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template))
    }

    // MARK: - Placeholders

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        with handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        let sampleMetrics = Metrics(recovery: 75, strain: 45, lastUpdated: Date())
        handler(template(for: complication.family, metrics: sampleMetrics))
    }

    // MARK: - Helpers

    private func loadMetrics() -> Metrics? {
        guard let defaults = UserDefaults(suiteName: groupID) else {
            return nil
        }

        let recoveryValue = defaults.double(forKey: "latestRecovery")
        let strainValue = defaults.double(forKey: "latestStrain")
        let lastUpdated = defaults.object(forKey: "lastMetricsUpdate") as? Date ?? Date()

        guard recoveryValue > 0 || strainValue > 0 else {
            return nil
        }

        return Metrics(
            recovery: Int(recoveryValue.rounded()),
            strain: Int(strainValue.rounded()),
            lastUpdated: lastUpdated
        )
    }

    private func template(for family: CLKComplicationFamily, metrics: Metrics?) -> CLKComplicationTemplate? {
        switch family {
        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackText()
            if let metrics {
                template.line1TextProvider = CLKSimpleTextProvider(text: "R\(metrics.recovery)%")
                template.line2TextProvider = CLKSimpleTextProvider(text: "S\(metrics.strain)%")
            } else {
                template.line1TextProvider = CLKSimpleTextProvider(text: "R--%")
                template.line2TextProvider = CLKSimpleTextProvider(text: "S--%")
            }
            return template

        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Strain Status")
            if let metrics {
                template.body1TextProvider = CLKSimpleTextProvider(text: "Recovery: \(metrics.recovery)%")
                template.body2TextProvider = CLKSimpleTextProvider(text: "Strain: \(metrics.strain)%")
            } else {
                template.body1TextProvider = CLKSimpleTextProvider(text: "Recovery: --%")
                template.body2TextProvider = CLKSimpleTextProvider(text: "Strain: --%")
            }
            return template

        case .utilitarianSmall:
            let template = CLKComplicationTemplateUtilitarianSmallFlat()
            if let metrics {
                template.textProvider = CLKSimpleTextProvider(text: "R\(metrics.recovery)% S\(metrics.strain)%")
            } else {
                template.textProvider = CLKSimpleTextProvider(text: "R-- S--")
            }
            return template

        case .utilitarianLarge:
            let template = CLKComplicationTemplateUtilitarianLargeFlat()
            if let metrics {
                template.textProvider = CLKSimpleTextProvider(
                    text: "Rec \(metrics.recovery)%  Str \(metrics.strain)%"
                )
            } else {
                template.textProvider = CLKSimpleTextProvider(text: "Rec --%  Str --%")
            }
            return template

        default:
            return nil
        }
    }
}
