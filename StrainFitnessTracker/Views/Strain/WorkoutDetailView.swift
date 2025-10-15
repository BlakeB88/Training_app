//
//  WorkoutDetailView.swift
//  StrainFitnessTracker
//
//  Detailed workout view matching iOS Health app style
//  Place in: StrainFitnessTracker/Views/Strain/
//

import SwiftUI
import HealthKit
import Charts

struct WorkoutDetailView: View {
    let workout: WorkoutSummary
    @State private var heartRateData: [HeartRatePoint] = []
    @State private var isLoadingHeartRate = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with workout type and time
                headerSection
                
                // Primary metrics cards
                primaryMetricsSection
                
                // Heart rate section
                if !heartRateData.isEmpty {
                    heartRateSection
                }
                
                // Secondary metrics
                secondaryMetricsSection
                
                // Workout details
                detailsSection
                
                // Swimming specific metrics (if applicable)
                if workout.workoutType == .swimming {
                    swimmingMetricsSection
                }
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(workoutName(workout.workoutType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(workout.startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .task {
            await loadHeartRateData()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large icon
            ZStack {
                Circle()
                    .fill(workoutColor(workout.workoutType).opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: workoutIcon(workout.workoutType))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(workoutColor(workout.workoutType))
            }
            
            // Time range
            VStack(spacing: 4) {
                Text(timeRange)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primaryText)
                
                Text(workout.startDate.formatted(date: .complete, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.cardBackground)
    }
    
    // MARK: - Primary Metrics Section
    private var primaryMetricsSection: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            PrimaryMetricCard(
                title: "Duration",
                value: formatDuration(workout.duration),
                icon: "timer",
                color: .blue
            )
            
            PrimaryMetricCard(
                title: "Calories",
                value: "\(Int(workout.calories))",
                subtitle: "CAL",
                icon: "flame.fill",
                color: .warningOrange
            )
            
            if let distance = workout.distance, distance > 0 {
                PrimaryMetricCard(
                    title: "Distance",
                    value: formatDistance(distance),
                    icon: "figure.run",
                    color: .accentBlue
                )
            } else {
                PrimaryMetricCard(
                    title: "Strain",
                    value: String(format: "%.1f", workout.strain),
                    icon: "bolt.fill",
                    color: strainColor(workout.strain)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Heart Rate Section
    private var heartRateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("HEART RATE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 16) {
                // Heart rate chart
                if #available(iOS 16.0, *) {
                    Chart(heartRateData) { point in
                        LineMark(
                            x: .value("Time", point.timestamp),
                            y: .value("BPM", point.heartRate)
                        )
                        .foregroundStyle(heartRateGradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Time", point.timestamp),
                            y: .value("BPM", point.heartRate)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.red.opacity(0.3), Color.red.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartYScale(domain: minHeartRate * 0.95...maxHeartRate * 1.05)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                            AxisValueLabel(format: .dateTime.hour().minute())
                        }
                    }
                    .frame(height: 200)
                    .padding(.horizontal, 16)
                }
                
                // Heart rate stats
                HStack(spacing: 0) {
                    HeartRateStat(
                        title: "Average",
                        value: "\(Int(workout.averageHeartRate ?? 0))",
                        subtitle: "BPM"
                    )
                    
                    Divider()
                        .frame(height: 40)
                    
                    HeartRateStat(
                        title: "Max",
                        value: "\(Int(workout.maxHeartRate ?? 0))",
                        subtitle: "BPM"
                    )
                    
                    Divider()
                        .frame(height: 40)
                    
                    HeartRateStat(
                        title: "Min",
                        value: "\(Int(minHeartRate))",
                        subtitle: "BPM"
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Secondary Metrics Section
    private var secondaryMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WORKOUT METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                if let avgHR = workout.averageHeartRate {
                    MetricRow(
                        icon: "heart.fill",
                        title: "Average Heart Rate",
                        value: "\(Int(avgHR)) bpm",
                        color: .red
                    )
                    Divider().padding(.leading, 56)
                }
                
                if let maxHR = workout.maxHeartRate {
                    MetricRow(
                        icon: "waveform.path.ecg",
                        title: "Max Heart Rate",
                        value: "\(Int(maxHR)) bpm",
                        color: .red
                    )
                    Divider().padding(.leading, 56)
                }
                
                if let distance = workout.distance, distance > 0 {
                    MetricRow(
                        icon: "location.fill",
                        title: "Distance",
                        value: formatDistance(distance),
                        color: .accentBlue
                    )
                    Divider().padding(.leading, 56)
                }
                
                MetricRow(
                    icon: "flame.fill",
                    title: "Active Calories",
                    value: "\(Int(workout.calories)) cal",
                    color: .warningOrange
                )
                
                Divider().padding(.leading, 56)
                
                MetricRow(
                    icon: "bolt.fill",
                    title: "Strain Score",
                    value: String(format: "%.1f", workout.strain),
                    color: strainColor(workout.strain)
                )
                
                if let intensity = workout.heartRateIntensity {
                    Divider().padding(.leading, 56)
                    MetricRow(
                        icon: "chart.bar.fill",
                        title: "Heart Rate Intensity",
                        value: String(format: "%.1f", intensity),
                        color: .purple
                    )
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DETAILS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                DetailRow(
                    title: "Start Time",
                    value: workout.startDate.formatted(date: .omitted, time: .shortened)
                )
                Divider().padding(.leading, 16)
                
                DetailRow(
                    title: "End Time",
                    value: workout.endDate.formatted(date: .omitted, time: .shortened)
                )
                Divider().padding(.leading, 16)
                
                DetailRow(
                    title: "Duration",
                    value: formatDuration(workout.duration)
                )
                Divider().padding(.leading, 16)
                
                DetailRow(
                    title: "Workout Type",
                    value: workoutName(workout.workoutType)
                )
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - Swimming Metrics Section
    private var swimmingMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SWIMMING METRICS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                if let stroke = workout.swimmingStrokeStyle {
                    MetricRow(
                        icon: "figure.pool.swim",
                        title: "Stroke Style",
                        value: strokeName(stroke),
                        color: .accentBlue
                    )
                    Divider().padding(.leading, 56)
                }
                
                if let laps = workout.lapCount {
                    MetricRow(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Laps",
                        value: "\(laps)",
                        color: .cyan
                    )
                    Divider().padding(.leading, 56)
                }
                
                if let distance = workout.distance {
                    MetricRow(
                        icon: "ruler",
                        title: "Average Pace",
                        value: formatPace(workout.duration / distance),
                        color: .green
                    )
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helper Properties
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let start = formatter.string(from: workout.startDate)
        let end = formatter.string(from: workout.endDate)
        return "\(start) - \(end)"
    }
    
    private var heartRateGradient: LinearGradient {
        LinearGradient(
            colors: [Color.red, Color.red.opacity(0.7)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private var minHeartRate: Double {
        heartRateData.map { $0.heartRate }.min() ?? 60
    }
    
    private var maxHeartRate: Double {
        heartRateData.map { $0.heartRate }.max() ?? 180
    }
    
    // MARK: - Helper Methods
    private func loadHeartRateData() async {
        isLoadingHeartRate = true
        
        do {
            let hrData = try await HealthKitManager.shared.fetchHeartRateData(for: HKWorkout(
                activityType: workout.workoutType,
                start: workout.startDate,
                end: workout.endDate
            ))
            
            // Convert to chart points
            let interval = workout.duration / 50 // Show ~50 points
            var points: [HeartRatePoint] = []
            var currentTime = workout.startDate
            
            for hr in hrData {
                points.append(HeartRatePoint(timestamp: currentTime, heartRate: hr))
                currentTime = currentTime.addingTimeInterval(interval)
            }
            
            await MainActor.run {
                self.heartRateData = points
                self.isLoadingHeartRate = false
            }
        } catch {
            print("Failed to load heart rate data: \(error)")
            await MainActor.run {
                self.isLoadingHeartRate = false
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let km = meters / 1000.0
        let miles = meters / 1609.344
        
        // Use km for most workouts, miles for running/cycling
        if workout.workoutType == .running || workout.workoutType == .cycling {
            return String(format: "%.2f mi", miles)
        } else {
            return String(format: "%.2f km", km)
        }
    }
    
    private func formatPace(_ secondsPerMeter: Double) -> String {
        let secondsPer100m = secondsPerMeter * 100
        let minutes = Int(secondsPer100m) / 60
        let seconds = Int(secondsPer100m) % 60
        return String(format: "%d:%02d /100m", minutes, seconds)
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
    
    private func workoutColor(_ type: HKWorkoutActivityType) -> Color {
        switch type {
        case .running: return .orange
        case .cycling: return .green
        case .swimming: return .accentBlue
        case .walking: return .purple
        case .yoga: return .pink
        default: return .blue
        }
    }
    
    private func strokeName(_ style: HKSwimmingStrokeStyle) -> String {
        switch style {
        case .freestyle: return "Freestyle"
        case .backstroke: return "Backstroke"
        case .breaststroke: return "Breaststroke"
        case .butterfly: return "Butterfly"
        case .mixed: return "Mixed"
        default: return "Unknown"
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

// MARK: - Supporting Views

struct PrimaryMetricCard: View {
    let title: String
    let value: String
    var subtitle: String = ""
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primaryText)
            
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondaryText)
            }
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct HeartRateStat: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct MetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Data Models

struct HeartRatePoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let heartRate: Double
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: WorkoutSummary(
            id: UUID(),
            workoutType: .swimming,
            startDate: Date().addingTimeInterval(-5400),
            endDate: Date(),
            duration: 5400,
            distance: 3175,
            calories: 720,
            averageHeartRate: 141,
            maxHeartRate: 185,
            swimmingStrokeStyle: .freestyle,
            lapCount: 127,
            strain: 10.1,
            heartRateIntensity: 2.5
        ))
    }
}
