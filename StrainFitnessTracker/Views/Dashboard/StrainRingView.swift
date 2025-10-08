//
//  StrainRingView.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import SwiftUI

struct StrainRingView: View {
    let strain: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let showLabel: Bool
    
    init(
        strain: Double,
        size: CGFloat = 200,
        lineWidth: CGFloat = 20,
        showLabel: Bool = true
    ) {
        self.strain = strain
        self.size = size
        self.lineWidth = lineWidth
        self.showLabel = showLabel
    }
    
    private var progress: Double {
        min(strain / AppConstants.Strain.maxValue, 1.0)
    }
    
    private var strainColor: Color {
        switch strain {
        case 0..<AppConstants.Strain.lightMax:
            return .green
        case AppConstants.Strain.lightMax..<AppConstants.Strain.moderateMax:
            return .yellow
        case AppConstants.Strain.moderateMax..<AppConstants.Strain.hardMax:
            return .orange
        default:
            return .red
        }
    }
    
    private var strainLevel: String {
        switch strain {
        case 0..<AppConstants.Strain.lightMax:
            return "Light"
        case AppConstants.Strain.lightMax..<AppConstants.Strain.moderateMax:
            return "Moderate"
        case AppConstants.Strain.moderateMax..<AppConstants.Strain.hardMax:
            return "Hard"
        default:
            return "Very Hard"
        }
    }
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: lineWidth
                )
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    strainColor,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            
            // Center content
            if showLabel {
                VStack(spacing: 4) {
                    Text(strain.formatted(.number.precision(.fractionLength(1))))
                        .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(strainLevel)
                        .font(.system(size: size * 0.08, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview
#Preview("Strain Ring Variations") {
    VStack(spacing: 30) {
        HStack(spacing: 30) {
            VStack {
                StrainRingView(strain: 3.5, size: 150)
                Text("Light")
                    .font(.caption)
            }
            
            VStack {
                StrainRingView(strain: 8.2, size: 150)
                Text("Moderate")
                    .font(.caption)
            }
        }
        
        HStack(spacing: 30) {
            VStack {
                StrainRingView(strain: 13.7, size: 150)
                Text("Hard")
                    .font(.caption)
            }
            
            VStack {
                StrainRingView(strain: 18.5, size: 150)
                Text("Very Hard")
                    .font(.caption)
            }
        }
        
        // Small version without label
        HStack(spacing: 20) {
            StrainRingView(strain: 5.0, size: 60, lineWidth: 8, showLabel: false)
            StrainRingView(strain: 10.0, size: 60, lineWidth: 8, showLabel: false)
            StrainRingView(strain: 15.0, size: 60, lineWidth: 8, showLabel: false)
            StrainRingView(strain: 20.0, size: 60, lineWidth: 8, showLabel: false)
        }
    }
    .padding()
}
