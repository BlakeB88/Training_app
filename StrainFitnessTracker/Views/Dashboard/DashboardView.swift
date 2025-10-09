//
//  DashboardView.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//  Updated: Dark/Light mode support & DataSyncService integration
//

import SwiftUI
import HealthKit

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingSettings = false
    @State private var selectedDate = Date()
    @State private var isDateSelectorExpanded = true
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Background - adapts to light/dark mode
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Collapsible Date selector
                        collapsibleDateSelector

                        if viewModel.isLoading {
                            loadingView
                        } else if let error = viewModel.errorMessage {
                            errorView(error)
                        } else if viewModel.hasDataForToday {
                            // Main content
                            mainContent
                        } else {
                            emptyStateView
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationTitle("Dashboard")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.primary)
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingSettings) {
                Text("Settings View") // Placeholder
            }
        }
        .task {
            await viewModel.initialize()
        }
    }

    // MARK: - Collapsible Date Selector
    private var collapsibleDateSelector: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDateSelectorExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(selectedDate.formatted(.dateTime.month().day().year()))
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isDateSelectorExpanded ? 180 : 0))
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expandable navigation controls
            if isDateSelectorExpanded {
                VStack(spacing: 12) {
                    Divider()
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                                    .font(.subheadline)
                            }
                            .foregroundColor(selectedDate <= Calendar.current.date(byAdding: .day, value: -7, to: Date())! ? .gray : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .disabled(selectedDate <= Calendar.current.date(byAdding: .day, value: -7, to: Date())!)
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                selectedDate = Date()
                            }
                        } label: {
                            Text("Today")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text("Next")
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(selectedDate >= Date().startOfDay ? .gray : .blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .disabled(selectedDate >= Date().startOfDay)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
    }

    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 20) {
            // Strain Ring
            strainSection

            // Recovery Card
            recoverySection

            // Quick Stats
            quickStatsSection

            // Today's Workouts
            if let metrics = viewModel.todayMetrics, !metrics.workouts.isEmpty {
                workoutsSection(metrics.workouts)
            }

            // Weekly Summary
            weeklySummarySection
        }
    }

    // MARK: - Strain Section
    private var strainSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Today's Strain")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                NavigationLink {
                    Text("Strain Detail View") // Placeholder
                } label: {
                    HStack(spacing: 4) {
                        Text("Details")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }

            StrainRingView(
                strain: viewModel.todayStrain,
                size: 200,
                lineWidth: 24
            )

            // Strain level description
            Text(strainDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
    }

    private var strainDescription: String {
        let strain = viewModel.todayStrain
        switch strain {
        case 0..<AppConstants.Strain.lightMax:
            return "Light activity day. Good for recovery."
        case AppConstants.Strain.lightMax..<AppConstants.Strain.moderateMax:
            return "Moderate strain. Balanced training load."
        case AppConstants.Strain.moderateMax..<AppConstants.Strain.hardMax:
            return "Hard training day. Monitor recovery."
        default:
            return "Very high strain. Prioritize rest."
        }
    }

    // MARK: - Recovery Section
    private var recoverySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Recovery")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                NavigationLink {
                    Text("Recovery Detail View") // Placeholder
                } label: {
                    HStack(spacing: 4) {
                        Text("Details")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            RecoveryCardView(
                recovery: viewModel.todayRecovery,
                components: viewModel.todayMetrics?.recoveryComponents,
                compact: false
            )
        }
    }

    // MARK: - Quick Stats Section
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            QuickStatCard(
                icon: "figure.run",
                label: "Workouts",
                value: "\(viewModel.todayWorkoutCount)",
                color: .blue
            )

            if let sleep = viewModel.todayMetrics?.sleepDuration {
                QuickStatCard(
                    icon: "bed.double.fill",
                    label: "Sleep",
                    value: sleep.asHoursMinutes,
                    color: .purple
                )
            }

            if let hrv = viewModel.todayMetrics?.hrvAverage {
                QuickStatCard(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: "\(Int(hrv)) ms",
                    color: .green
                )
            }
        }
    }

    // MARK: - Workouts Section
    private func workoutsSection(_ workouts: [WorkoutSummary]) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Today's Workouts")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()

                NavigationLink {
                    Text("Workout History View") // Placeholder
                } label: {
                    HStack(spacing: 4) {
                        Text("View All")
                            .font(.subheadline)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)

            ForEach(workouts.prefix(3)) { workout in
                WorkoutRowView(workout: workout)
            }
        }
    }

    // MARK: - Weekly Summary Section
    private var weeklySummarySection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("7-Day Average")
                    .font(.headline)
                    .foregroundColor(.secondary)

                Spacer()
            }

            HStack(spacing: 16) {
                if let avgStrain = viewModel.weeklyAverageStrain {
                    WeeklySummaryCard(
                        title: "Strain",
                        value: avgStrain.formatted(.number.precision(.fractionLength(1))),
                        icon: "flame.fill",
                        color: .orange
                    )
                }

                if let avgRecovery = viewModel.weeklyAverageRecovery {
                    WeeklySummaryCard(
                        title: "Recovery",
                        value: "\(Int(avgRecovery))%",
                        icon: "heart.fill",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading your data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    // MARK: - Error View
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.refresh()
                }
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("No Data Yet")
                .font(.title2.bold())

            Text("Complete a workout to start tracking your strain and recovery.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await viewModel.syncToday()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                        Text("Syncing...")
                    } else {
                        Image(systemName: "arrow.clockwise")
                        Text("Sync Now")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(viewModel.isSyncing ? Color.blue.opacity(0.6) : Color.blue)
                .clipShape(Capsule())
            }
            .disabled(viewModel.isSyncing)
            
            // Show last sync time if available
            if let lastSync = viewModel.lastSyncDate {
                Text("Last synced: \(lastSync.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .padding(.top, 60)
    }
}

// MARK: - Supporting Views

struct QuickStatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
    }
}

