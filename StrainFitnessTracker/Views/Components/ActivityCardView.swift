//
//  ActivityCardView.swift (UPDATED with Navigation)
//  StrainFitnessTracker
//
//  Activity card with tap navigation to detail views
//  Replace existing: StrainFitnessTracker/Views/Components/ActivityCardView.swift
//

import SwiftUI
import HealthKit

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
        .onAppear {
            // Debug: Check what we have
            if activity.type != .sleep {
                print("📱 ActivityCard for: \(activity.type.rawValue)")
                print("   Activity ID: \(activity.id)")
                print("   Workout in dict: \(workoutDetails[activity.id] != nil ? "YES" : "NO")")
                if let workout = workoutDetails[activity.id] {
                    print("   Workout HR: \(workout.averageHeartRate ?? 0)")
                    print("   Workout Cal: \(workout.calories)")
                }
            }
        }
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
                    sleepData: nil // This should be fetched from your data source
                )
            }
        } else {
            NavigationStack {
                WorkoutDetailView(workout: convertToWorkoutSummary(activity))
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
    
    private func convertToWorkoutSummary(_ activity: Activity) -> WorkoutSummary {
        // Convert Activity to WorkoutSummary
        // This is a placeholder - you should fetch the actual workout data
        return WorkoutSummary(
            id: activity.id,
            workoutType: activityTypeToHKWorkoutType(activity.type),
            startDate: activity.startTime,
            endDate: activity.endTime,
            duration: activity.duration,
            distance: nil,
            calories: 0,
            averageHeartRate: nil,
            maxHeartRate: nil,
            strain: activity.strain ?? 0
        )
    }
    
    private func activityTypeToHKWorkoutType(_ type: Activity.ActivityType) -> HKWorkoutActivityType {
        switch type {
        case .swimming: return .swimming
        case .running: return .running
        case .cycling: return .cycling
        case .workout: return .traditionalStrengthTraining
        case .walking: return .walking
        case .sleep: return .other
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        // Sleep activity preview
        ActivityCardView(
            activity: Activity(
                type: .sleep,
                startTime: Date().addingTimeInterval(-28800),
                endTime: Date(),
                strain: nil,
                duration: 28800
            ),
            workoutDetails: [:],
            sleepData: nil
        )
        
        // Workout activity preview
        ActivityCardView(
            activity: Activity(
                type: .swimming,
                startTime: Date().addingTimeInterval(-7200),
                endTime: Date().addingTimeInterval(-1800),
                strain: 10.1,
                duration: 5400
            ),
            workoutDetails: [
                UUID(): WorkoutSummary(
                    id: UUID(),
                    workoutType: .swimming,
                    startDate: Date().addingTimeInterval(-7200),
                    endDate: Date().addingTimeInterval(-1800),
                    duration: 5400,
                    distance: 3175,
                    calories: 720,
                    averageHeartRate: 141,
                    maxHeartRate: 185,
                    swimmingStrokeStyle: .freestyle,
                    lapCount: 127,
                    strain: 10.1,
                    heartRateIntensity: 2.5
                )
            ],
            sleepData: nil
        )
    }
    .padding()
    .background(Color.appBackground)
}
