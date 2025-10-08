import SwiftUI
import HealthKit
import UIKit

struct WorkoutListView: View {
    let workouts: [WorkoutSummary]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Activities")
                .font(.headline)
            
            ForEach(workouts) { workout in
                WorkoutRow(workout: workout)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: workoutIcon(workout.workoutType))
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(strainColor(workout.strain))
                .cornerRadius(8)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(workoutName(workout.workoutType))
                    .font(.subheadline.bold())
                
                HStack(spacing: 8) {
                    Text(workout.duration.asMinutes)
                    
                    if let distance = workout.distance, distance > 0 {
                        Text("•")
                        Text(distance.asKilometers)
                    }
                    
                    if workout.calories > 0 {
                        Text("•")
                        Text("\(Int(workout.calories)) cal")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Strain
            VStack(alignment: .trailing, spacing: 4) {
                Text(workout.strain.formatted(.number.precision(.fractionLength(1))))
                    .font(.headline)
                    .foregroundColor(strainColor(workout.strain))
                
                Text("Strain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<10: return .green
        case 10..<14: return .yellow
        case 14..<18: return .orange
        default: return .red
        }
    }
    
    private func workoutIcon(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        default: return "figure.mixed.cardio"
        }
    }
    
    private func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Functional Training"
        case .traditionalStrengthTraining: return "Strength Training"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        default: return "Workout"
        }
    }
}

#Preview {
    WorkoutListView(workouts: [
        WorkoutSummary(
            id: UUID(),
            workoutType: .running,
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            duration: 1800,
            distance: 5000,
            calories: 350,
            averageHeartRate: 155,
            maxHeartRate: 175,
            strain: 12.5
        ),
        WorkoutSummary(
            id: UUID(),
            workoutType: .cycling,
            startDate: Date().addingTimeInterval(-7200),
            endDate: Date().addingTimeInterval(-3600),
            duration: 3600,
            distance: 25000,
            calories: 520,
            averageHeartRate: 145,
            maxHeartRate: 168,
            strain: 15.8
        )
    ])
    .padding()
}
