//
//  SleepDetailView.swift
//  StrainFitnessTracker
//
//  Detailed sleep view matching iOS Health app style
//  Place in: StrainFitnessTracker/Views/Recovery/
//

import SwiftUI
import HealthKit
import Charts

struct SleepDetailView: View {
    let sleepStart: Date
    let sleepEnd: Date
    let sleepDuration: Double // in hours
    let sleepData: HealthKitManager.SleepData?
    
    @State private var sleepStages: [SleepStage] = []
    @State private var isLoadingDetails = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with moon icon and total duration
                headerSection
                
                // Primary sleep metrics
                primaryMetricsSection
                
                // Sleep stages chart
                if !sleepStages.isEmpty {
                    sleepStagesSection
                }
                
                // Sleep quality metrics
                sleepQualitySection
                
                // Sleep stages breakdown
                if let data = sleepData, data.hasDetailedStages {
                    sleepStagesBreakdownSection
                }
                
                // Schedule details
                scheduleSection
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Sleep")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(sleepStart.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
            }
        }
        .task {
            await loadSleepDetails()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Large moon icon
            ZStack {
                Circle()
                    .fill(Color.sleepBlue.opacity(0.15))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "moon.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.sleepBlue)
            }
            
            // Total sleep time
            VStack(spacing: 4) {
                Text(formatHoursMinutes(sleepDuration))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.primaryText)
                
                Text("Total Sleep")
                    .font(.system(size: 14))
                    .foregroundColor(.secondaryText)
            }
            
            // Sleep quality badge
            sleepQualityBadge
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
            if let data = sleepData {
                PrimarySleepMetric(
                    title: "Time in Bed",
                    value: formatHoursMinutes(data.timeInBed / 3600.0),
                    icon: "bed.double.fill",
                    color: .purple
                )
                
                PrimarySleepMetric(
                    title: "Efficiency",
                    value: "\(Int(data.sleepEfficiency))%",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green
                )
                
                PrimarySleepMetric(
                    title: "Restorative",
                    value: "\(Int(data.restorativeSleepPercentage))%",
                    icon: "sparkles",
                    color: .cyan
                )
            } else {
                PrimarySleepMetric(
                    title: "In Bed",
                    value: formatHoursMinutes(sleepDuration),
                    icon: "bed.double.fill",
                    color: .purple
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Sleep Stages Section
    private var sleepStagesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("SLEEP STAGES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 16) {
                // Timeline chart
                sleepStagesChart
                
                // Time axis labels
                HStack {
                    Text(sleepStart.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                    
                    Spacer()
                    
                    Text(sleepEnd.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
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
    
    private var sleepStagesChart: some View {
        GeometryReader { geometry in
            let totalDuration = sleepEnd.timeIntervalSince(sleepStart)
            
            HStack(spacing: 0) {
                ForEach(sleepStages) { stage in
                    let width = (stage.duration / totalDuration) * geometry.size.width
                    
                    Rectangle()
                        .fill(stageColor(stage.stage))
                        .frame(width: width)
                }
            }
            .frame(height: 60)
            .cornerRadius(8)
        }
        .frame(height: 60)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Sleep Quality Section
    private var sleepQualitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP QUALITY")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                if let data = sleepData {
                    SleepQualityRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Sleep Efficiency",
                        value: "\(Int(data.sleepEfficiency))%",
                        subtitle: targetText(data.sleepEfficiency, target: 85, isPercentage: true),
                        isGood: data.sleepEfficiency >= 85,
                        color: .green
                    )
                    Divider().padding(.leading, 56)
                    
                    SleepQualityRow(
                        icon: "sparkles",
                        title: "Restorative Sleep",
                        value: formatHoursMinutes(data.restorativeSleepDuration / 3600.0),
                        subtitle: "\(Int(data.restorativeSleepPercentage))% of total",
                        isGood: data.restorativeSleepPercentage >= 30,
                        color: .cyan
                    )
                    Divider().padding(.leading, 56)
                    
                    SleepQualityRow(
                        icon: "moon.zzz.fill",
                        title: "Deep Sleep",
                        value: formatHoursMinutes(data.deepSleepDuration / 3600.0),
                        subtitle: "\(Int((data.deepSleepDuration / data.totalSleepDuration) * 100))% of sleep",
                        isGood: data.deepSleepDuration >= 3600,
                        color: .purple
                    )
                    Divider().padding(.leading, 56)
                    
                    SleepQualityRow(
                        icon: "brain.head.profile",
                        title: "REM Sleep",
                        value: formatHoursMinutes(data.remSleepDuration / 3600.0),
                        subtitle: "\(Int((data.remSleepDuration / data.totalSleepDuration) * 100))% of sleep",
                        isGood: data.remSleepDuration >= 5400,
                        color: .indigo
                    )
                    
                    if data.awakeDuration > 0 {
                        Divider().padding(.leading, 56)
                        
                        SleepQualityRow(
                            icon: "eye",
                            title: "Time Awake",
                            value: formatHoursMinutes(data.awakeDuration / 3600.0),
                            subtitle: "\(Int((data.awakeDuration / data.timeInBed) * 100))% in bed",
                            isGood: data.awakeDuration < 1800,
                            color: .orange
                        )
                    }
                }
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Sleep Stages Breakdown
    private var sleepStagesBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP STAGES BREAKDOWN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            if let data = sleepData {
                VStack(spacing: 12) {
                    SleepStageCard(
                        stage: "REM Sleep",
                        duration: data.remSleepDuration / 3600.0,
                        percentage: (data.remSleepDuration / data.totalSleepDuration) * 100,
                        color: .indigo,
                        icon: "brain.head.profile",
                        description: "Memory consolidation and learning"
                    )
                    
                    SleepStageCard(
                        stage: "Deep Sleep",
                        duration: data.deepSleepDuration / 3600.0,
                        percentage: (data.deepSleepDuration / data.totalSleepDuration) * 100,
                        color: .purple,
                        icon: "moon.zzz.fill",
                        description: "Physical recovery and immune function"
                    )
                    
                    SleepStageCard(
                        stage: "Core Sleep",
                        duration: data.coreSleepDuration / 3600.0,
                        percentage: (data.coreSleepDuration / data.totalSleepDuration) * 100,
                        color: .cyan,
                        icon: "cloud.moon.fill",
                        description: "Light sleep and transition stages"
                    )
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SCHEDULE")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)
            
            VStack(spacing: 0) {
                ScheduleRow(
                    title: "Bedtime",
                    value: sleepStart.formatted(date: .omitted, time: .shortened),
                    icon: "bed.double.fill"
                )
                Divider().padding(.leading, 56)
                
                ScheduleRow(
                    title: "Wake Time",
                    value: sleepEnd.formatted(date: .omitted, time: .shortened),
                    icon: "sun.max.fill"
                )
                Divider().padding(.leading, 56)
                
                ScheduleRow(
                    title: "Time in Bed",
                    value: formatHoursMinutes((sleepData?.timeInBed ?? sleepDuration * 3600) / 3600.0),
                    icon: "clock.fill"
                )
                Divider().padding(.leading, 56)
                
                ScheduleRow(
                    title: "Time Asleep",
                    value: formatHoursMinutes(sleepDuration),
                    icon: "moon.fill"
                )
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
        .padding(.bottom, 50)
    }
    
    // MARK: - Sleep Quality Badge
    private var sleepQualityBadge: some View {
        let (text, color): (String, Color) = {
            switch sleepDuration {
            case 7...9: return ("Optimal", Color(red: 0.2, green: 0.8, blue: 0.2))
            case 6..<7, 9..<10: return ("Good", Color(red: 0.95, green: 0.7, blue: 0))
            default: return ("Poor", Color(red: 1.0, green: 0.2, blue: 0.2))
            }
        }()
        
        return Text(text)
            .font(.system(size: 13, weight: .bold))
            .tracking(0.5)
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(color)
            .cornerRadius(20)
    }
    
    // MARK: - Helper Methods
    private func loadSleepDetails() async {
        isLoadingDetails = true
        
        // Generate sleep stages from sleep data
        if let data = sleepData, data.hasDetailedStages {
            var stages: [SleepStage] = []
            var currentTime = sleepStart
            
            // Simplified sleep cycle pattern (actual data would come from HealthKit)
            let cyclePattern: [(HKCategoryValueSleepAnalysis, TimeInterval)] = [
                (.awake, 600),
                (.asleepCore, 1800),
                (.asleepDeep, 2700),
                (.asleepCore, 1800),
                (.asleepREM, 1500),
                (.asleepCore, 1200),
                (.asleepDeep, 2400),
                (.asleepCore, 1800),
                (.asleepREM, 1800),
                (.asleepCore, 900),
                (.awake, 300)
            ]
            
            for (stage, duration) in cyclePattern {
                stages.append(SleepStage(
                    stage: stage,
                    startTime: currentTime,
                    duration: duration
                ))
                currentTime = currentTime.addingTimeInterval(duration)
                
                if currentTime >= sleepEnd {
                    break
                }
            }
            
            await MainActor.run {
                self.sleepStages = stages
                self.isLoadingDetails = false
            }
        } else {
            await MainActor.run {
                self.isLoadingDetails = false
            }
        }
    }
    
    private func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        return "\(h)h \(minutes)m"
    }
    
    private func targetText(_ value: Double, target: Double, isPercentage: Bool) -> String {
        let comparison = value >= target ? "Above" : "Below"
        let targetStr = isPercentage ? "\(Int(target))%" : String(format: "%.1f", target)
        return "\(comparison) target (\(targetStr))"
    }
    
    private func stageColor(_ stage: HKCategoryValueSleepAnalysis) -> Color {
        switch stage {
        case .asleepREM: return Color.indigo
        case .asleepDeep: return Color.purple
        case .asleepCore: return Color.cyan
        case .awake: return Color.orange.opacity(0.5)
        default: return Color.gray
        }
    }
}

// MARK: - Supporting Views

struct PrimarySleepMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primaryText)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
}

struct SleepQualityRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let isGood: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.primaryText)
                
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondaryText)
                
                Image(systemName: isGood ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(isGood ? Color(red: 0.2, green: 0.8, blue: 0.2) : Color(red: 0.95, green: 0.7, blue: 0))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct SleepStageCard: View {
    let stage: String
    let duration: Double
    let percentage: Double
    let color: Color
    let icon: String
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
                    Text(stage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatHoursMinutes(duration))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(color)
                    
                    Text("\(Int(percentage))%")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                }
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
        }
        .padding(12)
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    private func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ScheduleRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentBlue)
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

// MARK: - Data Models

struct SleepStage: Identifiable {
    let id = UUID()
    let stage: HKCategoryValueSleepAnalysis
    let startTime: Date
    let duration: TimeInterval
}

extension HealthKitManager.SleepData {
    var hasDetailedStages: Bool {
        deepSleepDuration > 0 || remSleepDuration > 0 || coreSleepDuration > 0
    }
}

#Preview {
    NavigationStack {
        SleepDetailView(
            sleepStart: Date().addingTimeInterval(-28800),
            sleepEnd: Date(),
            sleepDuration: 8.55,
            sleepData: HealthKitManager.SleepData(
                totalSleepDuration: 30780,
                timeInBed: 40680,
                sleepStart: Date().addingTimeInterval(-28800),
                sleepEnd: Date(),
                restorativeSleepDuration: 10800,
                remSleepDuration: 5400,
                deepSleepDuration: 5400,
                coreSleepDuration: 19980,
                awakeDuration: 1800
            )
        )
    }
}
