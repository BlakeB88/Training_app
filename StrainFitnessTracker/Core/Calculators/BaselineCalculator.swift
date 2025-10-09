import Foundation

struct BaselineCalculator {
    
    /// Calculate baseline metrics from historical data
    static func calculateBaselines(from metrics: [SimpleDailyMetrics], forDate date: Date = Date()) -> BaselineMetrics? {
        let calendar = Calendar.current
        
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: date)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        
        let last28Days = metrics.filter { $0.date >= twentyEightDaysAgo && $0.date < date }
        let last7Days = metrics.filter { $0.date >= sevenDaysAgo && $0.date < date }
        
        guard last7Days.count >= 5 else {
            return nil
        }
        
        // Calculate HRV baseline (7-day average)
        let hrvReadings: [Double] = last7Days.compactMap { metric -> Double? in
            guard let hrv = metric.hrvAverage, hrv > 0 else { return nil }
            return hrv
        }
        let hrvBaseline: Double? = hrvReadings.isEmpty ? nil : hrvReadings.reduce(0, +) / Double(hrvReadings.count)
        let hrvStdDev: Double? = hrvReadings.isEmpty ? nil : calculateStandardDeviation(hrvReadings)
        
        // Calculate Resting HR baseline (7-day average)
        let rhrReadings: [Double] = last7Days.compactMap { metric -> Double? in
            guard let rhr = metric.restingHeartRate, rhr > 0 else { return nil }
            return rhr
        }
        let rhrBaseline: Double? = rhrReadings.isEmpty ? nil : rhrReadings.reduce(0, +) / Double(rhrReadings.count)
        let rhrStdDev: Double? = rhrReadings.isEmpty ? nil : calculateStandardDeviation(rhrReadings)
        
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
    
    static func calculate7DayAverage(values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let validValues = values.filter { $0 > 0 }
        guard !validValues.isEmpty else { return nil }
        return validValues.reduce(0, +) / Double(validValues.count)
    }
    
    static func calculate28DayAverage(values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let validValues = values.filter { $0 > 0 }
        guard !validValues.isEmpty else { return nil }
        return validValues.reduce(0, +) / Double(validValues.count)
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