struct WorkoutRowView: View {
    let workout: WorkoutSummary
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Workout icon
            Image(systemName: workoutIcon(workout.workoutType))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.1))
                .clipShape(Circle())

            // Workout info
            VStack(alignment: .leading, spacing: 4) {
                Text(workoutName(workout.workoutType))
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)

                HStack(spacing: 8) {
                    Text(workout.duration.asMinutes)

                    if let distance = workout.distance {
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

            // Strain badge
            VStack(spacing: 2) {
                Text(workout.strain.formatted(.number.precision(.fractionLength(1))))
                    .font(.headline.bold())
                    .foregroundColor(strainColor(workout.strain))

                Text("Strain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
    }

    private func strainColor(_ strain: Double) -> Color {
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
    
    private func workoutIcon(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .swimming: return "figure.pool.swim"
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stairs"
        case .highIntensityIntervalTraining: return "flame.fill"
        default: return "figure.mixed.cardio"
        }
    }
    
    private func workoutName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .swimming: return "Swimming"
        case .running: return "Running"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .hiking: return "Hiking"
        case .functionalStrengthTraining: return "Strength Training"
        case .traditionalStrengthTraining: return "Weight Training"
        case .yoga: return "Yoga"
        case .rowing: return "Rowing"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stair Climbing"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}

struct WeeklySummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)

            Text(value)
                .font(.title.bold())
                .foregroundColor(.primary)

            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Helper Extensions

extension Double {
    var asHoursMinutes: String {
        let hours = Int(self)
        let minutes = Int((self - Double(hours)) * 60)
        return "\(hours)h \(minutes)m"
    }

    var asMinutes: String {
        "\(Int(self)) min"
    }

    var asKilometers: String {
        String(format: "%.2f km", self / 1000)
    }
}

// MARK: - Preview
#Preview {
    DashboardView()
}
