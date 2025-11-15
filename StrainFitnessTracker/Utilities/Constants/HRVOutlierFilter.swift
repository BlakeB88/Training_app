import Foundation

/// Utility for filtering HRV outliers using statistical methods
struct HRVOutlierFilter {
    
    // MARK: - Updated BaselineCalculator Integration
    
    /// Calculate baseline metrics with outlier filtering
    static func calculateBaselinesWithFiltering(from metrics: [SimpleDailyMetrics], forDate date: Date = Date()) -> BaselineMetrics? {
        let calendar = Calendar.current
        
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: date)!
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        
        let last28Days = metrics.filter { $0.date >= twentyEightDaysAgo && $0.date < date }
        let last7Days = metrics.filter { $0.date >= sevenDaysAgo && $0.date < date }
        
        guard last7Days.count >= 5 else {
            return nil
        }
        
        // Collect all HRV readings (with outlier filtering)
        let allHRVValues: [Double] = last7Days.compactMap { $0.hrvAverage }.filter { $0 > 0 }
        let filteredHRV = HRVOutlierFilter.filterOutliers(allHRVValues)
        
        let hrvBaseline: Double? = filteredHRV.isEmpty ? nil : filteredHRV.reduce(0, +) / Double(filteredHRV.count)
        let hrvStdDev: Double? = filteredHRV.isEmpty ? nil : calculateStandardDeviation(filteredHRV)
        
        // RHR typically doesn't have as many outliers, but we can still filter extreme values
        let allRHRValues: [Double] = last7Days.compactMap { $0.restingHeartRate }.filter { $0 > 0 && $0 < 120 }
        let rhrBaseline: Double? = allRHRValues.isEmpty ? nil : allRHRValues.reduce(0, +) / Double(allRHRValues.count)
        let rhrStdDev: Double? = allRHRValues.isEmpty ? nil : calculateStandardDeviation(allRHRValues)
        
        // Calculate strain (no filtering needed for strain)
        let acuteStrainValues = last7Days.map { $0.strain }
        let acuteStrain: Double? = acuteStrainValues.isEmpty ? nil : acuteStrainValues.reduce(0, +) / Double(acuteStrainValues.count)
        
        let chronicStrainValues = last28Days.map { $0.strain }
        let chronicStrain: Double? = chronicStrainValues.isEmpty ? acuteStrain :
            chronicStrainValues.reduce(0, +) / Double(chronicStrainValues.count)
        
        // Log outlier analysis if any were removed
        if allHRVValues.count != filteredHRV.count {
            print("  🔍 HRV Baseline: Filtered \(allHRVValues.count - filteredHRV.count) outliers from \(allHRVValues.count) readings")
        }
        
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
    
    private static func calculateStandardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(values.count - 1)
        
        return sqrt(variance)
    }
}

// MARK: - Original HRVOutlierFilter

extension HRVOutlierFilter {
    
    // MARK: - Configuration
    
    /// Maximum reasonable HRV value (in ms) - readings above this are likely errors
    static let absoluteMaxHRV: Double = 200.0
    
    /// Minimum reasonable HRV value (in ms) - readings below this are likely errors
    static let absoluteMinHRV: Double = 10.0
    
    /// Number of standard deviations for outlier detection
    static let stdDevThreshold: Double = 3.0
    
    /// Minimum number of samples needed for statistical filtering
    static let minimumSamplesForStats: Int = 5
    
    // MARK: - Filtering Methods
    
    /// Filter HRV values using multiple methods (recommended)
    /// - Parameter values: Array of HRV values in milliseconds
    /// - Returns: Filtered array with outliers removed
    static func filterOutliers(_ values: [Double]) -> [Double] {
        guard !values.isEmpty else { return [] }
        
        // Step 1: Remove absolute outliers (obvious errors)
        let absoluteFiltered = filterAbsoluteOutliers(values)
        
        // Step 2: If we have enough data, apply statistical filtering
        if absoluteFiltered.count >= minimumSamplesForStats {
            return filterStatisticalOutliers(absoluteFiltered)
        }
        
        return absoluteFiltered
    }
    
    /// Filter values outside absolute min/max thresholds
    static func filterAbsoluteOutliers(_ values: [Double]) -> [Double] {
        let filtered = values.filter { value in
            value >= absoluteMinHRV && value <= absoluteMaxHRV
        }
        
        let removedCount = values.count - filtered.count
        if removedCount > 0 {
            print("  🔍 Removed \(removedCount) absolute HRV outliers")
        }
        
        return filtered
    }
    
    /// Filter values using Modified Z-Score method (robust to outliers)
    static func filterStatisticalOutliers(_ values: [Double]) -> [Double] {
        guard values.count >= minimumSamplesForStats else { return values }
        
        // Calculate median and MAD (Median Absolute Deviation)
        let median = calculateMedian(values)
        let absoluteDeviations = values.map { abs($0 - median) }
        let mad = calculateMedian(absoluteDeviations)
        
        // Avoid division by zero
        guard mad > 0 else { return values }
        
        // Calculate modified z-scores
        let filtered = values.filter { value in
            let modifiedZScore = 0.6745 * abs(value - median) / mad
            return modifiedZScore <= stdDevThreshold
        }
        
        let removedCount = values.count - filtered.count
        if removedCount > 0 {
            print("  🔍 Removed \(removedCount) statistical HRV outliers")
        }
        
        return filtered
    }
    
