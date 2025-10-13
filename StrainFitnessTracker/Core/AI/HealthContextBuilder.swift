import Foundation

class HealthContextBuilder {
    private let repository: MetricsRepository
    private let healthKitManager: HealthKitManager
    
    init(repository: MetricsRepository = MetricsRepository(),
         healthKitManager: HealthKitManager = .shared) {
        self.repository = repository
        self.healthKitManager = healthKitManager
    }
    
    /// Build CONCISE health context for AI (token-optimized)
    func buildHealthContext() async throws -> String {
        let today = Date().startOfDay
        let todayMetrics = try repository.fetchDailyMetrics(for: today)
        
        // Get last 7 days for trends
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let recentMetrics = try repository.fetchDailyMetrics(from: sevenDaysAgo, to: today)
        
        // ✅ MUCH MORE CONCISE - only key metrics
        var context = "TODAY: "
        context += formatTodayMetricsCompact(todayMetrics)
        
        context += "\n7-DAY AVG: "
        context += formatTrendsCompact(recentMetrics)
        
        return context
    }
    
    private func formatTodayMetricsCompact(_ metrics: SimpleDailyMetrics?) -> String {
        guard let m = metrics else { return "No data" }
        
        var parts: [String] = []
        
        // Most important metrics only
        parts.append("Strain \(f(m.strain))/21")
        
        if let rec = m.recovery {
            parts.append("Recovery \(f(rec))/100")
        }
        
        if let sleep = m.sleepDuration {
            parts.append("Sleep \(fh(sleep))")
        }
        
        if let hrv = m.hrvAverage {
            parts.append("HRV \(f(hrv))ms")
        }
        
        if let rhr = m.restingHeartRate {
            parts.append("RHR \(f(rhr))bpm")
        }
        
        if !m.workouts.isEmpty {
            parts.append("\(m.workouts.count) workout(s)")
        }
        
        return parts.joined(separator: ", ")
    }
    
    private func formatTrendsCompact(_ metrics: [SimpleDailyMetrics]) -> String {
        guard !metrics.isEmpty else { return "No recent data" }
        
        var parts: [String] = []
        
        // Strain average
        let avgStrain = metrics.map { $0.strain }.reduce(0, +) / Double(metrics.count)
        parts.append("Strain \(f(avgStrain))")
        
        // Recovery average
        let recoveries = metrics.compactMap { $0.recovery }
        if !recoveries.isEmpty {
            let avgRec = recoveries.reduce(0, +) / Double(recoveries.count)
            parts.append("Recovery \(f(avgRec))")
        }
        
        // Sleep average
        let sleeps = metrics.compactMap { $0.sleepDuration }
        if !sleeps.isEmpty {
            let avgSleep = sleeps.reduce(0, +) / Double(sleeps.count)
            parts.append("Sleep \(fh(avgSleep))")
        }
        
        // HRV average
        let hrvs = metrics.compactMap { $0.hrvAverage }
        if !hrvs.isEmpty {
            let avgHRV = hrvs.reduce(0, +) / Double(hrvs.count)
            parts.append("HRV \(f(avgHRV))ms")
        }
        
        // Total workouts
        let totalWorkouts = metrics.flatMap { $0.workouts }.count
        parts.append("\(totalWorkouts) workouts")
        
        return parts.joined(separator(", ")
    }
    
    // Helper formatters
    private func f(_ value: Double) -> String {
        String(format: "%.0f", value)
    }
    
    private func fh(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h\(m)m"
    }
}
