//
//  ContentView.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var hasRequestedPermissions = false
    
    var body: some View {
        if hasRequestedPermissions {
            mainTabView
        } else {
            permissionsPrompt
        }
    }
    
    private var permissionsPrompt: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Health Data Access")
                .font(.title.bold())
            
            Text("StrainFitnessTracker needs access to your health data to track your strain and recovery metrics.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 12) {
                PermissionInfoRow(icon: "figure.run", text: "Workout data")
                PermissionInfoRow(icon: "heart.fill", text: "Heart rate")
                PermissionInfoRow(icon: "waveform.path.ecg", text: "Heart rate variability")
                PermissionInfoRow(icon: "bed.double.fill", text: "Sleep analysis")
            }
            .padding()
            
            Button {
                requestPermissions()
            } label: {
                Text("Grant Access")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private var mainTabView: some View {
        TabView {
            // Strain Tab
            NavigationStack {
                StrainDetailView()
            }
            .tabItem {
                Label("Strain", systemImage: "flame.fill")
            }
            
            // Recovery Tab
            NavigationStack {
                RecoveryDetailView()
            }
            .tabItem {
                Label("Recovery", systemImage: "heart.fill")
            }
            
            // Profile/Settings Tab
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
    
    private func requestPermissions() {
        Task {
            do {
                try await HealthKitManager.shared.requestAuthorization()
                await MainActor.run {
                    hasRequestedPermissions = true
                }
            } catch {
                print("Error requesting authorization: \(error)")
                // Still show the main view even if there's an error
                await MainActor.run {
                    hasRequestedPermissions = true
                }
            }
        }
    }
}

struct PermissionInfoRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            Text(text)
        }
    }
}

// Simple Settings View
struct AppSettingsView: View {
    var body: some View {
        List {
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Health Data") {
                Button("Refresh Data") {
                    // Add refresh logic
                }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    ContentView()
}
