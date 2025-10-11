//
//  StrainDetailView.swift
//  StrainFitnessTracker
//
//  Updated: 10/10/25 - Complete redesign with strain components breakdown
//

import SwiftUI
import UIKit
import HealthKit

struct StrainDetailView: View {
    @StateObject private var viewModel: StrainViewModel
    @State private var selectedDate: Date
    @State private var isDateSelectorExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    init(initialDate: Date = Date()) {
        let vm = StrainViewModel(selectedDate: initialDate)
        _viewModel = StateObject(wrappedValue: vm)
        _selectedDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Collapsible Date picker
                    collapsibleDatePicker
                    
                    // Primary Strain Display
                    strainPrimaryCard
                    
                    // Strain Components Breakdown
                    strainComponentsSection
                    
                    // Workouts Contributing to Strain
                    if !viewModel.workouts.isEmpty {
                        workoutsSection
                    }
                    
                    // Weekly Trend Chart
                    weeklyTrendSection
                    
                    // ACWR Status (if available)
                    if let acwr = viewModel.acwr {
                        acwrCard(acwr)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("Strain Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .onChange(of: selectedDate) { _, newValue in
            Task { await viewModel.selectDate(newValue) }
        }
    }
    
    // MARK: - Collapsible Date Picker
    private var collapsibleDatePicker: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDateSelectorExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .tracking(0.5)
                        
                        Text(selectedDate.formatted(.dateTime.month().day().year()))
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("Change")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentBlue)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentBlue)
                            .rotationEffect(.degrees(isDateSelectorExpanded ? 180 : 0))
                    }
                }
                .padding(16)
                .background(Color.cardBackground)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if isDateSelectorExpanded {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color.cardBackground)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Primary Strain Card
    private var strainPrimaryCard: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Total Strain")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.1f", viewModel.currentStrain))
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(strainColor(viewModel.currentStrain))
                        
                        Text(viewModel.strainLevel)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondaryText)
                            .tracking(0.5)
                    }
                    
                    Spacer()
                    
                    // Strain gauge circle
                    StrainGaugeView(strain: viewModel.currentStrain)
                        .frame(width: 100, height: 100)
                }
            }
            
            // Strain range indicator
            strainRangeIndicator
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Strain Range Indicator
    private var strainRangeIndicator: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Light")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Text("0-9")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moderate")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Text("9-14")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("High")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Text("14-18")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Very High")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    Text("18-21")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Range bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondaryCardBackground)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(strainColor(viewModel.currentStrain))
                    .frame(width: max(2, min(CGFloat(viewModel.currentStrain / 21.0), 1.0) * 100), alignment: .leading)
            }
            .frame(height: 6)
        }
    }
    
    // MARK: - Strain Components Section
    private var strainComponentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("STRAIN COMPONENTS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
            
            VStack(spacing: 12) {
                // Cardiovascular Strain
                StrainComponentCard(
                    title: "Cardiovascular",
                    value: calculateCardiovascularStrain(),
                    percentage: (calculateCardiovascularStrain() / max(viewModel.currentStrain, 0.1)) * 100,
                    icon: "heart.fill",
                    color: .red,
                    description: "Heart rate elevation and duration"
                )
                
                // Muscular Strain
                StrainComponentCard(
                    title: "Muscular Load",
                    value: calculateMuscularStrain(),
                    percentage: (calculateMuscularStrain() / max(viewModel.currentStrain, 0.1)) * 100,
                    icon: "figure.strengthtraining.traditional",
                    color: .orange,
                    description: "Intensity and volume of workouts"
                )
                
                // Workout Duration
                StrainComponentCard(
                    title: "Duration",
                    value: Double(viewModel.workouts.count),
                    percentage: min(Double(viewModel.workouts.count) * 15, 100),
                    icon: "clock.fill",
                    color: .blue,
                    description: "\(viewModel.workouts.count) activity/activities"
                )
                
                // Workout Frequency
                StrainComponentCard(
                    title: "Intensity",
                    value: calculateAverageIntensity(),
                    percentage: (calculateAverageIntensity() / 3.0) * 100,
                    icon: "bolt.fill",
                    color: .yellow,
                    description: "Average HR intensity level"
                )
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Workouts Section
    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S ACTIVITIES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
            
            VStack(spacing: 12) {
                ForEach(viewModel.workouts) { workout in
                    WorkoutStrainCard(workout: workout)
                }
            }
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Weekly Trend Section
    private var weeklyTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-DAY TREND")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
            
            StrainChartView(weeklyData: viewModel.weeklyChartData.map { ($0.date, $0.value) })
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - ACWR Card
    private func acwrCard(_ acwr: Double) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACUTE:CHRONIC WORKLOAD RATIO")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACWR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    
                    Text(String(format: "%.2f", acwr))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(viewModel.acwrStatus?.description ?? "Unknown")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondaryText)
                    
                    HStack(spacing: 4) {
                        Image(systemName: acwrStatusIcon())
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text(acwrStatusText())
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(acwrStatusColor())
                }
            }
            
            Text("Ratio between acute (last 7 days) and chronic (last 28 days) strain. Optimal range: 0.8-1.3")
                .font(.system(size: 12))
                .foregroundColor(.tertiaryText)
                .lineLimit(3)
        }
        .padding(20)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Helper Methods
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<9: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case 9..<14: return Color(red: 0.95, green: 0.7, blue: 0)
        case 14..<18: return Color(red: 1.0, green: 0.5, blue: 0)
        default: return Color(red: 1.0, green: 0.2, blue: 0.2)
        }
    }
    
    private func calculateCardiovascularStrain() -> Double {
        guard !viewModel.workouts.isEmpty else { return 0 }
        return viewModel.workouts.reduce(0.0) { $0 + ($1.heartRateIntensity ?? 0) }
    }
    
    private func calculateMuscularStrain() -> Double {
        guard !viewModel.workouts.isEmpty else { return 0 }
        let totalCalories = viewModel.workouts.reduce(0.0) { $0 + $1.calories }
        return totalCalories > 0 ? min(totalCalories / 100.0, 10.0) : 0
    }
    
    private func calculateAverageIntensity() -> Double {
        guard !viewModel.workouts.isEmpty else { return 0 }
        let totalIntensity = viewModel.workouts.reduce(0.0) { $0 + ($1.heartRateIntensity ?? 0) }
        return totalIntensity / Double(viewModel.workouts.count)
    }
    
    private func acwrStatusIcon() -> String {
        guard let status = viewModel.acwrStatus else { return "questionmark.circle" }
        
        let statusString = status.description.lowercased()
        if statusString.contains("optimal") || statusString.contains("green") {
            return "checkmark.circle.fill"
        } else if statusString.contains("moderate") || statusString.contains("yellow") {
            return "exclamationmark.circle.fill"
        } else if statusString.contains("high") || statusString.contains("red") {
            return "xmark.circle.fill"
        }
        return "questionmark.circle"
    }
    
    private func acwrStatusText() -> String {
        return viewModel.acwrStatus?.description ?? "Unknown"
    }
    
    private func acwrStatusColor() -> Color {
        guard let status = viewModel.acwrStatus else { return .secondaryText }
        
        let statusString = status.description.lowercased()
        if statusString.contains("optimal") || statusString.contains("green") {
            return Color(red: 0.2, green: 0.8, blue: 0.2)
        } else if statusString.contains("moderate") || statusString.contains("yellow") {
            return Color(red: 0.95, green: 0.7, blue: 0)
        } else if statusString.contains("high") || statusString.contains("red") {
            return Color(red: 1.0, green: 0.2, blue: 0.2)
        }
        return .secondaryText
    }
}

