import SwiftUI
import WatchKit

@main
struct StrainFitnessTrackerWatch: App {
    init() {
        print("🟢 [Watch] App launched successfully on watchOS \(WKInterfaceDevice.current().systemVersion)")
        WatchConnectivityManager.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
        }
    }
}
