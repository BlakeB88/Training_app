import SwiftUI

struct HunterStatsView: View {
    @StateObject private var viewModel = HunterStatsViewModel()
    @State private var showRankInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                content
            }
            .navigationTitle("Stats")
            .toolbarBackground(Color.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showRankInfo = true }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.accentBlue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.showSwimTimeInput = true
                    }) {
                        Label("Add Time", systemImage: "stopwatch.fill")
                            .foregroundColor(.accentBlue)
                    }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showRankInfo) {
            HunterRankInfoView()
        }
        .sheet(isPresented: $viewModel.showSwimTimeInput) {
            SwimTimeInputView()
                .onDisappear {
                    Task {
                        await viewModel.refresh()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.snapshot == nil {
            ProgressView("Summoning stats...")
                .progressViewStyle(CircularProgressViewStyle(tint: .accentBlue))
                .foregroundColor(.secondaryText)
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.warningOrange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondaryText)
                Button("Retry") {
                    Task { await viewModel.refresh() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        } else if let snapshot = viewModel.snapshot {
            ScrollView {
                VStack(spacing: 16) {
                    HunterPlayerCard(snapshot: snapshot)
                    DailyModifiersBanner(modifiers: snapshot.dailyModifiers, awakenState: snapshot.awakenStateActive)
                    HunterStatGrid(stats: snapshot.statCards)
                    SwimMasterySection(snapshot: snapshot)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .refreshable {
                await viewModel.refresh()
            }
        } else {
            VStack(spacing: 12) {
                Text("No Hunter data yet")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text("Start logging workouts or swims to awaken your stat sheet.")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }
            .padding()
        }
    }
}

// MARK: - Rank Info
private struct HunterRankInfoView: View {
    private let rankDetails: [(rank: HunterRank, description: String)] = [
        (.National, "Elites performing at 90+ scores across categories."),
        (.SPlus, "Exceptional performance with pro-level balance."),
        (.S, "Highly trained across strength, endurance, and recovery."),
        (.A, "Consistent athlete with strong readiness and skill."),
        (.B, "Solid fundamentals with room to sharpen recovery."),
        (.C, "Developing baseline capacity across stats."),
        (.D, "New to training or returning from a break."),
        (.E, "Starter rank while the system learns your baseline.")
    ]

    private var xpRules: [String] {
        [
            "Daily stat average: every 5 points of the stat grid earns 1 XP.",
            "Swim mastery: every 4 points of swim mastery adds 1 XP.",
            "Consistency streak: +1 XP per day on streak (max 15).",
            "Personal records today: +25 XP bonus for any new swim PR."
        ]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ranking & Points")
                        .font(.title2.bold())
                        .foregroundColor(.primaryText)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ranks are based on your weighted stat scores. Higher scores move you toward the next letter grade.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)

                        ForEach(rankDetails, id: \.rank) { detail in
                            HStack(alignment: .top, spacing: 12) {
                                Text(detail.rank.displayName)
                                    .font(.headline)
                                    .foregroundColor(detail.rank.color)
                                    .frame(width: 70, alignment: .leading)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.9)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(Int(detail.rank.minimumScore))+")
                                        .font(.caption.bold())
                                        .foregroundColor(.secondaryText)
                                    Text("Requires at least \(Int(detail.rank.minimumScore)) weighted points in your stat grid.")
                                        .font(.caption2)
                                        .foregroundColor(.secondaryText)
                                    Text(detail.description)
                                        .font(.caption)
                                        .foregroundColor(.primaryText)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
                            .background(Color.cardBackground)
                            .cornerRadius(12)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How points & levels work")
                            .font(.headline)
                            .foregroundColor(.primaryText)
                        Text("XP rolls up your daily stats, swim mastery, and streaks to push your Hunter level forward.")
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(xpRules, id: \.self) { rule in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(.accentBlue)
                                        .font(.caption)
                                    Text(rule)
                                        .font(.caption)
                                        .foregroundColor(.primaryText)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color.cardBackground)
                        .cornerRadius(12)
                    }
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Hunter Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.fraction(0.5), .medium, .large])
    }
}

// MARK: - Player Card
private struct HunterPlayerCard: View {
    let snapshot: HunterStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hunter Rank")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                    HStack(alignment: .bottom, spacing: 8) {
                        Text(snapshot.hunterRank.displayName)
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(snapshot.hunterRank.color)
                        if snapshot.awakenStateActive {
                            Label("Awakened", systemImage: "sparkles")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Level \(snapshot.xpState.level)")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text("+\(snapshot.xpState.earnedToday) XP today")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("XP Progress")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                ProgressView(value: snapshot.xpState.progress)
                    .tint(.accentBlue)
                    .frame(maxWidth: .infinity)
                HStack {
                    Text("\(snapshot.xpState.currentXP) / \(snapshot.xpState.xpToNextLevel) XP")
                    Spacer()
                    Text("Streak: \(snapshot.consistencyStreak)d")
                }
                .font(.caption2)
                .foregroundColor(.secondaryText)
            }

            HStack {
                statMetric(title: "Daily Score", value: String(format: "%.0f", snapshot.dailyScore))
                Spacer()
                statMetric(title: "Overall PI", value: String(format: "%.0f", snapshot.overallPerformanceIndex))
                Spacer()
                statMetric(title: "Swim Mastery", value: snapshot.swimMasteryRank.displayName)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
    }

    private func statMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondaryText)
            Text(value)
                .font(.headline)
                .foregroundColor(.primaryText)
        }
    }
}

