import SwiftUI
import HealthKit

struct PermissionsView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var authorizationStatus: [HKObjectType: HKAuthorizationStatus] = [:]
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        List {
            Section {
                Text("StrainFitnessTracker needs access to your health data to calculate strain and recovery metrics.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Section {
                PermissionRow(
                    title: "Workouts",
                    icon: "figure.run",
                    color: .orange,
                    status: getStatus(for: HKObjectType.workoutType())
                )
                
                PermissionRow(
                    title: "Heart Rate",
                    icon: "heart.fill",
                    color: .red,
                    status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
                )
                
                PermissionRow(
                    title: "Heart Rate Variability",
                    icon: "waveform.path.ecg",
                    color: .purple,
                    status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
                )
                
                PermissionRow(
                    title: "Resting Heart Rate",
                    icon: "heart.text.square",
                    color: .pink,
                    status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!)
                )
                
                PermissionRow(
                    title: "Sleep Analysis",
                    icon: "bed.double.fill",
                    color: .blue,
                    status: getStatus(for: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)
                )
                
                PermissionRow(
                    title: "Active Energy",
                    icon: "flame.fill",
                    color: .orange,
                    status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                )
            } header: {
                Text("Required Permissions")
            }
            
            Section {
                Button {
                    requestAuthorization()
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Request Access")
                                .fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(isLoading)
            } footer: {
                Text("You can change these permissions anytime in the Health app under Sources.")
                    .font(.caption)
            }
        }
        .navigationTitle("Health Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            checkAuthorizationStatus()
        }
    }
    
    private func getStatus(for type: HKObjectType) -> PermissionStatus {
        guard let status = authorizationStatus[type] else {
            return .notDetermined
        }
        
        switch status {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }
    
    private func checkAuthorizationStatus() {
        let types: [HKObjectType] = [
            HKObjectType.workoutType(),
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
            HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]
        
        for type in types {
            let status = healthKitManager.healthStore.authorizationStatus(for: type)
            authorizationStatus[type] = status
        }
    }
    
    private func requestAuthorization() {
        isLoading = true
        
        healthKitManager.requestAuthorization { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    checkAuthorizationStatus()
                } else if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct PermissionRow: View {
    let title: String
    let icon: String
    let color: Color
    let status: PermissionStatus
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
            
            Spacer()
            
            statusBadge
        }
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        case .notDetermined:
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
        }
    }
}

enum PermissionStatus {
    case authorized
    case denied
    case notDetermined
}

#Preview {
    NavigationStack {
        PermissionsView()
    }
}
