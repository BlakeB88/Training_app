import SwiftUI
import Charts

struct StressChartView: View {
    let stressData: [StressMetrics]
    
    var body: some View {
        Chart(stressData) { metric in
            LineMark(
                x: .value("Time", metric.timestamp, unit: .minute),
                y: .value("Stress", metric.stressLevel)
            )
            .foregroundStyle(by: .value("Zone", metric.stressZone.description))
        }
        .chartForegroundStyleScale([
            "Low": Color.green,
            "Medium": Color.yellow,
            "High": Color.red
        ])
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 1, 2, 3]) { value in
                AxisValueLabel(String(format: "%.0f", value.as(Double.self) ?? 0))
            }
        }
        .frame(height: 200)
    }
}

#Preview {
    StressChartView(stressData: [
        StressMetrics(timestamp: Date(), stressLevel: 0.5, heartRate: 70, baselineHeartRate: 60),
        StressMetrics(timestamp: Date().addingTimeInterval(3600), stressLevel: 1.5, heartRate: 80, baselineHeartRate: 60),
        StressMetrics(timestamp: Date().addingTimeInterval(7200), stressLevel: 2.5, heartRate: 90, baselineHeartRate: 60)
    ])
}
