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
                    HealthChatView()
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
                    icon: "bubble.left.and.bubble.right",
                    label: "Health Chat",
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
                            // Current Stress Card (Hero Section)
                            currentStressCard
                            
                            // Stress Metrics Grid
                            stressMetricsGrid
                            
                            // Stress Monitor Chart
                            if !viewModel.metrics.stressHistory.isEmpty {
                                StressMonitorView(
                                    stressData: viewModel.metrics.stressHistory,
                                    currentStress: viewModel.metrics.currentStress,
                                    activities: viewModel.metrics.activities
                                )
                            } else {
                                emptyStressChart
                            }
                            
                            // Stress Distribution Card
                            stressDistributionCard
                            
                            // Stress Tips Card
                            stressTipsCard
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
            await viewModel.initialize()
        }
    }
    
    // MARK: - Current Stress Card (Hero Section)
    private var currentStressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("CURRENT STRESS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondaryText)
                        .tracking(1)
                    
                    Text("Last updated \(formattedLastUpdate)")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%.1f", viewModel.metrics.currentStress))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(stressLevel.uppercased())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(stressLevelColor)
                        .tracking(0.5)
                    
                    Text("STRESS")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.tertiaryText)
                        .tracking(0.5)
                }
            }
            
            // Stress level indicator bar
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(barColor(for: index))
                        .frame(height: 8)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Stress Metrics Grid
    private var stressMetricsGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Text("TODAY'S STRESS METRICS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(1)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    stressMetricCard(
                        title: "Average",
                        value: viewModel.metrics.stressHistory.isEmpty ? 0 :
                            viewModel.metrics.stressHistory.map { $0.value }.reduce(0, +) / Double(viewModel.metrics.stressHistory.count),
                        icon: "chart.bar.fill",
                        color: .stressMedium
                    )
                    
                    stressMetricCard(
                        title: "Max",
                        value: viewModel.metrics.stressHistory.map { $0.value }.max() ?? 0,
                        icon: "arrow.up.circle.fill",
                        color: .stressHigh
                    )
                }
                
                HStack(spacing: 12) {
                    stressReadingsCard
                    
                    timeInHighStressCard
                }
            }
        }
    }
    
    // MARK: - Stress Metric Card Component
    private func stressMetricCard(title: String, value: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
            }
            
            Text(String(format: "%.1f", value))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondaryCardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Stress Readings Card
    private var stressReadingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 14))
                    .foregroundColor(.accentBlue)
                
                Text("READINGS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.metrics.stressHistory.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                
                Text("today")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondaryCardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Time in High Stress Card
    private var timeInHighStressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.warningOrange)
                
                Text("HIGH STRESS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(timeInHighStressFormatted)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primaryText)
                
                Text("hrs")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondaryCardBackground)
        .cornerRadius(16)
    }
    
    // MARK: - Empty Stress Chart
    private var emptyStressChart: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 40))
                .foregroundColor(.secondaryText)
            
            Text("No stress data yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondaryText)
            
            Text("Stress readings will appear as they're collected")
                .font(.system(size: 14))
                .foregroundColor(.tertiaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Stress Distribution Card
    private var stressDistributionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("STRESS DISTRIBUTION")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(1)
            
            VStack(spacing: 12) {
                stressDistributionRow(
                    label: "Low",
                    color: .stressLow,
                    percentage: calculateDistribution(for: 0..<1.0)
                )
                
                stressDistributionRow(
                    label: "Medium",
                    color: .stressMedium,
                    percentage: calculateDistribution(for: 1.0..<2.0)
                )
                
                stressDistributionRow(
                    label: "High",
                    color: .stressHigh,
                    percentage: calculateDistribution(for: 2.0..<4.0)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Stress Distribution Row
    private func stressDistributionRow(label: String, color: Color, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                Text("\(Int(percentage))%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondaryText)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondaryCardBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (percentage / 100), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Stress Tips Card
    private var stressTipsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.warningOrange)
                
                Text("Managing Stress")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primaryText)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                StressTipRow(icon: "lungs.fill", text: "Practice deep breathing exercises")
                StressTipRow(icon: "figure.walk", text: "Take regular movement breaks")
                StressTipRow(icon: "moon.stars.fill", text: "Prioritize quality sleep")
                StressTipRow(icon: "drop.fill", text: "Stay hydrated throughout the day")
                StressTipRow(icon: "leaf.fill", text: "Spend time in nature")
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Helper Methods
    
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
    
    private func barColor(for index: Int) -> Color {
        let level = viewModel.metrics.currentStress
        
        if index == 0 { // Low bar
            return level >= 0 ? (level < 1.0 ? stressLevelColor : .stressLow.opacity(0.3)) : .stressLow.opacity(0.3)
        } else if index == 1 { // Medium bar
            return level >= 1.0 ? (level < 2.0 ? stressLevelColor : .stressMedium.opacity(0.3)) : .stressMedium.opacity(0.3)
        } else { // High bar
            return level >= 2.0 ? stressLevelColor : .stressHigh.opacity(0.3)
        }
    }
    
    private var formattedLastUpdate: String {
        guard let lastPoint = viewModel.metrics.stressHistory.last else { return "N/A" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: lastPoint.timestamp)
    }
    
    private var timeInHighStressFormatted: String {
        let highStressReadings = viewModel.metrics.stressHistory.filter { $0.value >= 2.0 }
        
        guard !highStressReadings.isEmpty,
              let firstReading = highStressReadings.first,
              let lastReading = highStressReadings.last else {
            return "0"
        }
        
        // Calculate approximate time in high stress
        // Assuming readings are roughly evenly distributed
        let totalTime = lastReading.timestamp.timeIntervalSince(firstReading.timestamp)
        let hours = totalTime / 3600
        
        return String(format: "%.1f", max(0, hours))
    }
    
    private func calculateDistribution(for range: Range<Double>) -> Double {
        guard !viewModel.metrics.stressHistory.isEmpty else { return 0 }
        
        let count = viewModel.metrics.stressHistory.filter { range.contains($0.value) }.count
        return (Double(count) / Double(viewModel.metrics.stressHistory.count)) * 100
    }
}

// MARK: - Stress Tip Row Component
struct StressTipRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentBlue.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentBlue)
            }
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.secondaryText)
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct StressView_Previews: PreviewProvider {
    static var previews: some View {
        StressView()
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
