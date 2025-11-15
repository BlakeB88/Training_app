import Foundation

struct BaselineCalculator {
    
    /// Calculate baseline metrics from historical data with outlier filtering
    static func calculateBaselines(from metrics: [SimpleDailyMetrics], forDate date: Date = Date()) -> BaselineMetrics? {
        let calendar = Calendar.current
        
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: date)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        
        let last28Days = metrics.filter { $0.date >= twentyEightDaysAgo && $0.date < date }
        let last7Days = metrics.filter { $0.date >= sevenDaysAgo && $0.date < date }
        
        guard last7Days.count >= 5 else {
            return nil
        }
        
        // ✅ NEW: Collect and filter HRV readings to remove outliers
        let hrvReadings: [Double] = last7Days.compactMap { metric -> Double? in
            guard let hrv = metric.hrvAverage, hrv > 0 else { return nil }
            return hrv
        }
        
        // Apply outlier filtering to HRV
        let filteredHRV = HRVOutlierFilter.filterOutliers(hrvReadings)
        
        let hrvBaseline: Double? = filteredHRV.isEmpty ? nil : filteredHRV.reduce(0, +) / Double(filteredHRV.count)
        let hrvStdDev: Double? = filteredHRV.isEmpty ? nil : calculateStandardDeviation(filteredHRV)
        
        // Log if outliers were removed
        if hrvReadings.count != filteredHRV.count {
            let removed = hrvReadings.count - filteredHRV.count
            let originalAvg = hrvReadings.reduce(0, +) / Double(hrvReadings.count)
            print("  🔍 HRV Baseline: Filtered \(removed) outliers from \(hrvReadings.count) readings")
            print("    Original avg: \(String(format: "%.1f", originalAvg)) ms → Filtered avg: \(String(format: "%.1f", hrvBaseline ?? 0)) ms")
        }
        
        // ✅ UPDATED: Filter RHR for extreme values (though less common)
        let rhrReadings: [Double] = last7Days.compactMap { metric -> Double? in
            guard let rhr = metric.restingHeartRate, rhr > 0 else { return nil }
            return rhr
        }
        
        // Apply basic filtering for RHR (remove extreme outliers)
        let filteredRHR = rhrReadings.filter { $0 >= 35 && $0 <= 120 }
        
        let rhrBaseline: Double? = filteredRHR.isEmpty ? nil : filteredRHR.reduce(0, +) / Double(filteredRHR.count)
        let rhrStdDev: Double? = filteredRHR.isEmpty ? nil : calculateStandardDeviation(filteredRHR)
        
        if rhrReadings.count != filteredRHR.count {
            print("  🔍 RHR Baseline: Filtered \(rhrReadings.count - filteredRHR.count) extreme values")
        }
        
        // Calculate acute strain (7-day average)
        let acuteStrainValues = last7Days.map { $0.strain }
        let acuteStrain: Double? = acuteStrainValues.isEmpty ? nil : acuteStrainValues.reduce(0, +) / Double(acuteStrainValues.count)
        
        // Calculate chronic strain (28-day average)
        let chronicStrainValues = last28Days.map { $0.strain }
        let chronicStrain: Double? = chronicStrainValues.isEmpty ? acuteStrain :
            chronicStrainValues.reduce(0, +) / Double(chronicStrainValues.count)
        
        return BaselineMetrics(
            hrvBaseline: hrvBaseline,
            hrvStandardDeviation: hrvStdDev,
            rhrBaseline: rhrBaseline,
            rhrStandardDeviation: rhrStdDev,
            acuteStrain: acuteStrain,
            chronicStrain: chronicStrain,
            respiratoryRateBaseline: nil,
            calculatedDate: date,
            daysOfData: last7Days.count
        )
    }
    
    /// Calculate standard deviation
    private static func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
    
    /// ✅ NEW: Calculate 7-day average with outlier filtering
    static func calculate7DayAverage(values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let validValues = values.filter { $0 > 0 }
        guard !validValues.isEmpty else { return nil }
        
        // Filter outliers before averaging
        let filtered = HRVOutlierFilter.filterOutliers(validValues)
        guard !filtered.isEmpty else { return nil }
        
        return filtered.reduce(0, +) / Double(filtered.count)
    }
    
    /// ✅ NEW: Calculate 28-day average with outlier filtering
    static func calculate28DayAverage(values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let validValues = values.filter { $0 > 0 }
        guard !validValues.isEmpty else { return nil }
        
        // Filter outliers before averaging
        let filtered = HRVOutlierFilter.filterOutliers(validValues)
        guard !filtered.isEmpty else { return nil }
        
        return filtered.reduce(0, +) / Double(filtered.count)
    }
    
    static func acwrRiskLevel(acwr: Double) -> ACWRStatus {
        switch acwr {
        case ..<0.8:
            return .undertraining
        case 0.8..<1.3:
            return .optimal
        case 1.3..<1.5:
            return .caution
        default:
            return .highRisk
        }
    }
    
    static func acwrRiskDescription(for status: ACWRStatus) -> String {
        return status.description
    }
}
