import SwiftUI
import WidgetKit

struct StrainComplicationEntryView: View {
    var entry: StrainComplicationProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            EmptyView()
        }
    }
}

// MARK: - Circular Complication (for Modular face small)

struct CircularComplicationView: View {
    let entry: StrainComplicationEntry
    
    var body: some View {
        if entry.hasData {
            ZStack {
                // Recovery ring (outer)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.recovery ?? 0) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.cyan, Color.green],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                
                // Strain ring (inner)
                Circle()
                    .trim(from: 0, to: CGFloat(entry.strain ?? 0) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(8)
                
                // Center value (strain)
                VStack(spacing: 0) {
                    Text("\(entry.strain ?? 0)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("strain")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        } else {
            VStack {
                Image(systemName: "bolt.heart.fill")
                    .font(.title2)
                Text("--")
                    .font(.caption2)
            }
        }
    }
}

// MARK: - Rectangular Complication (for Modular face large)

struct RectangularComplicationView: View {
    let entry: StrainComplicationEntry
    
    var body: some View {
        if entry.hasData {
            VStack(alignment: .leading, spacing: 4) {
                // Header
                HStack {
                    Image(systemName: "bolt.heart.fill")
                        .font(.caption)
                    Text("Fit Tracker")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.secondary)
                
                // Metrics
                HStack(spacing: 12) {
                    // Recovery
                    MetricRow(
                        label: "Recovery",
                        value: entry.recovery ?? 0,
                        color: .green
                    )
                    
                    Divider()
                    
                    // Strain
                    MetricRow(
                        label: "Strain",
                        value: entry.strain ?? 0,
                        color: .purple
                    )
                }
                
                // Optional: Exertion bar
                if let exertion = entry.exertion {
                    HStack(spacing: 4) {
                        Text("Exertion")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.gray.opacity(0.3))
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * CGFloat(exertion) / 100)
                            }
                        }
                        .frame(height: 4)
                        
                        Text("\(exertion)%")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                    }
                }
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "bolt.heart.fill")
                    Text("Fit Tracker")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Text("No data available")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MetricRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Text("\(value)%")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                
                // Small gauge indicator
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(-90))
            }
        }
    }
}

// MARK: - Inline Complication

struct InlineComplicationView: View {
    let entry: StrainComplicationEntry
    
    var body: some View {
        if entry.hasData {
            HStack(spacing: 6) {
                Image(systemName: "bolt.heart.fill")
                Text("R: \(entry.recovery ?? 0)%")
                Text("•")
                Text("S: \(entry.strain ?? 0)%")
            }
            .font(.caption2)
        } else {
            HStack {
                Image(systemName: "bolt.heart.fill")
                Text("No data")
            }
            .font(.caption2)
        }
    }
}

// MARK: - Preview

struct StrainComplicationEntryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            StrainComplicationEntryView(
                entry: StrainComplicationEntry(
                    date: Date(),
                    recovery: 75,
                    strain: 45,
                    exertion: 66
                )
            )
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
            
            StrainComplicationEntryView(
                entry: StrainComplicationEntry(
                    date: Date(),
                    recovery: 75,
                    strain: 45,
                    exertion: 66
                )
            )
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
        }
    }
}
