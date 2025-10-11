import Foundation

class HealthContextBuilder {
    private let repository: MetricsRepository
    private let healthKitManager: HealthKitManager
    
    init(repository: MetricsRepository = MetricsRepository(),
         healthKitManager: HealthKitManager = .shared) {
        self.repository = repository
        self.healthKitManager = healthKitManager
    }
    
    /// Build comprehensive health context for AI from user's data
    func buildHealthContext() async throws -> String {
        let today = Date().startOfDay
        let todayMetrics = try repository.fetchDailyMetrics(for: today)
        
        // Get last 7 days for trends
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: today)!
        let recentMetrics = try repository.fetchDailyMetrics(from: sevenDaysAgo, to: today)
        
        var context = "TODAY'S METRICS:\n"
        context += formatTodayMetrics(todayMetrics)
        
        context += "\n7-DAY TRENDS:\n"
        context += formatTrends(recentMetrics)
        
        context += "\nWEEKLY SUMMARY:\n"
        context += formatWeeklySummary(recentMetrics)
        
        return context
    }
    
    private func formatTodayMetrics(_ metrics: SimpleDailyMetrics?) -> String {
        guard let metrics = metrics else {
            return "No data tracked yet today.\n"
        }
        
        var output = ""
        
        // Strain & Recovery
        output += "Strain Score: \(String(format: "%.1f", metrics.strain))/21\n"
        if let recovery = metrics.recovery {
            output += "Recovery Score: \(String(format: "%.0f", recovery))/100\n"
        }
        
        // Sleep
        if let sleepDuration = metrics.sleepDuration {
            output += "Sleep: \(formatHours(sleepDuration)) hours"
            if let efficiency = metrics.sleepEfficiency {
                output += " (Efficiency: \(String(format: "%.0f", efficiency))%)"
            }
            output += "\n"
        }
        
        // Physiological Metrics
        if let rhr = metrics.restingHeartRate {
            output += "Resting Heart Rate: \(String(format: "%.0f", rhr)) bpm\n"
        }
        if let hrv = metrics.hrvAverage {
            output += "Heart Rate Variability: \(String(format: "%.0f", hrv)) ms\n"
        }
        if let respRate = metrics.respiratoryRate {
            output += "Respiratory Rate: \(String(format: "%.0f", respRate)) breaths/min\n"
        }
        
        // Activity
        if let steps = metrics.steps {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            let stepsFormatted = formatter.string(from: NSNumber(value: steps)) ?? "\(steps)"
            output += "Steps: \(stepsFormatted)\n"
        }
        if let calories = metrics.activeCalories {
            output += "Active Calories: \(String(format: "%.0f", calories))\n"
        }
        
        // Workouts
        if !metrics.workouts.isEmpty {
            output += "Workouts Today: \(metrics.workouts.count)\n"
            for workout in metrics.workouts {
                let avgHR = String(format: "%.0f", workout.averageHeartRate ?? 0)
                output += "  - \(workout.workoutType.name): \(formatHours(workout.duration)) at \(avgHR) avg bpm\n"
            }
        }
        
        // Stress
        if let avgStress = metrics.averageStress {
            let stressLevel = stressLevelDescription(avgStress)
            output += "Average Stress: \(String(format: "%.1f", avgStress))/3.0 (\(stressLevel))\n"
            if let maxStress = metrics.maxStress {
                output += "Peak Stress: \(String(format: "%.1f", maxStress))/3.0\n"
            }
        }
        
        return output
    }
    
    private func formatTrends(_ metrics: [SimpleDailyMetrics]) -> String {
        guard !metrics.isEmpty else { return "No recent data.\n" }
        
        var output = ""
        
        // Strain trend
        let strainValues = metrics.map { $0.strain }
        let avgStrain = strainValues.reduce(0, +) / Double(strainValues.count)
        let maxStrain = strainValues.max() ?? 0
        output += "Strain: Avg \(String(format: "%.1f", avgStrain)), Peak \(String(format: "%.1f", maxStrain))\n"
        
        // Recovery trend
        let recoveryValues = metrics.compactMap { $0.recovery }
        if !recoveryValues.isEmpty {
            let avgRecovery = recoveryValues.reduce(0, +) / Double(recoveryValues.count)
            output += "Recovery: Avg \(String(format: "%.0f", avgRecovery))/100\n"
        }
        
        // Sleep trend
        let sleepValues = metrics.compactMap { $0.sleepDuration }
        if !sleepValues.isEmpty {
            let avgSleep = sleepValues.reduce(0, +) / Double(sleepValues.count)
            output += "Sleep: Avg \(formatHours(avgSleep)) per night\n"
        }
        
        // HRV trend
        let hrvValues = metrics.compactMap { $0.hrvAverage }
        if !hrvValues.isEmpty {
            let avgHRV = hrvValues.reduce(0, +) / Double(hrvValues.count)
            output += "HRV: Avg \(String(format: "%.0f", avgHRV)) ms\n"
        }
        
        // Stress trend
        let stressValues = metrics.compactMap { $0.averageStress }
        if !stressValues.isEmpty {
            let avgStress = stressValues.reduce(0, +) / Double(stressValues.count)
            output += "Stress: Avg \(String(format: "%.1f", avgStress))/3.0\n"
        }
        
        return output
    }
    
    private func formatWeeklySummary(_ metrics: [SimpleDailyMetrics]) -> String {
        guard !metrics.isEmpty else { return "No recent data.\n" }
        
        var output = ""
        
        // Total workouts
        let totalWorkouts = metrics.flatMap { $0.workouts }.count
        output += "Total Workouts: \(totalWorkouts)\n"
        
        // Total strain load
        let totalStrain = metrics.reduce(0) { $0 + $1.strain }
        output += "Weekly Strain Load: \(String(format: "%.1f", totalStrain))\n"
        
        // Average sleep duration
        let sleepValues = metrics.compactMap { $0.sleepDuration }
        if !sleepValues.isEmpty {
            let avgSleep = sleepValues.reduce(0, +) / Double(sleepValues.count)
            output += "Average Sleep/Night: \(formatHours(avgSleep))\n"
        }
        
        // Days with adequate recovery
        let daysWithRecovery = metrics.filter { ($0.recovery ?? 0) >= 50 }.count
        output += "Days with Good Recovery: \(daysWithRecovery)/\(metrics.count)\n"
        
        // Workout breakdown
        let workoutsByType = Dictionary(grouping: metrics.flatMap { $0.workouts }) { $0.workoutType }
        if !workoutsByType.isEmpty {
            output += "Workout Types: "
            let typeNames = workoutsByType.keys.map { type in
                "\(type.name) (\(workoutsByType[type]?.count ?? 0))"
            }.joined(separator: ", ")
            output += typeNames + "\n"
        }
        
        return output
    }
    
    private func stressLevelDescription(_ level: Double) -> String {
        switch level {
        case 0..<1.0: return "Low"
        case 1.0..<2.0: return "Moderate"
        case 2.0...3.0: return "High"
        default: return "Unknown"
        }
    }
    
    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return "\(h)h \(m)m"
    }
}
