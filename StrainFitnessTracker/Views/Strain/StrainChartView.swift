import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

struct StrainChartView: View {
    let weeklyData: [(date: Date, strain: Double)]
    
    private var backgroundColor: Color {
        #if canImport(UIKit)
        Color(.systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Strain")
                .font(.headline)

            if #available(iOS 16.0, macOS 13.0, *) {
                Chart {
                    ForEach(weeklyData, id: \.date) { data in
                        BarMark(
                            x: .value("Day", data.date, unit: .day),
                            y: .value("Strain", data.strain)
                        )
                        .foregroundStyle(strainGradient(data.strain))
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: 0...21)
            } else {
                SimpleBarChartView(data: weeklyData)
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
    
    private func strainGradient(_ strain: Double) -> LinearGradient {
        let color: Color
        switch strain {
        case 0..<10: color = .green
        case 10..<14: color = .yellow
        case 14..<18: color = .orange
        default: color = .red
        }
        
        return LinearGradient(
            colors: [color.opacity(0.6), color],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// Fallback chart for older iOS versions
struct SimpleBarChartView: View {
    let data: [(date: Date, strain: Double)]
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(data, id: \.date) { item in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(strainColor(item.strain))
                        .frame(height: CGFloat(item.strain / 21.0) * 180)
                    
                    Text(item.date, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                }
            }
        }
        .frame(height: 200)
    }
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<10: return .green
        case 10..<14: return .yellow
        case 14..<18: return .orange
        default: return .red
        }
    }
}

#Preview {
    StrainChartView(weeklyData: [
        (Date().addingTimeInterval(-6*86400), 8.5),
        (Date().addingTimeInterval(-5*86400), 12.3),
        (Date().addingTimeInterval(-4*86400), 15.7),
        (Date().addingTimeInterval(-3*86400), 10.2),
        (Date().addingTimeInterval(-2*86400), 14.8),
        (Date().addingTimeInterval(-1*86400), 11.5),
        (Date(), 13.2)
    ])
    .padding()
}
