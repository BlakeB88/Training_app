import SwiftUI

struct HunterStatsView: View {
    @StateObject private var viewModel = HunterStatsViewModel()

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
                Text("\(timeToNextRank.formattedTime()) to next rank")
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
}
