import SwiftUI

struct RecoveryDetailView: View {
    @StateObject private var viewModel = RecoveryViewModel()
    @State private var selectedDate = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date picker
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color(uiColor: .systemBackground))
                    .cornerRadius(12)
                
                // Recovery card
                RecoveryCardView(
                    recovery: viewModel.currentRecovery,
                    components: viewModel.recoveryComponents
                )
                
                // Recovery components breakdown
                if let components = viewModel.recoveryComponents {
                    recoveryBreakdownCard(components: components)
                }
                
                // HRV Trend
                HRVTrendView(weeklyData: viewModel.weeklyHRVChartData.map { ($0.date, $0.value) })
                
                // Sleep Summary
                if viewModel.dailyMetrics != nil {
                    SleepSummaryView(sleepData: nil) // You'll need to add sleep data to DailyMetrics or fetch separately
                }
            }
            .padding()
        }
        .navigationTitle("Recovery")
        .task {
            await viewModel.loadData()
        }
        .onChange(of: selectedDate) { _, newDate in
            Task {
                await viewModel.selectDate(newDate)
            }
        }
    }
    
    private func recoveryBreakdownCard(components: RecoveryComponents) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
                if let hrvScore = components.hrvScore {
                    RecoveryComponentRow(
                        title: "HRV",
                        value: hrvScore,
                        color: recoveryColor(hrvScore),
                        icon: "waveform.path.ecg"
                    )
                }
                
                if let rhrScore = components.restingHRScore {
                    RecoveryComponentRow(
                        title: "Resting Heart Rate",
                        value: rhrScore,
                        color: recoveryColor(rhrScore),
                        icon: "heart.fill"
                    )
                }
                
                if let sleepScore = components.sleepScore {
                    RecoveryComponentRow(
                        title: "Sleep",
                        value: sleepScore,
                        color: recoveryColor(sleepScore),
                        icon: "bed.double.fill"
                    )
                }
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
    }
    
    private func recoveryColor(_ score: Double) -> Color {
        switch score {
        case 0..<33: return .red
        case 33..<67: return .yellow
        default: return .green
        }
    }
}

struct RecoveryComponentRow: View {
    let title: String
    let value: Double
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text("\(Int(value))%")
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        RecoveryDetailView()
    }
}
