//
//  StrainFitnessTrackerApp.swift
//  StrainFitnessTracker
//
//  App entry point with HealthKit initialization
//

import SwiftUI

@main
struct StrainFitnessTrackerApp: App {
    @StateObject private var healthKitManager = HealthKitManager.shared
    @StateObject private var notificationService = NotificationService.shared
    @State private var hasRequestedPermissions = false
    
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
                        await requestNotificationPermissions()
                        hasRequestedPermissions = true
                    }
                }
                .environmentObject(healthKitManager)
                .environmentObject(notificationService)
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

    private func requestNotificationPermissions() async {
        do {
            try await notificationService.requestAuthorization()
            print("🔔 Notifications authorized: \(notificationService.isAuthorized)")
        } catch {
            print("⚠️ Notification authorization failed: \(error)")
        }
    }
}

// MARK: - Content View with Tab Navigation
struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}
