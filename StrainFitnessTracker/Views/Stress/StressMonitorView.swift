//
//  StressMonitorView.swift
//  StrainFitnessTracker
//
//  Stress monitor with time-series graph
//

import SwiftUI

struct StressMonitorView: View {
    let stressData: [StressDataPoint]
    let currentStress: Double
    let activities: [Activity]
    
    private let chartHeight: CGFloat = 200
    private let maxStress: Double = 3.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STRESS MONITOR")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondaryText)
                        .tracking(1)
                    
                    Text("Last updated \(formattedLastUpdate)")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
            }
            
            // Current stress value
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", currentStress))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                
                Text(currentStressLevel.uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(stressLevelColor)
                    .tracking(0.5)
            }
            
            // Chart
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Y-axis labels and grid lines
                    VStack(spacing: 0) {
                        ForEach([3.0, 2.0, 1.0, 0.0], id: \.self) { value in
                            HStack {
                                Text(String(format: "%.1f", value))
                                    .font(.system(size: 10))
                                    .foregroundColor(.tertiaryText)
                                    .frame(width: 30, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(Color.chartGrid)
                                    .frame(height: 0.5)
                            }
                            .frame(height: chartHeight / 4)
                        }
                    }
                    
                    // Stress line chart
                    StressChartPath(
                        data: stressData,
                        maxStress: maxStress,
                        chartHeight: chartHeight,
                        chartWidth: geometry.size.width - 40
                    )
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.sleepBlue, .stressMedium, .warningOrange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
                    .offset(x: 40, y: 0)
                    
                    // Activity annotations
                    ForEach(activities) { activity in
                        ActivityAnnotation(
                            activity: activity,
                            stressData: stressData,
                            chartHeight: chartHeight,
                            chartWidth: geometry.size.width - 40
                        )
                        .offset(x: 40, y: 0)
                    }
                    
                    // X-axis labels
                    HStack {
                        Spacer().frame(width: 40)
                        
                        ForEach(timeLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundColor(.tertiaryText)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .offset(y: chartHeight + 8)
                }
            }
            .frame(height: chartHeight + 30)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    private var currentStressLevel: String {
        if currentStress < 1.0 {
            return "Low"
        } else if currentStress < 2.0 {
            return "Medium"
        } else {
            return "High"
        }
    }
    
    private var stressLevelColor: Color {
        if currentStress < 1.0 {
            return .stressLow
        } else if currentStress < 2.0 {
            return .stressMedium
        } else {
            return .stressHigh
        }
    }
    
    private var formattedLastUpdate: String {
        guard let lastPoint = stressData.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastPoint.timestamp)
    }
    
    private var timeLabels: [String] {
        guard let firstTime = stressData.first?.timestamp,
              let lastTime = stressData.last?.timestamp else {
            return []
        }
        
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        // Generate 4 time labels across the range
        let interval = lastTime.timeIntervalSince(firstTime) / 3
        var labels: [String] = []
        
        for i in 0...3 {
            let time = firstTime.addingTimeInterval(interval * Double(i))
            let hour = calendar.component(.hour, from: time)
            
            // Show PM for previous day times
            if hour >= 12 {
                formatter.dateFormat = "h:mm a"
            } else {
                formatter.dateFormat = "h:mm a"
            }
            
            labels.append(formatter.string(from: time))
        }
        
        return labels
    }
}

// MARK: - Stress Chart Path
struct StressChartPath: Shape {
    let data: [StressDataPoint]
    let maxStress: Double
    let chartHeight: CGFloat
    let chartWidth: CGFloat
    
    func path(in rect: CGRect) -> Path {
        guard data.count > 1,
              let firstTime = data.first?.timestamp,
              let lastTime = data.last?.timestamp else {
            return Path()
        }
        
        let timeRange = lastTime.timeIntervalSince(firstTime)
        
        var path = Path()
        
        for (index, point) in data.enumerated() {
            let x = CGFloat(point.timestamp.timeIntervalSince(firstTime) / timeRange) * chartWidth
            let y = chartHeight - (CGFloat(point.value / maxStress) * chartHeight)
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        return path
    }
}

// MARK: - Activity Annotation
struct ActivityAnnotation: View {
    let activity: Activity
    let stressData: [StressDataPoint]
    let chartHeight: CGFloat
    let chartWidth: CGFloat
    
    var body: some View {
        if let firstTime = stressData.first?.timestamp,
           let lastTime = stressData.last?.timestamp {
            let timeRange = lastTime.timeIntervalSince(firstTime)
            
            let startX = CGFloat(activity.startTime.timeIntervalSince(firstTime) / timeRange) * chartWidth
            let endX = CGFloat(activity.endTime.timeIntervalSince(firstTime) / timeRange) * chartWidth
            let width = max(endX - startX, 20)
            
            VStack(spacing: 2) {
                // Icon above chart
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(activityColor.opacity(0.3))
                        .frame(width: 30, height: 20)
                    
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(activityColor)
                }
                .offset(y: -25)
                
                // Activity duration bar
                Rectangle()
                    .fill(activityColor.opacity(0.2))
                    .frame(width: width, height: chartHeight)
                    .overlay(
                        Rectangle()
                            .fill(activityColor.opacity(0.3))
                            .frame(height: 3),
                        alignment: .top
                    )
            }
            .offset(x: startX, y: 0)
        }
    }
    
    private var activityColor: Color {
        switch activity.type {
        case .sleep:
            return .sleepBlue
        case .swimming, .running, .cycling, .workout:
            return .accentBlue
        case .walking:
            return .stressMedium
        }
    }
}

// MARK: - Preview
struct StressMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                StressMonitorView(
                    stressData: DailyMetrics.sampleData.stressHistory,
                    currentStress: 1.4,
                    activities: DailyMetrics.sampleData.activities
                )
                .padding()
            }
        }
    }
}
