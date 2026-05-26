import WatchConnectivity
import SwiftUI
import Combine

/// Receives data sent from the Watch app via WatchConnectivity.
/// Currently used for Watch battery level display on the dashboard.
@MainActor
class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    /// Battery level 0.0–1.0, or -1 if not yet received from Watch.
    @Published var watchBatteryLevel: Float = -1
    @Published var watchIsCharging: Bool = false

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else {
            print("⌚️ WCSession not supported on this device")
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
        print("⌚️ WCSession activating…")
    }

    // MARK: - Send metrics to Watch

    /// Call this whenever new metrics are saved so the Watch updates without needing a relaunch.
    func sendMetricsToWatch(recovery: Double, strainRaw: Double, sleepScore: Double, rank: String) {
        guard WCSession.default.activationState == .activated else {
            print("⌚️ WCSession not activated — cannot send metrics to Watch")
            return
        }

        let payload: [String: Any] = [
            "metric_recovery":   recovery,
            "metric_strainRaw":  strainRaw,
            "metric_sleepScore": Int(sleepScore.rounded()),
            "metric_rank":       rank
        ]

        // updateApplicationContext delivers even when Watch isn't reachable
        do {
            try WCSession.default.updateApplicationContext(payload)
            print("⌚️ Sent metrics context to Watch — R:\(Int(recovery))% S:\(String(format:"%.1f",strainRaw)) rank:\(rank)")
        } catch {
            print("⌚️ updateApplicationContext failed: \(error)")
        }

        // Also fire a real-time message if Watch is reachable (foreground)
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: { err in
                print("⌚️ sendMessage failed: \(err)")
            })
        }
    }

    // MARK: - Helpers

    private func applyContext(_ dict: [String: Any]) {
        if let level = dict["watchBattery"] as? Float {
            watchBatteryLevel = level
            print("⌚️ Watch battery updated: \(Int(level * 100))%")
        }
        if let charging = dict["watchCharging"] as? Bool {
            watchIsCharging = charging
        }
    }

    // MARK: - Formatted display

    var watchBatteryText: String {
        guard watchBatteryLevel >= 0 else { return "--" }
        return "\(Int(watchBatteryLevel * 100))%"
    }

    var watchBatteryColor: Color {
        guard watchBatteryLevel >= 0 else { return .secondary }
        if watchIsCharging { return .green }
        if watchBatteryLevel > 0.5 { return .green }
        if watchBatteryLevel > 0.2 { return .yellow }
        return .red
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        print("⌚️ WCSession activated: \(state.rawValue), error: \(error?.localizedDescription ?? "none")")
        // Pull latest context immediately after activation
        Task { @MainActor in
            applyContext(session.receivedApplicationContext)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after Watch switch
        WCSession.default.activate()
    }

    // Real-time message — no reply expected (battery updates from Watch)
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in applyContext(message) }
    }

    // Real-time message WITH reply — Watch is requesting a metrics push
    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            applyContext(message) // handle battery keys if present

            guard message["requestMetrics"] != nil else {
                replyHandler([:])
                return
            }

            let recovery  = Double(DataSharingManager.shared.getRecovery() ?? 0)
            let strainRaw = DataSharingManager.shared.getStrainRaw()   ?? 0
            let sleepScore = DataSharingManager.shared.getSleepScore() ?? 0
            let rank       = DataSharingManager.shared.getRank()       ?? "E"

            let response: [String: Any] = [
                "metric_recovery":   recovery,
                "metric_strainRaw":  strainRaw,
                "metric_sleepScore": sleepScore,
                "metric_rank":       rank
            ]
            print("⌚️ Replying to Watch metrics request — R:\(Int(recovery))% S:\(String(format:"%.1f",strainRaw)) rank:\(rank)")
            replyHandler(response)
        }
    }

    // Background context (Watch app sent while iPhone wasn't reachable)
    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in applyContext(applicationContext) }
    }
}
