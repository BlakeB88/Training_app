//
//  StrainRecoveryChartView.swift
//  StrainFitnessTracker
//
//  Weekly Strain & Recovery trend chart
//

import SwiftUI

struct StrainRecoveryChartView: View {
    let weekData: StrainRecoveryWeekData
    
    private let chartHeight: CGFloat = 180
    private let maxStrain: Double = 21.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("STRAIN & RECOVERY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(1)
                
                Spacer()
                
                Image(systemName: "info.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            
            // Chart
            GeometryReader { geometry in
                let chartWidth = geometry.size.width
                let spacing = chartWidth / CGFloat(weekData.weekDays.count + 1)
                
                ZStack(alignment: .topLeading) {
                    // Recovery zone background
                    VStack(spacing: 0) {
                        // Green zone (67-100%)
                        Rectangle()
                            .fill(Color.recoveryZoneGreen.opacity(0.1))
                            .frame(height: chartHeight * 0.33)
                        
                        // Yellow zone (34-66%)
                        Rectangle()
                            .fill(Color.recoveryZoneYellow.opacity(0.1))
                            .frame(height: chartHeight * 0.33)
                        
                        // Red zone (0-33%)
                        Rectangle()
                            .fill(Color.recoveryZoneRed.opacity(0.1))
                            .frame(height: chartHeight * 0.34)
                    }
                    
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach([100, 67, 34, 0], id: \.self) { value in
                            HStack {
                                Text("\(value)%")
                                    .font(.system(size: 9))
                                    .foregroundColor(.tertiaryText)
                                    .frame(width: 35, alignment: .trailing)
                                
                                Rectangle()
                                    .fill(Color.chartGrid.opacity(0.3))
                                    .frame(height: 0.5)
                            }
                            .frame(height: value == 0 ? 0 : chartHeight / 3)
                        }
                    }
                    
                    // Strain axis labels (left)
                    VStack(alignment: .trailing, spacing: 0) {
                        ForEach([21, 14, 7, 0], id: \.self) { value in
                            Text("\(value)")
                                .font(.system(size: 9))
                                .foregroundColor(.tertiaryText)
                                .frame(height: value == 0 ? 0 : chartHeight / 3)
                        }
                    }
                    .frame(width: 20)
                    .offset(x: -25, y: 0)
                    
                    // Data lines and points
                    ForEach(Array(weekData.weekDays.enumerated()), id: \.element.id) { index, day in
                        let x = spacing * CGFloat(index + 1)
                        
                        // Day label and background for current day
                        if isToday(day.date) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondaryCardBackground)
                                .frame(width: spacing * 0.8, height: chartHeight + 30)
                                .offset(x: x - spacing * 0.4, y: -5)
                        }
                        
                        // Strain point and line
                        let strainY = chartHeight - (CGFloat(day.strain / maxStrain) * chartHeight)
                        
                        if index > 0 {
                            let prevDay = weekData.weekDays[index - 1]
                            let prevX = spacing * CGFloat(index)
                            let prevStrainY = chartHeight - (CGFloat(prevDay.strain / maxStrain) * chartHeight)
                            
                            Path { path in
                                path.move(to: CGPoint(x: prevX, y: prevStrainY))
                                path.addLine(to: CGPoint(x: x, y: strainY))
                            }
                            .stroke(Color.strainBlue, lineWidth: 2)
                        }
                        
                        Circle()
                            .fill(Color.strainBlue)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.appBackground, lineWidth: 2)
                            )
                            .position(x: x, y: strainY)
                        
                        // Recovery point and line
                        let recoveryY = chartHeight - (CGFloat(day.recovery / 100) * chartHeight)
                        
                        if index > 0 {
                            let prevDay = weekData.weekDays[index - 1]
                            let prevX = spacing * CGFloat(index)
                            let prevRecoveryY = chartHeight - (CGFloat(prevDay.recovery / 100) * chartHeight)
                            
                            Path { path in
                                path.move(to: CGPoint(x: prevX, y: prevRecoveryY))
                                path.addLine(to: CGPoint(x: x, y: recoveryY))
                            }
                            .stroke(Color.chartSecondaryLine, lineWidth: 2)
                        }
                        
                        Circle()
                            .fill(Color(day.recoveryZone.color))
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .stroke(Color.appBackground, lineWidth: 2)
                            )
                            .position(x: x, y: recoveryY)
                        
                        // Day label
                        Text(day.dayLabel)
                            .font(.system(size: 10, weight: isToday(day.date) ? .bold : .regular))
                            .foregroundColor(isToday(day.date) ? .primaryText : .tertiaryText)
                            .position(x: x, y: chartHeight + 15)
                        
                        // Values (only for today)
                        if isToday(day.date) {
                            VStack(spacing: 2) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.strainBlue)
                                        .frame(width: 6, height: 6)
                                    Text(String(format: "%.1f", day.strain))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.primaryText)
                                }
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(day.recoveryZone.color))
                                        .frame(width: 6, height: 6)
                                    Text("\(Int(day.recovery))%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.primaryText)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cardBackground.opacity(0.9))
                            .cornerRadius(6)
                            .position(x: x, y: min(strainY, recoveryY) - 35)
                        }
                    }
                }
            }
            .frame(height: chartHeight + 30)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Sample Data
extension StrainRecoveryWeekData {
    static var sampleData: StrainRecoveryWeekData {
        let calendar = Calendar.current
        let today = Date()
        
        let days: [StrainRecoveryWeekData.DayData] = [
            .init(date: calendar.date(byAdding: .day, value: -6, to: today)!, strain: 18.8, recovery: 78),
            .init(date: calendar.date(byAdding: .day, value: -5, to: today)!, strain: 15.6, recovery: 56),
            .init(date: calendar.date(byAdding: .day, value: -4, to: today)!, strain: 4.9, recovery: 82),
            .init(date: calendar.date(byAdding: .day, value: -3, to: today)!, strain: 8.3, recovery: 47),
            .init(date: calendar.date(byAdding: .day, value: -2, to: today)!, strain: 12.1, recovery: 65),
            .init(date: calendar.date(byAdding: .day, value: -1, to: today)!, strain: 14.5, recovery: 71),
            .init(date: today, strain: 10.2, recovery: 82)
        ]
        
        return StrainRecoveryWeekData(weekDays: days)
    }
}

// MARK: - Preview
struct StrainRecoveryChartView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                StrainRecoveryChartView(weekData: .sampleData)
                    .padding()
            }
        }
    }
}
