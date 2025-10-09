//
//  CircularProgressView.swift
//  StrainFitnessTracker
//
//  Circular progress indicator matching Whoop design
//

import SwiftUI

struct CircularProgressView: View {
    let title: String
    let value: Double
    let maxValue: Double
    let color: Color
    let showPercentage: Bool
    
    init(title: String, value: Double, maxValue: Double = 100, color: Color, showPercentage: Bool = true) {
        self.title = title
        self.value = value
        self.maxValue = maxValue
        self.color = color
        self.showPercentage = showPercentage
    }
    
    private var progress: Double {
        min(max(value / maxValue, 0), 1)
    }
    
    private var displayValue: String {
        if showPercentage {
            return "\(Int(value))%"
        } else {
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
                
                // Value text
                Text(displayValue)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
            }
            
            // Title with chevron
            HStack(spacing: 2) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .tracking(1)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

// MARK: - Preview
struct CircularProgressView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            HStack(spacing: 20) {
                CircularProgressView(
                    title: "Sleep",
                    value: 77,
                    color: .sleepBlue
                )
                
                CircularProgressView(
                    title: "Recovery",
                    value: 82,
                    color: .recoveryGreen
                )
                
                CircularProgressView(
                    title: "Strain",
                    value: 10.2,
                    maxValue: 21,
                    color: .strainBlue,
                    showPercentage: false
                )
            }
            .padding()
        }
    }
}
