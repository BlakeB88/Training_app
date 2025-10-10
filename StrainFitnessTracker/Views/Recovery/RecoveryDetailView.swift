//
//  RecoveryDetailView.swift
//  StrainFitnessTracker
//
//  Updated: 10/8/25 - Added collapsible date selector and dark mode support
//

import SwiftUI

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
                // Collapsible Date picker
                collapsibleDatePicker
                
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
                    SleepSummaryView(sleepData: nil)
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
    
    // MARK: - Collapsible Date Picker
    private var collapsibleDatePicker: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDateSelectorExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(selectedDate.formatted(.dateTime.month().day().year()))
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Text("Change Date")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(isDateSelectorExpanded ? 180 : 0))
                    }
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Expandable date picker
            if isDateSelectorExpanded {
                DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
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
