import SwiftUI

struct WatchDashboardView: View {
    @State private var metrics: MetricsSnapshot?
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let metrics = metrics {
                    // Header
                    VStack(spacing: 4) {
                        HStack {
                            Image(systemName: "bolt.heart.fill")
                            Text("Fit Tracker")
                        }
                        .font(.headline)
                        
                        Text("Updated \(timeAgo(metrics.lastUpdate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Metrics
                    VStack(spacing: 20) {
                        // Recovery
                        WatchMetricCard(
                            title: "Recovery",
                            value: metrics.recoveryPercentage,
                            icon: "arrow.clockwise.circle.fill",
                            color: .green
                        )
                        
                        // Strain
                        WatchMetricCard(
                            title: "Strain",
                            value: metrics.strainPercentage,
                            icon: "bolt.fill",
                            color: .purple
                        )
                        
                        // Exertion (if available)
                        if let exertion = metrics.exertionPercentage {
                            WatchMetricCard(
                                title: "Exertion",
                                value: exertion,
                                icon: "flame.fill",
                                color: .orange
                            )
                        }
                    }
                    
                    // Visual ring summary
                    ZStack {
                        // Recovery ring (outer)
                        Circle()
                            .trim(from: 0, to: CGFloat(metrics.recoveryPercentage) / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan, .green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        
                        // Strain ring (inner)
                        Circle()
                            .trim(from: 0, to: CGFloat(metrics.strainPercentage) / 100)
                            .stroke(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(16)
                        
                        // Center label
                        VStack(spacing: 2) {
                            Text("\(metrics.strainPercentage)")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("Strain")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 120)
                    .padding()
                    
                } else if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                        Text("Loading metrics...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        
                        Text("No Data Available")
                            .font(.headline)
                        
                        Text("Open the iPhone app to sync your metrics")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            loadMetrics()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 8)
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Metrics")
        .onAppear {
            loadMetrics()
        }
    }
    
    private func loadMetrics() {
        isLoading = true
        
        // Simulate slight delay for loading animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            metrics = DataSharingManager.shared.getLatestMetrics()
            isLoading = false
        }
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

struct WatchMetricCard: View {
    let title: String
    let value: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(value)%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            // Mini progress indicator
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 32, height: 32)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    WatchDashboardView()
}
