import WatchKit
import WatchConnectivity
import Foundation
import WidgetKit

extension Notification.Name {
    /// Posted on the Watch whenever fresh metrics arrive from the iPhone.
    static let watchMetricsDidUpdate = Notification.Name("watchMetricsDidUpdate")
}

/// Runs on the Watch. Reads battery level and pushes it to the iPhone,
/// and receives metric updates pushed from the iPhone.
class WatchConnectivityManager: NSObject {
    static let shared = WatchConnectivityManager()

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()

        // Enable battery monitoring so we can read the level
        WKInterfaceDevice.current().isBatteryMonitoringEnabled = true
        print("⌚️ Watch WCSession activating, battery monitoring ON")
    }

    /// Ask the iPhone to immediately push its latest metrics.
    /// Uses sendMessage with a reply handler so we get a direct response
    /// rather than waiting for a queued updateApplicationContext.
    func requestMetrics() {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else {
            print("⌚️ [Watch] iPhone not reachable — skipping metrics request")
            return
        }
        print("⌚️ [Watch] Requesting metrics from iPhone…")
        WCSession.default.sendMessage(
            ["requestMetrics": true],
            replyHandler: { [weak self] response in
                print("⌚️ [Watch] Got metrics reply from iPhone")
                self?.applyMetrics(response)
            },
            errorHandler: { error in
                print("⌚️ [Watch] Metrics request failed: \(error.localizedDescription)")
            }
        )
    }

    func sendBatteryLevel() {
        guard WCSession.default.activationState == .activated else { return }

        let level    = WKInterfaceDevice.current().batteryLevel  // 0.0–1.0
        let charging = WKInterfaceDevice.current().batteryState == .charging

        let payload: [String: Any] = [
            "watchBattery":  level,
            "watchCharging": charging
        ]

        // updateApplicationContext works even when iPhone isn't reachable
        try? WCSession.default.updateApplicationContext(payload)

        // Also fire a real-time message if the phone is currently reachable
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }

        print("⌚️ Sent battery level: \(Int(level * 100))%")
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        print("⌚️ Watch WCSession activated: \(state.rawValue)")
        if state == .activated {
            sendBatteryLevel()
            // Apply any cached context that arrived while the Watch app was closed
            applyMetrics(session.receivedApplicationContext)
            // If iPhone is already reachable, ask for a fresh push immediately
            requestMetrics()
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            // Phone just came online — send battery and request fresh metrics
            sendBatteryLevel()
            requestMetrics()
        }
    }

    // MARK: - Receive metrics pushed from iPhone

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        applyMetrics(message)
    }

    func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        applyMetrics(applicationContext)
    }

    private func applyMetrics(_ dict: [String: Any]) {
        print("⌚️ [Watch] applyMetrics called with keys: \(dict.keys.sorted())")

        // Only process if the dictionary contains metric keys
        guard dict["metric_recovery"] != nil || dict["metric_strainRaw"] != nil else {
            print("⌚️ [Watch] No metric keys found — ignoring")
            return
        }

        let groupID = "group.com.blake.StrainFitnessTracker"
        guard let defaults = UserDefaults(suiteName: groupID) else {
            print("⌚️ [Watch] ❌ App Group UserDefaults not accessible!")
            return
        }

        if let recovery = dict["metric_recovery"] as? Double {
            let strainPct = ((dict["metric_strainRaw"] as? Double ?? 0) / 21.0) * 100.0
            defaults.set(Int(recovery.rounded()), forKey: "shared_recovery")
            defaults.set(Int(min(strainPct, 100).rounded()), forKey: "shared_strain")
            print("⌚️ [Watch] ✅ Wrote R:\(Int(recovery))% S_pct:\(Int(strainPct))%")
        }
        if let strainRaw = dict["metric_strainRaw"] as? Double {
            defaults.set(strainRaw, forKey: "shared_strain_raw")
        }
        if let sleepScore = dict["metric_sleepScore"] as? Int {
            defaults.set(sleepScore, forKey: "shared_sleep_score")
        }
        if let rank = dict["metric_rank"] as? String {
            defaults.set(rank, forKey: "shared_rank")
            print("⌚️ [Watch] ✅ Wrote rank: \(rank)")
        }
        defaults.set(Date(), forKey: "shared_last_update")
        let synced = defaults.synchronize()
        print("⌚️ [Watch] UserDefaults.synchronize() = \(synced)")

        // Reload the complication immediately so the watch face reflects new data
        WidgetCenter.shared.reloadTimelines(ofKind: "StrainRecoveryComplication")
        print("⌚️ [Watch] Requested complication timeline reload")

        // Notify the dashboard view to reload
        DispatchQueue.main.async {
            print("⌚️ [Watch] Posting watchMetricsDidUpdate notification")
            NotificationCenter.default.post(name: .watchMetricsDidUpdate, object: nil)
        }
    }
}
