import Foundation

/// Manages data sharing between iOS app, WatchOS app, and complications
class DataSharingManager {
    static let shared = DataSharingManager()
    
    private let groupID = "group.com.blake.StrainFitnessTracker"
    private let recoveryKey = "latestRecovery"
    private let strainKey = "latestStrain"
    private let exertionKey = "latestExertion"
    private let lastUpdateKey = "lastMetricsUpdate"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }
    
    private init() {}
    
    // MARK: - Save Methods
    
    /// Save latest metrics to shared storage
    func saveMetrics(recovery: Double, strain: Double, exertion: Double? = nil) {
        guard let defaults = sharedDefaults else {
            print("⚠️ Failed to access shared UserDefaults")
            return
        }
        
        defaults.set(recovery, forKey: recoveryKey)
        defaults.set(strain, forKey: strainKey)
        if let exertion = exertion {
            defaults.set(exertion, forKey: exertionKey)
        }
        defaults.set(Date(), forKey: lastUpdateKey)
        
        print("✅ Saved metrics - Recovery: \(recovery)%, Strain: \(strain)")
    }
    
    /// Save recovery metric only
    func saveRecovery(_ recovery: Double) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(recovery, forKey: recoveryKey)
        defaults.set(Date(), forKey: lastUpdateKey)
    }
    
    /// Save strain metric only
    func saveStrain(_ strain: Double) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(strain, forKey: strainKey)
        defaults.set(Date(), forKey: lastUpdateKey)
    }
    
    /// Save exertion metric only
    func saveExertion(_ exertion: Double) {
        guard let defaults = sharedDefaults else { return }
        defaults.set(exertion, forKey: exertionKey)
        defaults.set(Date(), forKey: lastUpdateKey)
    }
    
    // MARK: - Read Methods
    
    /// Get latest metrics from shared storage
    func getLatestMetrics() -> MetricsSnapshot? {
        guard let defaults = sharedDefaults else { return nil }
        
        let recovery = defaults.double(forKey: recoveryKey)
        let strain = defaults.double(forKey: strainKey)
        let exertion = defaults.double(forKey: exertionKey)
        
        guard let lastUpdate = defaults.object(forKey: lastUpdateKey) as? Date else {
            return nil
        }
        
        return MetricsSnapshot(
            recovery: recovery,
            strain: strain,
            exertion: exertion > 0 ? exertion : nil,
            lastUpdate: lastUpdate
        )
    }
    
    /// Get recovery value only
    func getRecovery() -> Double? {
        guard let defaults = sharedDefaults else { return nil }
        let value = defaults.double(forKey: recoveryKey)
        return value > 0 ? value : nil
    }
    
    /// Get strain value only
    func getStrain() -> Double? {
        guard let defaults = sharedDefaults else { return nil }
        let value = defaults.double(forKey: strainKey)
        return value > 0 ? value : nil
    }
    
    /// Get exertion value only
    func getExertion() -> Double? {
        guard let defaults = sharedDefaults else { return nil }
        let value = defaults.double(forKey: exertionKey)
        return value > 0 ? value : nil
    }
    
    /// Check if data is stale (older than 2 hours)
    func isDataStale() -> Bool {
        guard let defaults = sharedDefaults,
              let lastUpdate = defaults.object(forKey: lastUpdateKey) as? Date else {
            return true
        }
        
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        return lastUpdate < twoHoursAgo
    }
}

// MARK: - Models

/// Snapshot of metrics at a point in time
struct MetricsSnapshot {
    let recovery: Double
    let strain: Double
    let exertion: Double?
    let lastUpdate: Date
    
    var recoveryPercentage: Int {
        Int(recovery.rounded())
    }
    
    var strainPercentage: Int {
        Int(strain.rounded())
    }
    
    var exertionPercentage: Int? {
        guard let exertion = exertion else { return nil }
        return Int(exertion.rounded())
    }
}
