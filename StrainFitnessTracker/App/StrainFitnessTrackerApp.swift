//
//  StrainFitnessTrackerApp.swift
//  StrainFitnessTracker
//
//  App entry point with HealthKit initialization
//

import SwiftUI

@main
struct StrainFitnessTrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var hasRequestedPermissions = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        print("🚀 App launching...")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request permissions on first launch
                    if !hasRequestedPermissions {
                        await requestHealthKitPermissions()
                        hasRequestedPermissions = true
                    }

                    // Kick off ML training if we haven't trained today
                    await MLTrainingScheduler.shared.handleAppForeground()
                }
                .environmentObject(healthKitManager)
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        Task { @MainActor in
                            await MLTrainingScheduler.shared.handleAppForeground()
                        }
                    case .background:
                        MLTrainingScheduler.shared.handleAppBackground()
                    default:
                        break
                    }
                }
        }
    }
    
    private func requestHealthKitPermissions() async {
        do {
            try await HealthKitManager.shared.requestAuthorization()
            print("✅ HealthKit authorized successfully")
            print("   Authorization status: \(HealthKitManager.shared.isAuthorized)")
            
            // Do initial sync
            print("🔄 Starting initial data sync...")
            await DataSyncService.shared.quickSync()
            print("✅ Initial sync complete")
        } catch {
            print("❌ HealthKit authorization failed: \(error)")
        }
    }
}

// MARK: - Content View with Tab Navigation
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}
