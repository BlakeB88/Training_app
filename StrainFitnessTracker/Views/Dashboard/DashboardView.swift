//
//  DashboardView.swift
//  StrainFitnessTracker
//
//  Main dashboard view - UPDATED to properly display stress data and Hunter Rank Card
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel(
        dataSyncService: .shared,
        repository: MetricsRepository(),
        stressMonitorVM: StressMonitorViewModel(healthKitManager: HealthKitManager.shared)
    )
    @StateObject private var hunterViewModel = HunterStatsViewModel()
    @State private var selectedDate = Date()

    private var todaysSleepActivity: Activity? {
        viewModel.metrics.activities.first { $0.type == .sleep }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading health data...")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header Section
                            headerSection
                            
                            // Primary Metrics (Sleep, Recovery, Strain)
                            primaryMetricsSection
                            
                            // Health & Stress Monitor Cards
                            monitorCardsSection
                            
                            // My Day Section
                            myDaySection
                            
                            // Stats Section Header
                            Text("Stats")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Hunter Rank Card
                            HunterRankCard(snapshot: hunterViewModel.snapshot)
                            
                            // My Dashboard (Detailed Metrics)
                            myDashboardSection
                            
                            // Stress Monitor Graph - UPDATED
                            stressMonitorSection
                            
                            // Strain & Recovery Chart
                            strainRecoverySection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                    .refreshable {
                        await viewModel.refreshData()
                        await hunterViewModel.refresh()
                    }
                }
                
                // Error message
                if let error = viewModel.errorMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.warningOrange)
                            Text(error)
                                .foregroundColor(.primaryText)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Dashboard")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await viewModel.syncHealthKit()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 20))
                            .foregroundColor(.secondaryText)
                    }
                }
            }
        }
        .task {
            // Initialize and load data when view appears
            print("📱 Dashboard appeared, initializing...")
            await viewModel.initialize()
            await hunterViewModel.load()
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack(spacing: 12) {
            // User initial
            ZStack {
                Circle()
                    .fill(Color.warningOrange)
                    .frame(width: 36, height: 36)
                
                Text("BB")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Calories
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.warningOrange)
                
                Text("\(viewModel.metrics.calories)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)
            }
            
            Spacer()
            
            // Date navigation
            HStack(spacing: 16) {
                Button(action: {
                    changeSelectedDate(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondaryText)
                }

                Button(action: {
                    changeSelectedDate(to: Date())
                }) {
                    Text("TODAY")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.secondaryCardBackground)
                        .cornerRadius(20)
                }

                Button(action: {
                    changeSelectedDate(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondaryText)
                }
            }
            
            Spacer()
            
            // Device battery
            HStack(spacing: 4) {
                Image(systemName: "applewatch")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
                
                Text("--")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondaryText)
            }
        }
    }
    
    // MARK: - Primary Metrics Section
    private var primaryMetricsSection: some View {
        VStack(spacing: 16) {
            // App title
            Text("TRAIN")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(4)
            
            // Circular progress indicators
            HStack(spacing: 30) {
                if let sleepActivity = todaysSleepActivity {
                    NavigationLink(
                        destination: SleepDetailView(
                            sleepStart: sleepActivity.startTime,
                            sleepEnd: sleepActivity.endTime,
                            sleepDuration: sleepActivity.duration / 3600.0,
                            sleepData: viewModel.todaysSleepData
                        )
                    ) {
                        CircularProgressView(
                            title: "Sleep",
                            value: viewModel.metrics.sleepScore,
                            color: .sleepBlue,
                            isInteractive: true
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    CircularProgressView(
                        title: "Sleep",
                        value: viewModel.metrics.sleepScore,
                        color: .sleepBlue
                    )
                }

                NavigationLink(destination: RecoveryDetailView(initialDate: selectedDate)) {
                    CircularProgressView(
                        title: "Recovery",
                        value: viewModel.metrics.recoveryScore,
                        color: .recoveryGreen,
                        isInteractive: true
                    )
                }

                NavigationLink(destination: StrainDetailView(initialDate: selectedDate)) {
                    CircularProgressView(
                        title: "Strain",
                        value: viewModel.metrics.strainScore,
                        maxValue: 21,
                        color: .strainBlue,
                        showPercentage: false,
                        isInteractive: true
                    )
                }
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Monitor Cards Section
    private var monitorCardsSection: some View {
        HStack(spacing: 12) {
            HealthMonitorCard(
                metricsInRange: viewModel.metrics.healthMetricsInRange,
                totalMetrics: viewModel.metrics.totalHealthMetrics
            )
            
            StressMonitorCard(
                currentStress: viewModel.metrics.currentStress,
                lastUpdateTime: viewModel.lastStressUpdate
            )
        }
    }
    
    // MARK: - My Day Section
    private var myDaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("My Day")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primaryText)
            
            // Today's Activities
            if !viewModel.metrics.activities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("TODAY'S ACTIVITIES")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondaryText)
                            .tracking(1)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 12))
                            .foregroundColor(.secondaryText)
                    }
                    
                    ForEach(viewModel.metrics.activities) { activity in
                        if activity.type == .sleep {
                            ActivityCardView(
                                activity: activity,
                                workoutDetails: [:],
                                sleepData: viewModel.todaysSleepData
                            )
                        } else {
                            ActivityCardView(
                                activity: activity,
                                workoutDetails: viewModel.workoutDetails,
                                sleepData: nil
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 40))
                        .foregroundColor(.secondaryText)
                    
                    Text("No activities yet today")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    Text("Start tracking your workouts!")
                        .font(.system(size: 14))
                        .foregroundColor(.tertiaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.cardBackground)
                .cornerRadius(16)
            }
        }
    }
    
    // MARK: - My Dashboard Section
    private var myDashboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("My Dashboard")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Spacer()
            }
            
            // Metric cards
            VStack(spacing: 12) {
                ForEach(viewModel.detailedMetrics) { metric in
                    MetricCardView(metric: metric)
                }
            }
        }
    }
    
    // MARK: - Stress Monitor Section - UPDATED
    private var stressMonitorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.metrics.stressHistory.isEmpty {
                StressMonitorView(
                    stressData: viewModel.metrics.stressHistory,
                    currentStress: viewModel.metrics.currentStress,
                    activities: viewModel.metrics.activities
                )
            } else {
                // Empty state with debug info
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 40))
                        .foregroundColor(.secondaryText)
                    
                    Text("Stress data will appear here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
                    
                    Text("Current stress: \(String(format: "%.1f", viewModel.metrics.currentStress))")
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                    
                    Button("Refresh Data") {
                        Task {
                            await viewModel.refreshData()
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentBlue)
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.cardBackground)
                .cornerRadius(20)
            }
        }
    }
    
    // MARK: - Strain & Recovery Section
    private var strainRecoverySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            StrainRecoveryChartView(weekData: viewModel.weekData)
        }
    }

    // MARK: - Date Handling
    private func changeSelectedDate(by days: Int) {
        let newDate = selectedDate.startOfDay.adding(days: days)
        changeSelectedDate(to: newDate)
    }

    private func changeSelectedDate(to date: Date) {
        let normalizedDate = date.startOfDay
        selectedDate = normalizedDate

        Task {
            print("📅 Loading data for \(normalizedDate)")
            await viewModel.loadData(for: normalizedDate, forceRefresh: true)
        }
    }
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