// MARK: - Strain Gauge Component
struct StrainGaugeView: View {
    let strain: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondaryCardBackground, lineWidth: 8)
            
            Circle()
                .trim(from: 0, to: min(strain / 21.0, 1.0))
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: strainGaugeColors()),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: strain)
            
            VStack(spacing: 2) {
                Text(String(format: "%.0f", strain))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("/ 21")
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
        }
    }
    
    private func strainGaugeColors() -> [Color] {
        let percent = min(strain / 21.0, 1.0)
        
        if percent < 0.43 {
            return [Color(red: 0.2, green: 0.8, blue: 0.2), Color(red: 0.2, green: 0.8, blue: 0.2)]
        } else if percent < 0.67 {
            return [Color(red: 0.95, green: 0.7, blue: 0), Color(red: 0.95, green: 0.7, blue: 0)]
        } else if percent < 0.86 {
            return [Color(red: 1.0, green: 0.5, blue: 0), Color(red: 1.0, green: 0.5, blue: 0)]
        } else {
            return [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 1.0, green: 0.2, blue: 0.2)]
        }
    }
}

// MARK: - Strain Component Card
struct StrainComponentCard: View {
    let title: String
    let value: Double
    let percentage: Double
    let icon: String
    let color: Color
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", value))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(color)
            }
            
            // Progress bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondaryCardBackground)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.7))
                    .frame(width: max(2, min(CGFloat(percentage / 100.0), 1.0) * 100), alignment: .leading)
            }
            .frame(height: 4)
            
            HStack {
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(12)
        .background(Color.secondaryCardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Workout Strain Card
struct WorkoutStrainCard: View {
    let workout: WorkoutSummary
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: workoutIcon(workout.workoutType))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(strainColor(workout.strain))
                .cornerRadius(10)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(workoutName(workout.workoutType))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                    
                    Text(formatDuration(workout.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                    
                    if workout.calories > 0 {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.warningOrange)
                        
                        Text("\(Int(workout.calories)) kcal")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            
            Spacer()
            
            // Strain badge
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", workout.strain))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(strainColor(workout.strain))
                
                Text("Strain")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryText)
            }
        }
        .padding(12)
        .background(Color.secondaryCardBackground)
        .cornerRadius(12)
    }
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<10: return Color(red: 0.2, green: 0.8, blue: 0.2)
        case 10..<14: return Color(red: 0.95, green: 0.7, blue: 0)
        case 14..<18: return Color(red: 1.0, green: 0.5, blue: 0)
        default: return Color(red: 1.0, green: 0.2, blue: 0.2)
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    NavigationStack {
        StrainDetailView()
    }
}
