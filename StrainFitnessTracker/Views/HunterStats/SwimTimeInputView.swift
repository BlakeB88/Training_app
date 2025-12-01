import SwiftUI

struct SwimTimeInputView: View {
    @StateObject private var viewModel = SwimTimeInputViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Input Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Add Swim Time")
                                .font(.title2.bold())
                                .foregroundColor(.primaryText)
                            
                            // Unit Toggle
                            Picker("Unit", selection: $viewModel.selectedUnit) {
                                Text("LCM").tag(DistanceUnit.meters)
                                Text("SCM").tag(DistanceUnit.shortCourseMeters)
                                Text("SCY").tag(DistanceUnit.yards)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)
                            
                            // Event Selector
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Event")
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                Menu {
                                    ForEach(viewModel.filteredEvents) { event in
                                        Button(event.displayName) {
                                            viewModel.selectedEvent = event
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(viewModel.selectedEvent?.displayName ?? "Select Event")
                                            .foregroundColor(viewModel.selectedEvent == nil ? .secondaryText : .primaryText)
                                        Spacer()
                                        Image(systemName: "chevron.down")
                                            .foregroundColor(.secondaryText)
                                    }
                                    .padding()
                                    .background(Color.secondaryCardBackground)
                                    .cornerRadius(12)
                                }
                            }
                            
                            // Time Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Time")
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                HStack(spacing: 12) {
                                    TimeComponentPicker(
                                        value: $viewModel.minutes,
                                        label: "min",
                                        range: 0...59
                                    )
                                    
                                    Text(":")
                                        .font(.title)
                                        .foregroundColor(.secondaryText)
                                    
                                    TimeComponentPicker(
                                        value: $viewModel.seconds,
                                        label: "sec",
                                        range: 0...59
                                    )
                                    
                                    Text(".")
                                        .font(.title)
                                        .foregroundColor(.secondaryText)
                                    
                                    TimeComponentPicker(
                                        value: $viewModel.milliseconds,
                                        label: "ms",
                                        range: 0...99
                                    )
                                }
                            }
                            
                            // Date Picker
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date")
                                    .font(.headline)
                                    .foregroundColor(.primaryText)
                                
                                DatePicker("", selection: $viewModel.recordDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding()
                                    .background(Color.secondaryCardBackground)
                                    .cornerRadius(12)
                            }
                            
                            // World Record Reference
                            if let event = viewModel.selectedEvent {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("World Record")
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                        Text(event.worldRecordSeconds.formattedTime())
                                            .font(.headline)
                                            .foregroundColor(.primaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text("Your Time")
                                            .font(.caption)
                                            .foregroundColor(.secondaryText)
                                        Text(viewModel.totalSeconds > 0 ? viewModel.formatTime(viewModel.totalSeconds) : "--:--")
                                            .font(.headline)
                                            .foregroundColor(.accentBlue)
                                    }
                                }
                                .padding()
                                .background(Color.secondaryCardBackground)
                                .cornerRadius(12)
                            }
                            
                            // Submit Button
                            Button(action: {
                                viewModel.submitTime()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Time")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.canSubmit ? Color.accentBlue : Color.gray)
                                .cornerRadius(12)
                            }
                            .disabled(!viewModel.canSubmit)
                        }
                        .padding()
                        .background(Color.cardBackground)
                        .cornerRadius(20)
                        
                        // Recent Records Section
                        if !viewModel.records.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Recent Times")
                                    .font(.title2.bold())
                                    .foregroundColor(.primaryText)
                                
                                ForEach(viewModel.records) { record in
                                    SwimRecordRow(record: record, viewModel: viewModel)
                                }
                            }
                            .padding()
                            .background(Color.cardBackground)
                            .cornerRadius(20)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Swim Times")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Time Saved!", isPresented: $viewModel.showSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your swim time has been recorded")
            }
        }
    }
}

// MARK: - Time Component Picker
private struct TimeComponentPicker: View {
    @Binding var value: Int
    let label: String
    let range: ClosedRange<Int>
    
    var body: some View {
        VStack(spacing: 4) {
            Picker("", selection: $value) {
                ForEach(range, id: \.self) { num in
                    Text(String(format: "%02d", num))
                        .tag(num)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80, height: 100)
            .clipped()
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
    }
}

// MARK: - Record Row
private struct SwimRecordRow: View {
    let record: SwimTimeRecord
    @ObservedObject var viewModel: SwimTimeInputViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.getEventName(for: record))
                    .font(.headline)
                    .foregroundColor(.primaryText)
                Text(record.recordDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
            
            Text(viewModel.formatTime(record.timeInSeconds))
                .font(.headline)
                .foregroundColor(.accentBlue)
            
            Button(action: {
                viewModel.deleteRecord(record)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.dangerRed)
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(Color.secondaryCardBackground)
        .cornerRadius(12)
    }
}

#Preview {
    SwimTimeInputView()
}
