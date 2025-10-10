//
//  DashboardView.swift
//  StrainFitnessTracker
//
//  Main dashboard view - FIXED to use real HealthKit data
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel(
        dataSyncService: .shared,
        repository: MetricsRepository(),
        stressMonitorVM: StressMonitorViewModel(healthKitManager: HealthKitManager.shared)
    )
    @State private var selectedDate = Date()
    
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
                            
                            // My Dashboard (Detailed Metrics)
                            myDashboardSection
                            
                            // Stress Monitor Graph
                            stressMonitorSection
                            
                            // Strain & Recovery Chart
                            strainRecoverySection
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                    .refreshable {
                        await viewModel.refreshData()
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
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            // Add activity action
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 56, height: 56)
                                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 90)
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
            // Load data when view appears
            print("📱 Dashboard appeared, loading data...")
            await viewModel.refreshData()
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                print("📅 Date changed to \(newDate)")
                await viewModel.loadData(for: newDate)
            }
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
                
                Text("HG")
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
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondaryText)
                }
                
                Button(action: {
                    selectedDate = Date()
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
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
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
        .padding(.top, 8)
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
                CircularProgressView(
                    title: "Sleep",
                    value: viewModel.metrics.sleepScore,
                    color: .sleepBlue
                )
                
                CircularProgressView(
                    title: "Recovery",
                    value: viewModel.metrics.recoveryScore,
                    color: .recoveryGreen
                )
                
                CircularProgressView(
                    title: "Strain",
                    value: viewModel.metrics.strainScore,
                    maxValue: 21,
                    color: .strainBlue,
                    showPercentage: false
                )
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
            
            // Daily Outlook
            DailyOutlookCard()
            
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
                        ActivityCardView(activity: activity)
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
            
            // Action buttons
            HStack(spacing: 12) {
                Button(action: {
                    // Add activity action
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("ADD ACTIVITY")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Start activity action
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 14, weight: .semibold))
                        
                        Text("START ACTIVITY")
                            .font(.system(size: 13, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.cardBackground)
                    .cornerRadius(12)
                }
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
                
                Button(action: {
                    // Customize action
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                        
                        Text("CUSTOMIZE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(.accentBlue)
                }
            }
            
            // Metric cards
            VStack(spacing: 12) {
                ForEach(viewModel.detailedMetrics) { metric in
                    MetricCardView(metric: metric)
                }
            }
        }
    }
    
    // MARK: - Stress Monitor Section
    private var stressMonitorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !viewModel.metrics.stressHistory.isEmpty {
                StressMonitorView(
                    stressData: viewModel.metrics.stressHistory,
                    currentStress: viewModel.metrics.currentStress,
                    activities: viewModel.metrics.activities
                )
            } else {
                // Empty state for stress
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 40))
                        .foregroundColor(.secondaryText)
                    
                    Text("Stress data will appear here")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondaryText)
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
}

// MARK: - Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
