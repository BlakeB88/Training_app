import Foundation

/// Shared data manager for communicating between iPhone app, Watch app, and complications
/// Must be included in ALL targets: iOS app, Watch app, and Widget extension
class DataSharingManager {
    static let shared = DataSharingManager()
    
    // MARK: - App Group Configuration
    private let appGroupIdentifier = "group.com.blake.StrainFitnessTracker"
    
    // Lazy initialization to avoid repeated warnings
    private lazy var userDefaults: UserDefaults? = {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Failed to access App Group: \(appGroupIdentifier)")
            print("   Make sure App Groups capability is enabled for this target")
            return nil
        }
        return defaults
    }()
    
    // MARK: - Storage Keys
    private enum Keys {
        static let recovery = "shared_recovery"
        static let strain = "shared_strain"
        static let exertion = "shared_exertion"
        static let lastUpdate = "shared_last_update"
        static let sleep = "shared_sleep"           // Double — hours (e.g. 7.5)
        static let sleepScore = "shared_sleep_score" // Int — 0-100 score (matches dashboard ring)
        static let strainRaw = "shared_strain_raw"   // Double — raw 0-21 value (e.g. 15.1)
        static let rank = "shared_rank"              // String — display name (e.g. "A", "S+")
    }
    
    private init() {
        // Verify App Groups on init
        #if DEBUG
        verifyAppGroups()
        #endif
    }
    
    // MARK: - Save Methods
    
    func saveMetrics(recovery: Double, strain: Double, exertion: Double? = nil) {
        guard let defaults = userDefaults else {
            print("❌ Cannot save metrics - App Group not accessible")
            return
        }
        
        // Convert to Int percentages for simplicity
        defaults.set(Int(recovery.rounded()), forKey: Keys.recovery)
        defaults.set(Int(strain.rounded()), forKey: Keys.strain)
        
        if let exertion = exertion {
            defaults.set(Int(exertion.rounded()), forKey: Keys.exertion)
        }
        
        defaults.set(Date(), forKey: Keys.lastUpdate)
        
        // Force synchronize to ensure data is written
        defaults.synchronize()
        
        print("✅ Saved metrics - Recovery: \(Int(recovery))%, Strain: \(Int(strain))%")
    }
    
    func saveRecovery(_ recovery: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(Int(recovery.rounded()), forKey: Keys.recovery)
        defaults.set(Date(), forKey: Keys.lastUpdate)
        defaults.synchronize()
    }
    
    func saveStrain(_ strain: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(Int(strain.rounded()), forKey: Keys.strain)
        defaults.set(Date(), forKey: Keys.lastUpdate)
        defaults.synchronize()
    }
    
    func saveExertion(_ exertion: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(Int(exertion.rounded()), forKey: Keys.exertion)
        defaults.set(Date(), forKey: Keys.lastUpdate)
        defaults.synchronize()
    }

    func saveSleep(_ hours: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(hours, forKey: Keys.sleep)
        defaults.synchronize()
    }

    func saveSleepScore(_ score: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(Int(score.rounded()), forKey: Keys.sleepScore)
        defaults.synchronize()
    }

    func saveStrainRaw(_ strain: Double) {
        guard let defaults = userDefaults else { return }
        defaults.set(strain, forKey: Keys.strainRaw)
        defaults.synchronize()
    }

    func saveRank(_ rankDisplayName: String) {
        guard let defaults = userDefaults else { return }
        defaults.set(rankDisplayName, forKey: Keys.rank)
        defaults.synchronize()
    }
    
    // MARK: - Retrieve Methods
    
    func getLatestMetrics() -> MetricsSnapshot? {
        guard let defaults = userDefaults else {
            print("❌ Cannot read metrics - App Group not accessible")
            return nil
        }
        
        // Check if we have any data
        guard defaults.object(forKey: Keys.lastUpdate) != nil else {
            print("⚠️ No metrics data available in App Group")
            return nil
        }
        
        let recovery = defaults.integer(forKey: Keys.recovery)
        let strain = defaults.integer(forKey: Keys.strain)
        let exertion = defaults.integer(forKey: Keys.exertion)
        let lastUpdate = defaults.object(forKey: Keys.lastUpdate) as? Date ?? Date()
        
        let exertionValue = exertion > 0 ? exertion : nil
        
        print("📊 Retrieved metrics: R=\(recovery)%, S=\(strain)%, E=\(exertionValue ?? 0)%")
        
        return MetricsSnapshot(
            recoveryPercentage: recovery,
            strainPercentage: strain,
            exertionPercentage: exertionValue,
            lastUpdate: lastUpdate
        )
    }
    
    func getRecovery() -> Int? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.integer(forKey: Keys.recovery)
        return value > 0 ? value : nil
    }
    
    func getStrain() -> Int? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.integer(forKey: Keys.strain)
        return value > 0 ? value : nil
    }
    
    func getExertion() -> Int? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.integer(forKey: Keys.exertion)
        return value > 0 ? value : nil
    }

    func getSleep() -> Double? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.double(forKey: Keys.sleep)
        return value > 0 ? value : nil
    }

    func getSleepScore() -> Int? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.integer(forKey: Keys.sleepScore)
        return value > 0 ? value : nil
    }

    func getStrainRaw() -> Double? {
        guard let defaults = userDefaults else { return nil }
        let value = defaults.double(forKey: Keys.strainRaw)
        return value > 0 ? value : nil
    }

    func getRank() -> String? {
        guard let defaults = userDefaults else { return nil }
        return defaults.string(forKey: Keys.rank)
    }
    
    func isDataStale() -> Bool {
        guard let defaults = userDefaults,
              let lastUpdate = defaults.object(forKey: Keys.lastUpdate) as? Date else {
            return true
        }
        
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)
        return lastUpdate < twoHoursAgo
    }
    
    // MARK: - Debug Methods
    
    func verifyAppGroups() {
        print("\n🔍 === APP GROUPS VERIFICATION ===")
        print("App Group ID: \(appGroupIdentifier)")
        
        if let defaults = userDefaults {
            print("✅ UserDefaults accessible")
            
            // Try to write and read a test value
            let testKey = "test_access"
            let testValue = "test_\(Date().timeIntervalSince1970)"
            defaults.set(testValue, forKey: testKey)
            defaults.synchronize()
            
            if let readValue = defaults.string(forKey: testKey), readValue == testValue {
                print("✅ Read/Write working correctly")
                defaults.removeObject(forKey: testKey)
            } else {
                print("⚠️ Read/Write test failed")
            }
            
            // Check for existing data
            if let lastUpdate = defaults.object(forKey: Keys.lastUpdate) as? Date {
                let recovery = defaults.integer(forKey: Keys.recovery)
                let strain = defaults.integer(forKey: Keys.strain)
                print("📊 Existing data found:")
                print("   Recovery: \(recovery)%")
                print("   Strain: \(strain)%")
                print("   Last Update: \(lastUpdate)")
            } else {
                print("ℹ️ No existing data in App Group")
            }
        } else {
            print("❌ UserDefaults NOT accessible")
            print("   Verify App Groups capability is enabled")
            print("   Check that bundle ID matches provisioning profile")
        }
        print("==================================\n")
    }
    
    func debugPrint() {
        verifyAppGroups()
    }
}

// MARK: - Metrics Snapshot Model

struct MetricsSnapshot: Codable {
    let recoveryPercentage: Int
    let strainPercentage: Int
    let exertionPercentage: Int?
    let lastUpdate: Date
    
    var isStale: Bool {
        Date().timeIntervalSince(lastUpdate) > 3600 // Older than 1 hour
    }
    
    var formattedLastUpdate: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: lastUpdate)
    }
}
