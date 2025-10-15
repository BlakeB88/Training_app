//
//  ActivityCardView.swift
//  StrainFitnessTracker
//
//  Activity item for "Today's Activities" section
//

import SwiftUI

struct ActivityCardView: View {
    let activity: Activity
    let workoutDetails: [UUID: WorkoutSummary]
    let sleepData: HealthKitManager.SleepData?
    
    @State private var showDetail = false
    
    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(activity.type.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: activity.type.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(activity.type.color)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(activity.type.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondaryText)
                            .tracking(0.5)
                        
                        if let strain = activity.strain {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundColor(.tertiaryText)
                            
                            Text(String(format: "%.1f", strain))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(strainColor(strain))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(activity.formattedDuration)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primaryText)
                        
                        Text("•")
                            .font(.system(size: 12))
                            .foregroundColor(.tertiaryText)
                        
                        Text(activity.formattedTimeRange)
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            navigationDestination
        }
    }
    
    @ViewBuilder
    private var navigationDestination: some View {
        if activity.type == .sleep {
            NavigationStack {
                SleepDetailView(
                    sleepStart: activity.startTime,
                    sleepEnd: activity.endTime,
                    sleepDuration: activity.duration / 3600.0,
                    sleepData: sleepData
                )
            }
        } else if let workout = workoutDetails[activity.id] {
            NavigationStack {
                WorkoutDetailView(workout: workout)
            }
        }
    }
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<10: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case 10..<14: return Color(red: 0.95, green: 0.7, blue: 0)
        case 14..<18: return Color(red: 1.0, green: 0.5, blue: 0)
        default: return Color(red: 1.0, green: 0.2, blue: 0.2)
        }
    }
}
