import SwiftUI
import HealthKit

struct PermissionsView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var authorizationStatus: [HKObjectType: HKAuthorizationStatus] = [:]
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.accentBlue)
                        
                        Text("Health Permissions")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primaryText)
                        
                        Text("StrainFitnessTracker needs access to your health data to calculate strain and recovery metrics.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // Permission Cards
                    VStack(spacing: 12) {
                        PermissionCard(
                            title: "Workouts",
                            icon: "figure.run",
                            color: .orange,
                            description: "Track your activities and calculate strain",
                            status: getStatus(for: HKObjectType.workoutType())
                        )
                        
                        PermissionCard(
                            title: "Heart Rate",
                            icon: "heart.fill",
                            color: .red,
                            description: "Monitor real-time stress levels",
                            status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!)
                        )
                        
                        PermissionCard(
                            title: "Heart Rate Variability",
                            icon: "waveform.path.ecg",
                            color: .purple,
                            description: "Calculate recovery scores",
                            status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!)
                        )
                        
                        PermissionCard(
                            title: "Resting Heart Rate",
                            icon: "heart.text.square",
                            color: .pink,
                            description: "Track baseline health metrics",
                            status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!)
                        )
                        
                        PermissionCard(
                            title: "Sleep Analysis",
                            icon: "bed.double.fill",
                            color: .sleepBlue,
                            description: "Analyze sleep quality and duration",
                            status: getStatus(for: HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!)
                        )
                        
                        PermissionCard(
                            title: "Active Energy",
                            icon: "flame.fill",
                            color: .warningOrange,
                            description: "Track calories burned during activities",
                            status: getStatus(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!)
                        )
                    }
                    .padding(.horizontal)
                    
                    // Request Button
                    Button {
                        requestAuthorization()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Grant Access")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.accentBlue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // Footer
                    Text("You can change these permissions anytime in the Health app under Sources.")
                        .font(.system(size: 13))
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Success!", isPresented: $showSuccess) {
            Button("Continue") {
                dismiss()
            }
        } message: {
            Text("Health permissions granted. You can now start tracking your fitness metrics!")
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
                    showSuccess = true
                } else if let error = error {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct PermissionCard: View {
    let title: String
    let icon: String
    let color: Color
    let description: String
    let status: PermissionStatus
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Status Badge
            statusBadge
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var statusBadge: some View {
        switch status {
        case .authorized:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.recoveryGreen)
                .font(.system(size: 22))
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 22))
        case .notDetermined:
            Image(systemName: "circle")
                .foregroundColor(.tertiaryText)
                .font(.system(size: 22))
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
