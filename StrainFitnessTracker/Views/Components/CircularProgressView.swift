//
//  CircularProgressView.swift
//  StrainFitnessTracker
//
//  Circular progress indicator - NOW USING REAL DATA
//

import SwiftUI

struct CircularProgressView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let showPercentage: Bool
    let isInteractive: Bool
    
    init(
        title: String,
        value: Double,
        maxValue: Double = 100,
        color: Color,
        showPercentage: Bool = true,
        isInteractive: Bool = false
    ) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.showPercentage = showPercentage
        self.isInteractive = isInteractive
    }
    
    private var progress: Double {
        min(max(value / maxValue, 0), 1)
    }
    
    private var displayValue: String {
        if showPercentage {
            // For percentage values, show as integer
            return "\(Int(value))%"
        } else {
            // For strain values, show one decimal place
            return String(format: "%.1f", value)
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.cardBackground, lineWidth: 8)
                    .frame(width: 90, height: 90)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        color,
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round
                        )
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1), value: progress)
                
                // Value text - handle "no data" state
                if value == 0 {
                    Text("--")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.secondaryText)
                } else {
                    Text(displayValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primaryText)
                }
            }
            
            // Title with chevron
            HStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .tracking(1)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(isInteractive ? color : .secondaryText)
            }
        }
        .contentShape(Rectangle())
    }
}