    /// Filter using IQR (Interquartile Range) method
    static func filterIQROutliers(_ values: [Double]) -> [Double] {
        guard values.count >= minimumSamplesForStats else { return values }
        
        let sorted = values.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4
        
        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1
        
        let lowerBound = q1 - (1.5 * iqr)
        let upperBound = q3 + (1.5 * iqr)
        
        let filtered = values.filter { value in
            value >= lowerBound && value <= upperBound
        }
        
        let removedCount = values.count - filtered.count
        if removedCount > 0 {
            print("  🔍 Removed \(removedCount) IQR HRV outliers")
        }
        
        return filtered
    }
    
    /// Calculate average HRV with outlier filtering
    static func calculateFilteredAverage(_ values: [Double]) -> Double? {
        let filtered = filterOutliers(values)
        guard !filtered.isEmpty else { return nil }
        return filtered.reduce(0.0, +) / Double(filtered.count)
    }
    
    /// Calculate standard deviation with outlier filtering
    static func calculateFilteredStdDev(_ values: [Double]) -> Double? {
        let filtered = filterOutliers(values)
        guard filtered.count > 1 else { return nil }
        
        let mean = filtered.reduce(0.0, +) / Double(filtered.count)
        let squaredDifferences = filtered.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0.0, +) / Double(filtered.count - 1)
        
        return sqrt(variance)
    }
    
    // MARK: - Helper Methods
    
    private static func calculateMedian(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        let count = sorted.count
        
        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
    
    /// Check if a single value is likely an outlier
    static func isLikelyOutlier(_ value: Double, comparedTo values: [Double]) -> Bool {
        // Check absolute bounds
        if value < absoluteMinHRV || value > absoluteMaxHRV {
            return true
        }
        
        guard values.count >= minimumSamplesForStats else { return false }
        
        let median = calculateMedian(values)
        let absoluteDeviations = values.map { abs($0 - median) }
        let mad = calculateMedian(absoluteDeviations)
        
        guard mad > 0 else { return false }
        
        let modifiedZScore = 0.6745 * abs(value - median) / mad
        return modifiedZScore > stdDevThreshold
    }
    
    /// Get statistics about outliers in the dataset
    static func analyzeOutliers(_ values: [Double]) -> OutlierAnalysis {
        let absoluteFiltered = filterAbsoluteOutliers(values)
        let fullyFiltered = filterOutliers(values)
        
        let absoluteOutliers = values.count - absoluteFiltered.count
        let statisticalOutliers = absoluteFiltered.count - fullyFiltered.count
        let totalOutliers = values.count - fullyFiltered.count
        
        let originalAvg = values.isEmpty ? 0 : values.reduce(0.0, +) / Double(values.count)
        let filteredAvg = fullyFiltered.isEmpty ? 0 : fullyFiltered.reduce(0.0, +) / Double(fullyFiltered.count)
        
        return OutlierAnalysis(
            totalSamples: values.count,
            absoluteOutliers: absoluteOutliers,
            statisticalOutliers: statisticalOutliers,
            totalOutliers: totalOutliers,
            retainedSamples: fullyFiltered.count,
            originalAverage: originalAvg,
            filteredAverage: filteredAvg,
            averageDifference: abs(filteredAvg - originalAvg)
        )
    }
}

// MARK: - Outlier Analysis Result

struct OutlierAnalysis {
    let totalSamples: Int
    let absoluteOutliers: Int
    let statisticalOutliers: Int
    let totalOutliers: Int
    let retainedSamples: Int
    let originalAverage: Double
    let filteredAverage: Double
    let averageDifference: Double
    
    var outlierPercentage: Double {
        guard totalSamples > 0 else { return 0 }
        return (Double(totalOutliers) / Double(totalSamples)) * 100.0
    }
    
    var impactOnAverage: Double {
        guard originalAverage > 0 else { return 0 }
        return (averageDifference / originalAverage) * 100.0
    }
    
    func printSummary() {
        print("📊 HRV Outlier Analysis:")
        print("   Total samples: \(totalSamples)")
        print("   Absolute outliers: \(absoluteOutliers)")
        print("   Statistical outliers: \(statisticalOutliers)")
        print("   Total removed: \(totalOutliers) (\(String(format: "%.1f", outlierPercentage))%)")
        print("   Retained: \(retainedSamples)")
        print("   Original avg: \(String(format: "%.1f", originalAverage)) ms")
        print("   Filtered avg: \(String(format: "%.1f", filteredAverage)) ms")
        print("   Impact: \(String(format: "%.1f", impactOnAverage))%")
    }
}
