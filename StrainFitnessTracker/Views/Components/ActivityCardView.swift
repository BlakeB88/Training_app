//
//  ActivityCardView.swift
//  StrainFitnessTracker
//
//  Activity item for "Today's Activities" section
//

import SwiftUI

struct ActivityCardView: View {
    let activity: Activity
    
    var body: some View {
        HStack(spacing: 16) {
            // Activity icon and duration/strain
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(activityColor)
                    .frame(width: 60, height: 60)
                
                VStack(spacing: 2) {
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(displayValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Activity details
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.type.rawValue)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.primaryText)
                    .tracking(0.5)
                
                HStack(spacing: 0) {
                    Text(activity.formattedTimeRange)
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    private var displayValue: String {
        if let strain = activity.strain {
            return String(format: "%.1f", strain)
        } else {
            return activity.formattedDuration
        }
    }
    
    private var activityColor: Color {
        switch activity.type {
        case .sleep:
            return .sleepBlue
        case .swimming:
            return Color(hex: "32ADE6") // Bright cyan for swimming
        case .running, .cycling, .workout:
            return .strainBlue
        case .walking:
            return Color(hex: "5AC8FA")
        }
    }
}
