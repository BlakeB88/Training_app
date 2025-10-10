//
//  RecoveryDetailView.swift
//  StrainFitnessTracker
//
//  Enhanced to show comprehensive recovery metrics
//  Place in: StrainFitnessTracker/Views/Recovery/
//

import SwiftUI
import Charts

struct RecoveryDetailView: View {
    @StateObject private var viewModel: RecoveryViewModel
    @State private var selectedDate: Date
    @State private var isDateSelectorExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    init(initialDate: Date = Date()) {
        let vm = RecoveryViewModel(selectedDate: initialDate)
        _viewModel = StateObject(wrappedValue: vm)
        _selectedDate = State(initialValue: initialDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date Selector
                collapsibleDatePicker
                
                // Main Recovery Score Card
                mainRecoveryCard
                
                // Recovery Components Breakdown
                if let components = viewModel.recoveryComponents {
                    recoveryComponentsSection(components)
                }
                
                // Key Physiological Metrics
                physiologicalMetricsSection
                
                // Sleep Metrics Section
                sleepMetricsSection
                
                // Weekly Recovery Trend
                weeklyRecoveryTrendSection
                
                // HRV Trend
                if !viewModel.weeklyHRVChartData.isEmpty {
                    HRVTrendView(weeklyData: viewModel.weeklyHRVChartData.map { ($0.date, $0.value) })
                }
                
                // Recovery Tips
                recoveryTipsSection
            }
            .padding()
        }
        .background(Color.appBackground)
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadData()
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.selectDate(newDate)
            }
        }
    }
    
    // MARK: - Main Recovery Card
    private var mainRecoveryCard: some View {
        VStack(spacing: 16) {
            if let recovery = viewModel.currentRecovery {
                // Recovery Score with Ring
                VStack(spacing: 12) {
                    ZStack {
                        // Background ring
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 160, height: 160)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: recovery / 100)
                            .stroke(
                                recoveryGradient(recovery),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 1.0), value: recovery)
                        
                        // Score text
                        VStack(spacing: 4) {
                            Text("\(Int(recovery))")
                                .font(.system(size: 54, weight: .bold))
                                .foregroundColor(.primaryText)
                            
                            Text("RECOVERY")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondaryText)
                                .tracking(1)
                        }
                    }
                    
                    // Recovery Level Badge
                    recoveryLevelBadge(recovery)
                    
                    // Recovery Message
                    Text(recoveryMessage(recovery))
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // No recovery data
                VStack(spacing: 12) {
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 50))
                        .foregroundColor(.secondaryText)
                    
                    Text("No Recovery Data")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    
                    Text("Recovery score will be calculated based on your sleep and physiological metrics")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 30)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
    
    // MARK: - Recovery Components Section
    private func recoveryComponentsSection(_ components: RecoveryComponents) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Factors")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primaryText)
            
            VStack(spacing: 12) {
                if let hrvScore = components.hrvScore {
                    RecoveryFactorCard(
                        title: "Heart Rate Variability",
                        subtitle: "Nervous system recovery",
                        score: hrvScore,
                        icon: "waveform.path.ecg",
                        color: factorColor(hrvScore)
                    )
                }
                
                if let rhrScore = components.restingHRScore {
                    RecoveryFactorCard(
                        title: "Resting Heart Rate",
                        subtitle: "Cardiovascular readiness",
                        score: rhrScore,
                        icon: "heart.fill",
                        color: factorColor(rhrScore)
                    )
                }
                
                if let sleepScore = components.sleepScore {
                    RecoveryFactorCard(
                        title: "Sleep Performance",
                        subtitle: "Rest quality",
                        score: sleepScore,
                        icon: "bed.double.fill",
                        color: factorColor(sleepScore)
                    )
                }
            }
        }
    }
    
    // MARK: - Physiological Metrics Section
    private var physiologicalMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Physiological Metrics")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primaryText)
            
            VStack(spacing: 12) {
                if let hrv = viewModel.hrvAverage {
                    PhysiologicalMetricRow(
                        icon: "waveform.path.ecg",
                        title: "HRV Average",
                        value: String(format: "%.0f ms", hrv),
                        color: .blue
                    )
                }
                
                if let rhr = viewModel.restingHeartRate {
                    PhysiologicalMetricRow(
                        icon: "heart.fill",
                        title: "Resting Heart Rate",
                        value: String(format: "%.0f bpm", rhr),
                        color: .red
                    )
                }
                
                if let respiratory = viewModel.dailyMetrics?.respiratoryRate {
                    PhysiologicalMetricRow(
                        icon: "lungs.fill",
                        title: "Respiratory Rate",
                        value: String(format: "%.1f brpm", respiratory),
                        color: .cyan
                    )
                }
                
                if let vo2Max = viewModel.dailyMetrics?.vo2Max {
                    PhysiologicalMetricRow(
                        icon: "figure.run",
                        title: "VO₂ Max",
                        value: String(format: "%.1f", vo2Max),
                        color: .green
                    )
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Sleep Metrics Section
    private var sleepMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sleep Metrics")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primaryText)
            
            VStack(spacing: 12) {
                if let sleepDuration = viewModel.sleepDuration {
                    SleepMetricCard(
                        icon: "moon.fill",
                        title: "Sleep Duration",
                        value: formatHours(sleepDuration),
                        target: "7-9 hours",
                        isGood: sleepDuration >= 7 && sleepDuration <= 9
                    )
                }
                
                if let efficiency = viewModel.dailyMetrics?.sleepEfficiency {
                    SleepMetricCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Sleep Efficiency",
                        value: String(format: "%.0f%%", efficiency),
                        target: "85%+",
                        isGood: efficiency >= 85
                    )
                }
                
                if let restorative = viewModel.dailyMetrics?.restorativeSleepPercentage {
                    SleepMetricCard(
                        icon: "sparkles",
                        title: "Restorative Sleep",
                        value: String(format: "%.0f%%", restorative),
                        target: "30%+",
                        isGood: restorative >= 30
                    )
                }
                
                if let consistency = viewModel.dailyMetrics?.sleepConsistency {
                    SleepMetricCard(
                        icon: "clock.fill",
                        title: "Sleep Consistency",
                        value: String(format: "%.0f%%", consistency),
                        target: "70%+",
                        isGood: consistency >= 70
                    )
                }
                
                if let debt = viewModel.dailyMetrics?.sleepDebt {
                    SleepMetricCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Sleep Debt",
                        value: formatHours(debt),
                        target: "< 1 hour",
                        isGood: debt < 1
                    )
                }
            }
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(16)
        }
    }
    
    // MARK: - Weekly Recovery Trend
    private var weeklyRecoveryTrendSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Weekly Trend")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Spacer()
                
                if let avgRecovery = viewModel.weeklyAverageRecovery {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Average")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Text("\(Int(avgRecovery))%")
                            .font(.headline)
                            .foregroundColor(.recoveryGreen)
                    }
                }
            }
            
            if !viewModel.weeklyRecoveryChartData.isEmpty {
                recoveryWeekChart
            } else {
                Text("Not enough data for weekly trend")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    private var recoveryWeekChart: some View {
        Chart(viewModel.weeklyRecoveryChartData) { dataPoint in
            BarMark(
                x: .value("Day", dataPoint.date, unit: .day),
                y: .value("Recovery", dataPoint.value)
            )
            .foregroundStyle(recoveryBarGradient(dataPoint.value))
            .cornerRadius(6)
        }
        .frame(height: 200)
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow))
            }
        }
    }
    
    // MARK: - Recovery Tips Section
    private var recoveryTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Tips")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primaryText)
            
            VStack(spacing: 12) {
                RecoveryTipCard(
                    icon: "bed.double.fill",
                    tip: "Aim for 7-9 hours of quality sleep each night",
                    color: .sleepBlue
                )
                
                RecoveryTipCard(
                    icon: "drop.fill",
                    tip: "Stay hydrated throughout the day",
                    color: .accentBlue
                )
                
                RecoveryTipCard(
                    icon: "leaf.fill",
                    tip: "Practice stress management techniques",
                    color: .recoveryGreen
                )
                
                if let recovery = viewModel.currentRecovery, recovery < 67 {
                    RecoveryTipCard(
                        icon: "figure.walk",
                        tip: "Consider light activity or rest day for optimal recovery",
                        color: .warningOrange
                    )
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(16)
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
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                        
                        Text(selectedDate.formatted(.dateTime.month().day().year()))
                            .font(.title3.bold())
                            .foregroundColor(.primaryText)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("Change Date")
                            .font(.subheadline)
                            .foregroundColor(.accentBlue)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.accentBlue)
                            .rotationEffect(.degrees(isDateSelectorExpanded ? 180 : 0))
                    }
                }
                .padding()
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
    }
    
    // MARK: - Helper Functions
    private func recoveryGradient(_ recovery: Double) -> AngularGradient {
        let colors: [Color]
        switch recovery {
        case 0..<34:
            colors = [.recoveryZoneRed, .recoveryZoneRed.opacity(0.7)]
        case 34..<67:
            colors = [.recoveryZoneYellow, .recoveryZoneYellow.opacity(0.7)]
        default:
            colors = [.recoveryGreen, .recoveryGreen.opacity(0.7)]
        }
        return AngularGradient(colors: colors, center: .center)
    }
    
    private func recoveryBarGradient(_ recovery: Double) -> LinearGradient {
        let color: Color
        switch recovery {
        case 0..<34: color = .recoveryZoneRed
        case 34..<67: color = .recoveryZoneYellow
        default: color = .recoveryGreen
        }
        return LinearGradient(
            colors: [color, color.opacity(0.6)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    private func recoveryLevelBadge(_ recovery: Double) -> some View {
        let (text, color): (String, Color) = {
            switch recovery {
            case 67...100: return ("GREEN", .recoveryZoneGreen)
            case 34..<67: return ("YELLOW", .recoveryZoneYellow)
            default: return ("RED", .recoveryZoneRed)
            }
        }()
        
        return Text(text)
            .font(.system(size: 13, weight: .bold))
            .tracking(1)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(20)
    }
    
    private func recoveryMessage(_ recovery: Double) -> String {
        switch recovery {
        case 67...100:
            return "Your body is well recovered. You're ready for high-intensity activities."
        case 34..<67:
            return "Moderate recovery. Consider a balanced workout or active recovery."
        default:
            return "Low recovery. Prioritize rest and recovery activities today."
        }
    }
    
    private func factorColor(_ score: Double) -> Color {
        switch score {
        case 67...100: return .recoveryZoneGreen
        case 34..<67: return .recoveryZoneYellow
        default: return .recoveryZoneRed
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        return "\(h)h \(minutes)m"
    }
}

// MARK: - Supporting Views

struct RecoveryFactorCard: View {
    let title: String
    let subtitle: String
    let score: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Text("\(Int(score))%")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct PhysiologicalMetricRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primaryText)
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(.primaryText)
        }
    }
}

struct SleepMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let target: String
    let isGood: Bool
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isGood ? .recoveryGreen : .warningOrange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primaryText)
                
                Text("Target: \(target)")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Text(value)
                .font(.headline)
                .foregroundColor(isGood ? .recoveryGreen : .primaryText)
        }
        .padding(.vertical, 4)
    }
}

struct RecoveryTipCard: View {
    let icon: String
    let tip: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(tip)
                .font(.subheadline)
                .foregroundColor(.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding()
        .background(Color.secondaryCardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        RecoveryDetailView()
    }
}
