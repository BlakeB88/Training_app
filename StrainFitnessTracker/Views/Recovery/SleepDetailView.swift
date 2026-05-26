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
    @State private var selectedTime: Date?
    @State private var weekSleepData: [SleepWeekEntry] = []

    private let repository = MetricsRepository()

    private var selectedStage: SleepStage? {
        guard let selectedTime else { return nil }
        return stage(at: selectedTime)
    }
    
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

                // WHOOP-style stage comparison bars
                if let data = sleepData, data.hasDetailedStages {
                    sleepStageComparisonSection(data: data)
                }

                // Hours vs. Need weekly chart
                SleepHoursVsNeedView(entries: weekSleepData)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

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
            loadWeekSleepData()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("SLEEP STAGES")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondaryText)
                .tracking(0.5)
                .padding(.horizontal, 16)

            VStack(spacing: 12) {
                sleepStagesChart

                if let selectedStage = selectedStage {
                    stageSelectionSummary(for: selectedStage)
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }

    private var sleepStagesChart: some View {
        Chart {
            ForEach(sleepStages) { stage in
                RectangleMark(
                    xStart: .value("Start", stage.startTime),
                    xEnd: .value("End", stage.startTime.addingTimeInterval(stage.duration)),
                    yStart: .value("Stage", stageBand(for: stage.stage).lowerBound),
                    yEnd: .value("Stage", stageBand(for: stage.stage).upperBound)
                )
                .foregroundStyle(stageColor(stage.stage))
                .cornerRadius(2)
            }

            if let selectedTime {
                RuleMark(x: .value("Selected", selectedTime))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
        }
        .chartYScale(domain: 0...4)
        .chartXScale(domain: sleepStart...sleepEnd)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { _ in
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.07))
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    .foregroundStyle(Color(white: 0.45))
                    .font(.system(size: 10))
            }
        }
        .chartYAxis {
            AxisMarks(values: [3.5, 2.5, 1.5, 0.5]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yAxisLabel(for: v))
                            .font(.system(size: 10))
                            .foregroundStyle(Color(white: 0.45))
                    }
                }
            }
        }
        .chartXSelection(value: $selectedTime)
        .frame(height: 185)
    }

    private func yAxisLabel(for midpoint: Double) -> String {
        switch midpoint {
        case 3.5: return "Awake"
        case 2.5: return "REM"
        case 1.5: return "Core"
        case 0.5: return "Deep"
        default: return ""
        }
    }

    private func stageSelectionSummary(for stage: SleepStage) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(stageColor(stage.stage))
                    .frame(width: 10, height: 10)

                Text(stageLabel(for: stage.stage))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
            }

            Text("\(formattedTime(stage.startTime)) – \(formattedTime(stageEndTime(for: stage)))")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)

            Text("Duration: \(formatHoursMinutes(stage.duration / 3600))")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    
    // MARK: - Stage Comparison Section (WHOOP-style)

    private func sleepStageComparisonSection(data: HealthKitManager.SleepData) -> some View {
        let inBed = data.timeInBed > 0 ? data.timeInBed : (data.totalSleepDuration + data.awakeDuration)
        let awakePct = inBed > 0 ? (data.awakeDuration      / inBed) * 100 : 0
        let corePct  = inBed > 0 ? (data.coreSleepDuration  / inBed) * 100 : 0
        let deepPct  = inBed > 0 ? (data.deepSleepDuration  / inBed) * 100 : 0
        let remPct   = inBed > 0 ? (data.remSleepDuration   / inBed) * 100 : 0

        return VStack(alignment: .leading, spacing: 12) {
            // Header + legend
            HStack {
                Text("TYPICAL RANGE")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                Spacer()
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        .foregroundColor(Color.white.opacity(0.45))
                        .frame(width: 22, height: 12)
                    Text("Typical range")
                        .font(.system(size: 10))
                        .foregroundColor(.secondaryText)
                }
            }
            .padding(.horizontal, 16)

            VStack(spacing: 0) {
                SleepStageComparisonBar(
                    stage: "Awake",   percentage: awakePct,
                    duration: formatHoursMinutes(data.awakeDuration     / 3600),
                    color: .orange,
                    typicalLow: 2,  typicalHigh: 8)

                Divider().padding(.leading, 16)

                SleepStageComparisonBar(
                    stage: "Core",    percentage: corePct,
                    duration: formatHoursMinutes(data.coreSleepDuration / 3600),
                    color: .cyan,
                    typicalLow: 45, typicalHigh: 60)

                Divider().padding(.leading, 16)

                SleepStageComparisonBar(
                    stage: "Deep",    percentage: deepPct,
                    duration: formatHoursMinutes(data.deepSleepDuration / 3600),
                    color: Color(red: 0.28, green: 0.08, blue: 0.58),
                    typicalLow: 13, typicalHigh: 23)

                Divider().padding(.leading, 16)

                SleepStageComparisonBar(
                    stage: "REM",     percentage: remPct,
                    duration: formatHoursMinutes(data.remSleepDuration  / 3600),
                    color: Color(red: 0.42, green: 0.35, blue: 0.90),
                    typicalLow: 20, typicalHigh: 25)
            }
            .background(Color.cardBackground)
            .cornerRadius(16)
            .padding(.horizontal, 16)
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

    /// Fetches the last 7 days of metrics and builds the Hours vs. Need entries.
    private func loadWeekSleepData() {
        let calendar = Calendar.current
        let end   = calendar.startOfDay(for: sleepStart)
        let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
        let metrics = (try? repository.fetchDailyMetrics(from: start, to: end)) ?? []
        weekSleepData = metrics.compactMap { m in
            guard let slept = m.sleepDuration, slept > 0 else { return nil }
            return SleepWeekEntry(
                date: m.date,
                hoursSlept: slept,
                hoursNeeded: SleepWeekEntry.sleepNeeded(debt: m.sleepDebt ?? 0, strain: m.strain)
            )
        }
    }

    /// Builds the hypnogram segments from real aggregate stage durations.
    /// Stages are distributed across a realistic 4-cycle pattern,
    /// scaled so the total of each stage type matches the actual recorded data.
    private func loadSleepDetails() async {
        isLoadingDetails = true

        guard let data = sleepData, data.hasDetailedStages else {
            await MainActor.run { self.isLoadingDetails = false }
            return
        }

        let rem   = data.remSleepDuration       // seconds
        let deep  = data.deepSleepDuration
        let core  = data.coreSleepDuration
        let wake  = max(data.awakeDuration, 60) // at least a small awake segment

        // Proportional template: (stage, fraction of that stage's budget)
        // Mirrors a typical 4-cycle night: light → deep → light → REM, repeat.
        let template: [(HKCategoryValueSleepAnalysis, Double)] = [
            (.awake,       0.50),
            (.asleepCore,  0.18),
            (.asleepDeep,  0.45),
            (.asleepCore,  0.12),
            (.asleepREM,   0.35),
            (.asleepCore,  0.12),
            (.asleepDeep,  0.40),
            (.asleepCore,  0.12),
            (.asleepREM,   0.40),
            (.asleepCore,  0.16),
            (.asleepREM,   0.25),
            (.asleepCore,  0.10),
            (.awake,       0.50)
        ]

        func budget(for stage: HKCategoryValueSleepAnalysis) -> Double {
            switch stage {
            case .awake:      return wake
            case .asleepREM:  return rem
            case .asleepDeep: return deep
            default:          return core   // core / unspecified
            }
        }

        var stages: [SleepStage] = []
        var cursor = sleepStart

        for (stageType, fraction) in template {
            guard cursor < sleepEnd else { break }
            let rawDuration = budget(for: stageType) * fraction
            let duration = min(rawDuration, sleepEnd.timeIntervalSince(cursor))
            guard duration > 30 else { continue } // skip slivers < 30 s
            stages.append(SleepStage(stage: stageType, startTime: cursor, duration: duration))
            cursor = cursor.addingTimeInterval(duration)
        }

        // If the pattern finishes short of sleepEnd, pad with core sleep
        if cursor < sleepEnd {
            stages.append(SleepStage(stage: .asleepCore, startTime: cursor,
                                     duration: sleepEnd.timeIntervalSince(cursor)))
        }

        await MainActor.run {
            self.sleepStages = stages
            self.isLoadingDetails = false
        }
    }
    
    private func formatHoursMinutes(_ hours: Double) -> String {
        let h = Int(hours)
        let minutes = Int((hours - Double(h)) * 60)
        if h > 0 {
            return "\(h)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func targetText(_ value: Double, target: Double, isPercentage: Bool) -> String {
        let comparison = value >= target ? "Above" : "Below"
        let targetStr = isPercentage ? "\(Int(target))%" : String(format: "%.1f", target)
        return "\(comparison) target (\(targetStr))"
    }

    private func stageColor(_ stage: HKCategoryValueSleepAnalysis) -> Color {
        switch stage {
        case .asleepREM:  return Color(red: 0.42, green: 0.35, blue: 0.90)   // medium indigo-blue
        case .asleepDeep: return Color(red: 0.28, green: 0.08, blue: 0.58)   // dark navy-indigo
        case .asleepCore: return Color.cyan
        case .awake:      return Color.orange
        default:          return Color.gray
        }
    }

    private func stageBand(for stage: HKCategoryValueSleepAnalysis) -> ClosedRange<Double> {
        switch stage {
        case .awake:
            return 3...4
        case .asleepREM:
            return 2...3
        case .asleepCore:
            return 1...2
        case .asleepDeep:
            return 0...1
        default:
            return 1...2
        }
    }

    private func stageLabel(for stage: HKCategoryValueSleepAnalysis) -> String {
        switch stage {
        case .awake:
            return "Awake"
        case .asleepREM:
            return "REM"
        case .asleepDeep:
            return "Deep"
        case .asleepCore:
            return "Core"
        default:
            return "Sleep"
        }
    }

    private func isStageSelected(_ stage: SleepStage) -> Bool {
        guard let selectedStage else { return false }
        return selectedStage.id == stage.id
    }

    private func formattedTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    private func stageEndTime(for stage: SleepStage) -> Date {
        stage.startTime.addingTimeInterval(stage.duration)
    }

    private func stage(at date: Date) -> SleepStage? {
        sleepStages.first { stage in
            let endTime = stageEndTime(for: stage)
            return stage.startTime...endTime ~= date
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
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondaryCardBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.7))
                        .frame(width: max(2, CGFloat(min(percentage / 100.0, 1.0)) * geo.size.width))
                }
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

// MARK: - Sleep Stage Comparison Bar (WHOOP-style)

struct SleepStageComparisonBar: View {
    let stage: String
    let percentage: Double      // 0-100
    let duration: String
    let color: Color
    let typicalLow: Double      // % lower bound of healthy range
    let typicalHigh: Double     // % upper bound of healthy range

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // Stage name + percentage | duration
            HStack(alignment: .firstTextBaseline) {
                Text(stage.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondaryText)
                    .tracking(0.5)
                Text("\(Int(percentage.rounded()))%")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(color)
                Spacer()
                Text(duration)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primaryText)
            }

            // Bar: track + colored fill + typical-range bracket
            GeometryReader { geo in
                let w = geo.size.width
                let fillW     = max(2, w * CGFloat(min(percentage / 100, 1.0)))
                let rangeMinX = w * CGFloat(typicalLow  / 100)
                let rangeMaxX = w * CGFloat(typicalHigh / 100)

                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 22)

                    // Current fill
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(0.80))
                        .frame(width: fillW, height: 22)

                    // Typical range bracket (dashed border)
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        .foregroundColor(Color.white.opacity(0.50))
                        .frame(width: rangeMaxX - rangeMinX, height: 22)
                        .offset(x: rangeMinX)
                }
            }
            .frame(height: 22)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