// MARK: - Modifier Banner
private struct DailyModifiersBanner: View {
    let modifiers: [DailyModifier]
    let awakenState: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Daily Modifiers")
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Spacer()
                if awakenState {
                    Label("Awakened", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }

            if modifiers.isEmpty {
                Text("No buffs or debuffs today. Hold the line.")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondaryCardBackground)
                    .cornerRadius(14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(modifiers) { modifier in
                            ModifierChip(modifier: modifier)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
}

private struct ModifierChip: View {
    let modifier: DailyModifier

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: modifier.icon)
                .foregroundColor(.primaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text(modifier.title)
                    .font(.caption)
                    .foregroundColor(.primaryText)
                Text(modifier.description)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(chipColor)
        .cornerRadius(16)
    }

    private var chipColor: Color {
        switch modifier.modifierType {
        case .recoveryBuff: return Color.recoveryGreen.opacity(0.2)
        case .strainBuff: return Color.strainBlue.opacity(0.2)
        case .sleepBuff: return Color.sleepBlue.opacity(0.2)
        case .penalty: return Color.dangerRed.opacity(0.2)
        }
    }
}

// MARK: - Stats Grid
private struct HunterStatGrid: View {
    let stats: [HunterStat]
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(stats) { stat in
                HunterStatCardView(stat: stat)
            }
        }
    }
}

private struct HunterStatCardView: View {
    let stat: HunterStat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: stat.category.icon)
                    .font(.title3)
                    .foregroundColor(stat.category.accentColor)
                Spacer()
                Text(stat.rank.displayName)
                    .font(.title3.bold())
                    .foregroundColor(stat.rank.color)
            }
            Text(String(format: "%.0f", stat.score))
                .font(.largeTitle.weight(.bold))
                .foregroundColor(.primaryText)
            Text(stat.explanation)
                .font(.caption)
                .foregroundColor(.secondaryText)
            if let next = stat.nextRankHint {
                Text(next)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
            HStack(spacing: 6) {
                ForEach(stat.positives, id: \.self) { positive in
                    Tag(text: positive, color: .recoveryGreen)
                }
            }
            HStack(spacing: 6) {
                ForEach(stat.negatives, id: \.self) { negative in
                    Tag(text: negative, color: .warningOrange)
                }
            }
            HStack {
                Image(systemName: stat.trend.direction.icon)
                    .foregroundColor(stat.trend.direction.color)
                Text(String(format: "%.1f vs 30d", stat.trend.delta))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
}

private struct Tag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

// MARK: - Swim Section
private struct SwimMasterySection: View {
    let snapshot: HunterStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Swim Mastery")
                        .font(.headline)
                        .foregroundColor(.primaryText)
                    Text("Average PI \(String(format: "%.0f", snapshot.swimMasteryScore)) • Rank \(snapshot.swimMasteryRank.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                Spacer()
            }

            ForEach(snapshot.swimPerformances) { performance in
                SwimEventCard(performance: performance)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
    }
}

private struct SwimEventCard: View {
    let performance: SwimEventPerformance

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(performance.displayDistance)
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Spacer()
                Text(performance.rank.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(performance.rank.color)
            }
            HStack {
                statLine(title: "PR", value: performance.personalRecordFormatted)
                Spacer()
                statLine(title: "WR", value: performance.worldRecordFormatted)
                Spacer()
                statLine(title: "PI", value: String(format: "%.0f", performance.performanceIndex))
            }
            ProgressView(value: performance.progressToNextRank)
                .tint(.accentBlue)
            if let timeToNextRank = performance.timeToNextRank {
                Text(formattedTimeGap(timeToNextRank))
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            } else {
                Text("Top rank achieved")
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .padding()
        .background(Color.secondaryCardBackground)
        .cornerRadius(16)
    }

    private func statLine(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondaryText)
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primaryText)
        }
    }
    
    private func formattedTimeGap(_ seconds: TimeInterval) -> String {
        let absoluteSeconds = abs(seconds)
        
        // For times under 60 seconds, show as seconds with decimal
        if absoluteSeconds < 60 {
            return String(format: "Drop %.2fs to next rank", absoluteSeconds)
        }
        // For times 60 seconds and over, show as minutes with decimal
        else {
            let minutes = absoluteSeconds / 60.0
            return String(format: "Drop %.2f min to next rank", minutes)
        }
    }
}
