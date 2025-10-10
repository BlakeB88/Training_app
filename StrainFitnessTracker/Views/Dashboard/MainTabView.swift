//
//  MainTabView.swift
//  StrainFitnessTracker
//
//  Main tab bar navigation matching Whoop design
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Tab = .home
    
    enum Tab {
        case home
        case health
        case stress
        case more
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .home:
                    DashboardView()
                case .health:
                    HealthView()
                case .stress:
                    StressView()
                case .more:
                    MoreView()
                }
            }
            
            // Custom Tab Bar
            HStack(spacing: 0) {
                TabBarButton(
                    icon: "house.fill",
                    label: "Home",
                    isSelected: selectedTab == .home
                ) {
                    selectedTab = .home
                }
                
                TabBarButton(
                    icon: "heart.text.square.fill",
                    label: "Health",
                    isSelected: selectedTab == .health
                ) {
                    selectedTab = .health
                }
                
                TabBarButton(
                    icon: "brain.head.profile",
                    label: "Stress",
                    isSelected: selectedTab == .stress
                ) {
                    selectedTab = .stress
                }
                
                TabBarButton(
                    icon: "line.3.horizontal",
                    label: "More",
                    isSelected: selectedTab == .more
                ) {
                    selectedTab = .more
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .background(
                Color.cardBackground
                    .ignoresSafeArea(edges: .bottom)
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .accentBlue : .secondaryText)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .accentBlue : .secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Placeholder Views
struct HealthView: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("Health Monitor")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("Detailed health metrics and trends")
                    .font(.system(size: 16))
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

struct StressView: View {
    @StateObject private var viewModel = DashboardViewModel(
        dataSyncService: .shared,
        repository: MetricsRepository(),
        stressMonitorVM: StressMonitorViewModel(healthKitManager: HealthKitManager.shared)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading stress data...")
                            .font(.headline)
                            .foregroundColor(.secondaryText)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Current Stress Card
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Current Stress Level")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primaryText)
                                    
                                    Spacer()
                                }
                                
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Text(String(format: "%.1f", viewModel.metrics.currentStress))
                                        .font(.system(size: 60, weight: .bold, design: .rounded))
                                        .foregroundColor(.primaryText)
                                    
                                    Text(stressLevel.uppercased())
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(stressLevelColor)
                                        .tracking(0.5)
                                }
                                
                                Text("Last updated \(formattedLastUpdate)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.tertiaryText)
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity)
                            .background(Color.cardBackground)
                            .cornerRadius(20)
                            
                            // Stress Monitor Chart
                            if !viewModel.metrics.stressHistory.isEmpty {
                                StressMonitorView(
                                    stressData: viewModel.metrics.stressHistory,
                                    currentStress: viewModel.metrics.currentStress,
                                    activities: viewModel.metrics.activities
                                )
                            }
                            
                            // Stress Tips Card
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Managing Stress")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.primaryText)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    StressTipRow(icon: "leaf.fill", text: "Take deep breaths")
                                    StressTipRow(icon: "figure.walk", text: "Go for a short walk")
                                    StressTipRow(icon: "moon.stars.fill", text: "Get quality sleep")
                                    StressTipRow(icon: "drop.fill", text: "Stay hydrated")
                                }
                            }
                            .padding(24)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cardBackground)
                            .cornerRadius(20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await viewModel.refreshData()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Stress Monitor")
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
            await viewModel.refreshData()
        }
    }
    
    private var stressLevel: String {
        if viewModel.metrics.currentStress < 1.0 {
            return "Low"
        } else if viewModel.metrics.currentStress < 2.0 {
            return "Medium"
        } else {
            return "High"
        }
    }
    
    private var stressLevelColor: Color {
        if viewModel.metrics.currentStress < 1.0 {
            return .stressLow
        } else if viewModel.metrics.currentStress < 2.0 {
            return .stressMedium
        } else {
            return .stressHigh
        }
    }
    
    private var formattedLastUpdate: String {
        guard let lastPoint = viewModel.metrics.stressHistory.last else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastPoint.timestamp)
    }
}

struct StressTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentBlue)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                List {
                    Section {
                        NavigationLink(destination: Text("Profile")) {
                            Label("Profile", systemImage: "person.fill")
                        }
                        
                        NavigationLink(destination: Text("Settings")) {
                            Label("Settings", systemImage: "gearshape.fill")
                        }
                        
                        NavigationLink(destination: Text("Notifications")) {
                            Label("Notifications", systemImage: "bell.fill")
                        }
                    }
                    
                    Section {
                        NavigationLink(destination: Text("Help & Support")) {
                            Label("Help & Support", systemImage: "questionmark.circle.fill")
                        }
                        
                        NavigationLink(destination: Text("About")) {
                            Label("About", systemImage: "info.circle.fill")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.appBackground)
            }
            .navigationTitle("More")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
