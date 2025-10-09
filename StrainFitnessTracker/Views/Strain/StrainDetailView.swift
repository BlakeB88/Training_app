//
//  StrainDetailView.swift
//  StrainFitnessTracker
//
//  Updated: 10/8/25 - Added collapsible date selector and dark mode support
//

import SwiftUI
import UIKit

struct StrainDetailView: View {
    @StateObject private var viewModel = StrainViewModel()
    @State private var selectedDate = Date()
    @State private var isDateSelectorExpanded = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Collapsible Date picker
                collapsibleDatePicker
                
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
    
    private var strainBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Strain Breakdown")
                .font(.headline)
            
            VStack(spacing: 12) {
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
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 5, x: 0, y: 2)
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
