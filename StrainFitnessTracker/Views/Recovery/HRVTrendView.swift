import SwiftUI
import Charts

struct HRVTrendView: View {
    let weeklyData: [(date: Date, hrv: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Trend")
                .font(.headline)
            
            if !weeklyData.isEmpty {
                if #available(iOS 16.0, macOS 13.0, *) {
                    Chart {
                        ForEach(weeklyData, id: \.date) { data in
                            LineMark(
                                x: .value("Day", data.date, unit: .day),
                                y: .value("HRV", data.hrv)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)
                            
                            AreaMark(
                                x: .value("Day", data.date, unit: .day),
                                y: .value("HRV", data.hrv)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .frame(height: 200)
                    .chartYScale(domain: 0...maxHRV * 1.2)
                } else {
                    // Fallback for older versions
                    SimpleLineChartView(data: weeklyData)
                }
                
                // Stats
                HStack(spacing: 20) {
                    StatView(title: "Average", value: String(format: "%.0f ms", averageHRV))
                    StatView(title: "Highest", value: String(format: "%.0f ms", maxHRV))
                    StatView(title: "Lowest", value: String(format: "%.0f ms", minHRV))
                }
                .padding(.top, 8)
            } else {
                Text("No HRV data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
    
    private var averageHRV: Double {
        guard !weeklyData.isEmpty else { return 0 }
        return weeklyData.map { $0.hrv }.reduce(0, +) / Double(weeklyData.count)
    }
    
    private var maxHRV: Double {
        weeklyData.map { $0.hrv }.max() ?? 0
    }
    
    private var minHRV: Double {
        weeklyData.map { $0.hrv }.min() ?? 0
    }
}

struct SimpleLineChartView: View {
    let data: [(date: Date, hrv: Double)]
    
    var body: some View {
        GeometryReader { geometry in
            let maxValue = data.map { $0.hrv }.max() ?? 100
            let points = data.enumerated().map { index, item in
                CGPoint(
                    x: CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width,
                    y: geometry.size.height - (CGFloat(item.hrv) / CGFloat(maxValue) * geometry.size.height)
                )
            }
            
            Path { path in
                guard let firstPoint = points.first else { return }
                path.move(to: firstPoint)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.blue, lineWidth: 2)
        }
        .frame(height: 200)
    }
}

struct StatView: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.bold())
        }
    }
}

#Preview {
    HRVTrendView(weeklyData: [
        (Date().addingTimeInterval(-6*86400), 65),
        (Date().addingTimeInterval(-5*86400), 72),
        (Date().addingTimeInterval(-4*86400), 58),
        (Date().addingTimeInterval(-3*86400), 68),
        (Date().addingTimeInterval(-2*86400), 75),
        (Date().addingTimeInterval(-1*86400), 70),
        (Date(), 73)
    ])
    .padding()
}
