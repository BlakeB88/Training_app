import SwiftUI
import WidgetKit

// MARK: - Colors (local — can't import main app's Color extension)
private let recoveryGreen = Color(red: 0.196, green: 0.843, blue: 0.294) // #32D74B
private let strainBlue    = Color(red: 0.30,  green: 0.55,  blue: 1.0)

// MARK: - Strain formatter (shows "12.7", not "61%")
private func formatStrain(_ raw: Double?) -> String {
    guard let raw else { return "--" }
    // Drop decimal if it's a whole number
    return raw.truncatingRemainder(dividingBy: 1) == 0
        ? String(format: "%.0f", raw)
        : String(format: "%.1f", raw)
}

// MARK: - Entry View

struct StrainComplicationEntryView: View {
    var entry: StrainComplicationProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let _ = print("🟡 [Complication] StrainComplicationEntryView.body — family: \(family), hasData: \(entry.hasData)")
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            let _ = print("🔴 [Complication] Unexpected family: \(family)")
            Text("?")
        }
    }
}

// MARK: - Circular Complication

struct CircularComplicationView: View {
    let entry: StrainComplicationEntry

    var body: some View {
        if entry.hasData {
            ZStack {
                // Recovery ring (outer) — green
                Circle()
                    .trim(from: 0, to: CGFloat(entry.recovery ?? 0) / 100)
                    .stroke(recoveryGreen,
                            style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Strain ring (inner) — blue
                Circle()
                    .trim(from: 0, to: CGFloat(entry.strain ?? 0) / 100)
                    .stroke(strainBlue,
                            style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(10)

                // Center — raw strain value
                VStack(spacing: 0) {
                    Text(formatStrain(entry.strainRaw))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(strainBlue)
                        .minimumScaleFactor(0.7)
                    Text("strain")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack(spacing: 2) {
                Image(systemName: "bolt.heart.fill")
                    .font(.title3)
                Text("--")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Rectangular Complication

struct RectangularComplicationView: View {
    let entry: StrainComplicationEntry

    var body: some View {
        if entry.hasData {
            HStack(spacing: 8) {
                // Recovery column
                VStack(alignment: .leading, spacing: 2) {
                    Text("Recovery")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text("\(entry.recovery ?? 0)%")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(recoveryGreen)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    // Mini ring
                    MiniRing(progress: Double(entry.recovery ?? 0) / 100, color: recoveryGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1)
                    .padding(.vertical, 4)

                // Strain column
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strain")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(formatStrain(entry.strainRaw))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(strainBlue)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    // Mini ring — still fills by percentage, shows raw as text
                    MiniRing(progress: Double(entry.strain ?? 0) / 100, color: strainBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 2)
        } else {
            HStack {
                Image(systemName: "bolt.heart.fill")
                Text("No data available")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

// MARK: - Shared mini ring indicator

struct MiniRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
    }
}

// MARK: - Inline Complication

struct InlineComplicationView: View {
    let entry: StrainComplicationEntry

    var body: some View {
        if entry.hasData {
            Text("R:\(entry.recovery ?? 0)%  S:\(formatStrain(entry.strainRaw))")
                .font(.caption2)
        } else {
            Label("No data", systemImage: "bolt.heart.fill")
                .font(.caption2)
        }
    }
}

// MARK: - Preview

struct StrainComplicationEntryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StrainComplicationEntryView(
                entry: StrainComplicationEntry(date: Date(), recovery: 54, strain: 60, strainRaw: 12.7, exertion: nil)
            )
            .containerBackground(.black, for: .widget)
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")

            StrainComplicationEntryView(
                entry: StrainComplicationEntry(date: Date(), recovery: 54, strain: 60, strainRaw: 12.7, exertion: nil)
            )
            .containerBackground(.black, for: .widget)
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
        }
    }
}
