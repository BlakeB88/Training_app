import SwiftUI

struct SettingsView: View {
    @AppStorage("userAge") private var userAge: Int = 20
    @AppStorage("userWeight") private var userWeight: Double = 80.0
    @AppStorage("userGender") private var userGender: String = "Male"
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("dailyReminderTime") private var dailyReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    
    var body: some View {
        Form {
            // Profile Section
            Section {
                NavigationLink {
                    ProfileSetupView()
                } label: {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile")
                                .font(.headline)
                            Text("\(userAge) years • \(Int(userWeight)) kg • \(userGender)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("User Profile")
            }
            
            // Permissions Section
            Section {
                NavigationLink {
                    PermissionsView()
                } label: {
                    HStack {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.green)
                        Text("Health Permissions")
                    }
                }
            } header: {
                Text("Privacy")
            }
            
            // Notifications Section
            Section {
                Toggle(isOn: $notificationsEnabled) {
                    HStack {
                        Image(systemName: "bell.fill")
                            .foregroundColor(.orange)
                        Text("Enable Notifications")
                    }
                }
                
                if notificationsEnabled {
                    DatePicker("Daily Reminder", selection: $dailyReminderTime, displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Receive daily reminders to check your recovery and strain.")
            }
            
            // Data Section
            Section {
                Button {
                    // Sync data action
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("Sync HealthKit Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Button {
                    // Export data action
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                        Text("Export Data")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Data Management")
            }
            
            // About Section
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
                
                Link(destination: URL(string: "https://example.com/privacy")!) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://example.com/terms")!) {
                    HStack {
                        Text("Terms of Service")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
