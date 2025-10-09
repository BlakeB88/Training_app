import SwiftUI

struct StressMonitorView: View {
    @ObservedObject private var viewModel = StressMonitorViewModel(healthKitManager: HealthKitManager.shared)
    
    var body: some View {
        VStack(spacing: 20) {
            // Stress Gauge
            StressGaugeView(stressLevel: viewModel.currentStressLevel)
                .frame(height: 200)
            
            // Current Stress Info
            VStack(spacing: 10) {
                Text("Current Stress: \(viewModel.formatStressLevel(viewModel.currentStressLevel))")
                    .font(.title2)
                    .foregroundColor(Color(viewModel.getStressZoneColor(viewModel.currentStressZone)))
                Text(viewModel.getCurrentStressExplanation())
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Stress Chart
            StressChartView(stressData: viewModel.getChartData())
                .frame(height: 200)
            
            // Daily Summary
            VStack(spacing: 10) {
                Text("Today’s Summary")
                    .font(.headline)
                HStack(spacing: 20) {
                    VStack {
                        Text("Avg Stress")
                        Text(viewModel.formatStressLevel(viewModel.todayAverageStress))
                            .foregroundColor(.blue)
                    }
                    VStack {
                        Text("Max Stress")
                        Text(viewModel.formatStressLevel(viewModel.todayMaxStress))
                            .foregroundColor(.red)
                    }
                    VStack {
                        Text("High Stress Time")
                        Text(viewModel.formatDuration(viewModel.timeInHighStress))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            // Refresh Button
            Button(action: {
                Task {
                    await viewModel.refreshCurrentStress()
                }
            }) {
                Text("Refresh")
                    .fontWeight(.bold)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // Error Message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
        .task {
            await viewModel.initialize()
        }
    }
}

#Preview {
    StressMonitorView()
}
