import SwiftUI

struct ProfileSetupView: View {
    @AppStorage("userAge") private var userAge: Int = 30
    @AppStorage("userWeight") private var userWeight: Double = 70.0
    @AppStorage("userHeight") private var userHeight: Double = 170.0
    @AppStorage("userGender") private var userGender: String = "Male"
    @AppStorage("maxHeartRate") private var maxHeartRate: Int = 190
    @AppStorage("restingHeartRate") private var restingHeartRate: Int = 60
    
    @Environment(\.dismiss) private var dismiss
    
    private let genders = ["Male", "Female", "Other"]
    
    var body: some View {
        Form {
            // Basic Info
            Section {
                Stepper("Age: \(userAge)", value: $userAge, in: 13...100)
                
                Picker("Gender", selection: $userGender) {
                    ForEach(genders, id: \.self) { gender in
                        Text(gender).tag(gender)
                    }
                }
            } header: {
                Text("Basic Information")
            }
            
            // Physical Metrics
            Section {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: $userWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("kg")
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("Height", value: $userHeight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    Text("cm")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Physical Metrics")
            }
            
            // Heart Rate Zones
            Section {
                Stepper("Max HR: \(maxHeartRate) bpm", value: $maxHeartRate, in: 150...220)
                
                Stepper("Resting HR: \(restingHeartRate) bpm", value: $restingHeartRate, in: 40...100)
                
                Button("Calculate from Age") {
                    maxHeartRate = 220 - userAge
                }
                .foregroundColor(.blue)
            } header: {
                Text("Heart Rate Zones")
            } footer: {
                Text("Max HR is used to calculate strain. Default formula: 220 - age.")
            }
            
            // Calculated Zones
            Section {
                HRZoneRow(zone: "Zone 1 (Recovery)", range: "\(restingHeartRate)-\(zone1Upper) bpm", color: .gray)
                HRZoneRow(zone: "Zone 2 (Aerobic)", range: "\(zone1Upper)-\(zone2Upper) bpm", color: .blue)
                HRZoneRow(zone: "Zone 3 (Tempo)", range: "\(zone2Upper)-\(zone3Upper) bpm", color: .green)
                HRZoneRow(zone: "Zone 4 (Threshold)", range: "\(zone3Upper)-\(zone4Upper) bpm", color: .orange)
                HRZoneRow(zone: "Zone 5 (Max)", range: "\(zone4Upper)-\(maxHeartRate) bpm", color: .red)
            } header: {
                Text("Your Heart Rate Zones")
            }
        }
        .navigationTitle("Profile Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    // Heart rate zone calculations
    private var zone1Upper: Int {
        restingHeartRate + Int(Double(maxHeartRate - restingHeartRate) * 0.6)
    }
    
    private var zone2Upper: Int {
        restingHeartRate + Int(Double(maxHeartRate - restingHeartRate) * 0.7)
    }
    
    private var zone3Upper: Int {
        restingHeartRate + Int(Double(maxHeartRate - restingHeartRate) * 0.8)
    }
    
    private var zone4Upper: Int {
        restingHeartRate + Int(Double(maxHeartRate - restingHeartRate) * 0.9)
    }
}

struct HRZoneRow: View {
    let zone: String
    let range: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            
            Text(zone)
                .font(.subheadline)
            
            Spacer()
            
            Text(range)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSetupView()
    }
}
