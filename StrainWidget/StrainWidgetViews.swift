import SwiftUI
import WidgetKit

// MARK: - Entry View Router

struct StrainWidgetEntryView: View {
    let entry: StrainWidgetEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            LargeWidgetView(entry: entry)
        }
    }
}

// MARK: - Large: 2×2 grid
// Layout: Sleep(TL)  Recovery(TR)
//         Strain(BL) Rank(BR)

struct LargeWidgetView: View {
    let entry: StrainWidgetEntry

    var body: some View {
        if entry.hasData {
            GeometryReader { geo in
                let cellSize = min(geo.size.width / 2 - 20, geo.size.height / 2 - 20)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        // ── Top Left: Sleep ──
                        DashboardRing(
                            progress: Double(entry.sleepScore ?? 0) / 100.0,
                            color: sleepBlue,
                            label: entry.sleepScore.map { "\($0)%" }
                                ?? entry.sleepHours.map { formatSleep($0) } ?? "--",
                            title: "SLEEP",
                            lineWidth: 9,
                            fontSize: 22,
                            captionSize: 12
                        )
                        .frame(width: cellSize, height: cellSize)

                        // ── Top Right: Recovery ──
                        DashboardRing(
                            progress: Double(entry.recovery ?? 0) / 100.0,
                            color: recoveryColor(entry.recovery ?? 0),
                            label: "\(entry.recovery ?? 0)%",
                            title: "RECOVERY",
                            lineWidth: 9,
                            fontSize: 22,
                            captionSize: 12
                        )
                        .frame(width: cellSize, height: cellSize)
                    }

                    HStack(spacing: 8) {
                        // ── Bottom Left: Strain ──
                        DashboardRing(
                            progress: Double(entry.strain ?? 0) / 100.0,
                            color: strainBlue,
                            label: entry.strainRaw.map { formatStrain($0) }
                                ?? entry.strain.map { "\($0)%" } ?? "--",
                            title: "STRAIN",
                            lineWidth: 9,
                            fontSize: 22,
                            captionSize: 12
                        )
                        .frame(width: cellSize, height: cellSize)

                        // ── Bottom Right: Rank (no circle) ──
                        RankBadge(rank: entry.rank, fontSize: 42, captionSize: 10)
                            .frame(width: cellSize, height: cellSize)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(12)
            }
        } else {
            NoDataView()
        }
    }
}

// MARK: - Medium: 4 rings in a row
// Layout: Sleep | Recovery | Strain | Rank

struct MediumWidgetView: View {
    let entry: StrainWidgetEntry

    var body: some View {
        if entry.hasData {
            GeometryReader { geo in
                let ringSize = min(geo.size.height - 16, (geo.size.width - 24) / 4)
                HStack(spacing: 4) {
                    DashboardRing(
                        progress: Double(entry.sleepScore ?? 0) / 100.0,
                        color: sleepBlue,
                        label: entry.sleepScore.map { "\($0)%" }
                            ?? entry.sleepHours.map { formatSleep($0) } ?? "--",
                        title: "SLEEP",
                        lineWidth: 7
                    )
                    .frame(width: ringSize, height: ringSize)

                    DashboardRing(
                        progress: Double(entry.recovery ?? 0) / 100.0,
                        color: recoveryColor(entry.recovery ?? 0),
                        label: "\(entry.recovery ?? 0)%",
                        title: "RECOVERY",
                        lineWidth: 7
                    )
                    .frame(width: ringSize, height: ringSize)

                    DashboardRing(
                        progress: Double(entry.strain ?? 0) / 100.0,
                        color: strainBlue,
                        label: entry.strainRaw.map { formatStrain($0) }
                            ?? entry.strain.map { "\($0)%" } ?? "--",
                        title: "STRAIN",
                        lineWidth: 7
                    )
                    .frame(width: ringSize, height: ringSize)

                    RankBadge(rank: entry.rank, fontSize: 22, captionSize: 7)
                        .frame(width: ringSize, height: ringSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 6)
            }
        } else {
            NoDataView()
        }
    }
}

// MARK: - Small: Recovery ring + rank text

struct SmallWidgetView: View {
    let entry: StrainWidgetEntry

    var body: some View {
        if entry.hasData {
            VStack(spacing: 8) {
                DashboardRing(
                    progress: Double(entry.recovery ?? 0) / 100.0,
                    color: recoveryColor(entry.recovery ?? 0),
                    label: "\(entry.recovery ?? 0)%",
                    title: "RECOVERY",
                    lineWidth: 11
                )
                if let rank = entry.rank {
                    Text("RANK \(rank)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(rankColor(rank))
                        .tracking(0.5)
                }
            }
            .padding(12)
        } else {
            NoDataView()
        }
    }
}

// MARK: - Dashboard Ring

struct DashboardRing: View {
    let progress: Double
    let color: Color
    let label: String
    let title: String
    var lineWidth: CGFloat = 10
    var fontSize: CGFloat = 14
    var captionSize: CGFloat = 7

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.15), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(label)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.35)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
            Text(title)
                .font(.system(size: captionSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(0.8)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.top, 6)
        }
    }
}

// MARK: - Rank Badge (no circle — matches app font exactly)

struct RankBadge: View {
    let rank: String?
    var fontSize: CGFloat = 32     // app uses size 32, weight .bold
    var captionSize: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let rank {
                Text(rank)
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(rankColor(rank))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                Text("--")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(.white.opacity(0.2))
            }
            Spacer(minLength: 0)
            Text("RANK")
                .font(.system(size: captionSize, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
                .tracking(0.8)
                .padding(.top, 6)
        }
    }
}

// MARK: - No Data

struct NoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "bolt.heart")
                .font(.title2)
                .foregroundColor(.white.opacity(0.25))
            Text("Open app to sync")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.25))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Colors & Helpers

private let sleepBlue    = Color(red: 0.45, green: 0.78, blue: 1.0)
private let strainBlue   = Color(red: 0.30, green: 0.55, blue: 1.0)
private let recoveryGreen = Color(red: 0.196, green: 0.843, blue: 0.294) // #32D74B

private func recoveryColor(_ v: Int) -> Color {
    if v >= 67 { return recoveryGreen }
    if v >= 34 { return .yellow }
    return .red
}

func rankColor(_ rank: String) -> Color {
    switch rank {
    case "E":        return .white
    case "D":        return .red
    case "C":        return .orange
    case "B":        return .yellow
    case "A":        return recoveryGreen
    case "S":        return .blue
    case "S+":       return .purple
    case "National": return .indigo
    default:         return .gray
    }
}

private func formatSleep(_ hours: Double) -> String {
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return m == 0 ? "\(h)h" : "\(h)h\(m)m"
}

private func formatStrain(_ raw: Double) -> String {
    String(format: "%.1f", raw)
}
