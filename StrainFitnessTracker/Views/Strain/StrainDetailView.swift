import SwiftUI
import UIKit

struct StrainDetailView: View {
    @StateObject private var viewModel = StrainViewModel()
    @State private var selectedDate = Date()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date picker
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                
                // Strain ring
                StrainRingView(strain: viewModel.currentStrain)
                    .frame(height: 250)
                
                // Strain breakdown
                strainBreakdownCard
                
                // Weekly chart
                StrainChartView(weeklyData: viewModel.weeklyChartData.map { ($0.date, $0.value) })
                
                // Today's workouts
                if !viewModel.workouts.isEmpty {
                    WorkoutListView(workouts: viewModel.workouts)
                }
            }
            .padding()
        }
        .navigationTitle("Strain")
        .task {
            await viewModel.loadData()
        }
        .onChange(of: selectedDate) { _, newValue in
            Task { await viewModel.selectDate(newValue) }
        }
    }
    
    private var strainBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strain Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Note: These properties don't exist in StrainViewModel
                // You'll need to add them or calculate from workouts
                StrainComponentRow(
                    title: "Total Strain",
                    value: viewModel.currentStrain,
                    color: strainColor(viewModel.currentStrain),
                    icon: "flame.fill"
                )
                
                StrainComponentRow(
                    title: "Workouts",
                    value: Double(viewModel.workouts.count),
                    color: .blue,
                    icon: "figure.run"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func strainColor(_ strain: Double) -> Color {
        switch strain {
        case 0..<10: return .green
        case 10..<14: return .yellow
        case 14..<18: return .orange
        default: return .red
        }
    }
}

struct StrainComponentRow: View {
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
            
            Text(value.formatted(.number.precision(.fractionLength(1))))
                .font(.headline)
                .foregroundColor(color)
        }
    }
}

#Preview {
    NavigationStack {
        StrainDetailView()
    }
}
