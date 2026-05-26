//
//  StrainFitnessTrackerApp.swift
//  StrainFitnessTracker
//
//  App entry point with HealthKit initialization
//

#if !os(watchOS)
import SwiftUI

@main
struct StrainFitnessTrackerApp: App {
    #if canImport(CreateML)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    @StateObject private var healthKitManager = HealthKitManager.shared
    @State private var hasRequestedPermissions = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        print("🚀 App launching...")
        PhoneConnectivityManager.shared.activate()
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

                    #if canImport(CreateML)
                    // Kick off ML training if we haven't trained today
                    await MLTrainingScheduler.shared.handleAppForeground()
                    #endif
                }
                .environmentObject(healthKitManager)
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        #if canImport(CreateML)
                        Task { @MainActor in
                            await MLTrainingScheduler.shared.handleAppForeground()
                        }
                        #endif
                    case .background:
                        #if canImport(CreateML)
                        MLTrainingScheduler.shared.handleAppBackground()
                        #endif
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
#endif // !os(watchOS)
