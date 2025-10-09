//
//  StressCalculator.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import Foundation
import HealthKit

/// Calculates stress levels based on heart rate and HRV data
class StressCalculator {
    
    // MARK: - Constants
    
    private static let hrWeight: Double = 0.6 // Heart rate contributes 60%
    private static let hrvWeight: Double = 0.4 // HRV contributes 40%
    
    // Heart rate elevation thresholds (bpm above resting)
    private static let lowStressHRThreshold: Double = 10.0
    private static let mediumStressHRThreshold: Double = 20.0
    private static let highStressHRThreshold: Double = 30.0
    
    // HRV depression thresholds (% below baseline)
    private static let lowStressHRVThreshold: Double = 10.0
    private static let mediumStressHRVThreshold: Double = 25.0
    private static let highStressHRVThreshold: Double = 40.0
    
    // MARK: - Main Calculation Methods
    
    /// Calculate stress level from heart rate and HRV
    /// Returns a value from 0.0 (no stress) to 3.0 (maximum stress)
    static func calculateStressLevel(
    currentHeartRate: Double,
    baselineHeartRate: Double,
    currentHRV: Double?,
    baselineHRV: Double?
    ) -> Double {
    
    // Calculate HR-based stress component
    let hrStressComponent = calculateHRStressComponent(
    currentHR: currentHeartRate,
    baselineHR: baselineHeartRate
    )
    
    // Calculate HRV-based stress component
    var hrvStressComponent: Double = 0.0
    var effectiveHRVWeight = hrvWeight
    
    if let currentHRV = currentHRV, let baselineHRV = baselineHRV {
    hrvStressComponent = calculateHRVStressComponent(
    currentHRV: currentHRV,
    baselineHRV: baselineHRV
    )
    } else {
    // If no HRV data, give HR component full weight
    effectiveHRVWeight = 0.0
    }
    
    // Normalize weights if HRV is missing
    let effectiveHRWeight = hrvWeight == 0.0 ? 1.0 : hrWeight
    let totalWeight = effectiveHRWeight + effectiveHRVWeight
    
    // Combine components
    let stressLevel = (hrStressComponent * effectiveHRWeight + hrvStressComponent * effectiveHRVWeight) / totalWeight
    
    // Clamp to 0.0 - 3.0 range
    return min(max(stressLevel, 0.0), 3.0)
    }
    
    /// Calculate stress from a single heart rate reading with context
    static func calculateStressMetric(
    timestamp: Date,
    heartRate: Double,
    baselineHeartRate: Double,
    hrv: Double?,
    baselineHRV: Double?,
    isWorkoutRelated: Bool
    ) -> StressMetrics {
    
    let stressLevel = calculateStressLevel(
    currentHeartRate: heartRate,
    baselineHeartRate: baselineHeartRate,
    currentHRV: hrv,
    baselineHRV: baselineHRV
    )
    
    // Calculate confidence based on data availability
    var confidence = 1.0
    if hrv == nil || baselineHRV == nil {
    confidence *= 0.7 // Lower confidence without HRV data
    }
    if isWorkoutRelated {
    confidence *= 0.5 // Much lower confidence during workouts
    }
    
    return StressMetrics(
    timestamp: timestamp,
    stressLevel: stressLevel,
    heartRate: heartRate,
    baselineHeartRate: baselineHeartRate,
    hrv: hrv,
    baselineHRV: baselineHRV,
    isExerciseRelated: isWorkoutRelated,
    confidence: confidence
    )
    }
    
    // MARK: - Component Calculations
    
    /// Calculate stress component from heart rate elevation
    private static func calculateHRStressComponent(currentHR: Double, baselineHR: Double) -> Double {
    let elevation = currentHR - baselineHR
    
    // Map elevation to 0.0 - 3.0 scale
    if elevation < lowStressHRThreshold {
    // Low stress zone (0.0 - 1.0)
    return (elevation / lowStressHRThreshold) * 1.0
    } else if elevation < mediumStressHRThreshold {
    // Medium stress zone (1.0 - 2.0)
    let normalizedElevation = (elevation - lowStressHRThreshold) / (mediumStressHRThreshold - lowStressHRThreshold)
    return 1.0 + (normalizedElevation * 1.0)
    } else if elevation < highStressHRThreshold {
    // High stress zone (2.0 - 3.0)
    let normalizedElevation = (elevation - mediumStressHRThreshold) / (highStressHRThreshold - mediumStressHRThreshold)
    return 2.0 + (normalizedElevation * 1.0)
    } else {
    // Maximum stress
    return 3.0
    }
    }
    
    /// Calculate stress component from HRV depression
    private static func calculateHRVStressComponent(currentHRV: Double, baselineHRV: Double) -> Double {
    guard baselineHRV > 0 else { return 0 }
    
    // Calculate percent depression (negative if HRV is higher than baseline)
    let percentDepression = ((baselineHRV - currentHRV) / baselineHRV) * 100.0
    
    // Map depression to 0.0 - 3.0 scale
    if percentDepression < lowStressHRVThreshold {
    // Low stress zone
    return max(0.0, (percentDepression / lowStressHRVThreshold) * 1.0)
    } else if percentDepression < mediumStressHRVThreshold {
    // Medium stress zone
    let normalizedDepression = (percentDepression - lowStressHRVThreshold) / (mediumStressHRVThreshold - lowStressHRVThreshold)
    return 1.0 + (normalizedDepression * 1.0)
    } else if percentDepression < highStressHRVThreshold {
    // High stress zone
    let normalizedDepression = (percentDepression - mediumStressHRVThreshold) / (highStressHRVThreshold - mediumStressHRVThreshold)
    return 2.0 + (normalizedDepression * 1.0)
    } else {
    // Maximum stress
    return 3.0
    }
    }
    
    // MARK: - Batch Processing
    
    /// Calculate stress metrics for a full day
    static func calculateDailyStress(
    from contextData: StressContextData,
    date: Date
    ) -> [StressMetrics] {
    
    guard let baselineRHR = contextData.baselineRestingHeartRate else {
    print("⚠️ No baseline RHR available for stress calculation")
    return []
    }
    
    let baselineHRV = contextData.baselineHRV
    
    var stressMetrics: [StressMetrics] = []
    
    // Process each heart rate reading
    for hrReading in contextData.heartRateReadings {
    // Find nearest HRV reading
    let nearestHRV = contextData.findNearestHRV(to: hrReading.timestamp, withinMinutes: 30)
    
    // Check if this is workout-related
    let isWorkoutRelated = contextData.isWorkoutRelated(timestamp: hrReading.timestamp, bufferMinutes: 60)
    
    // Calculate stress metric
    let stressMetric = calculateStressMetric(
    timestamp: hrReading.timestamp,
    heartRate: hrReading.heartRate,
    baselineHeartRate: baselineRHR,
    hrv: nearestHRV,
    baselineHRV: baselineHRV,
    isWorkoutRelated: isWorkoutRelated
    )
    
    stressMetrics.append(stressMetric)
    }
    
    return stressMetrics.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Calculate current stress level from latest readings
    static func calculateCurrentStress(
    latestHeartRate: (timestamp: Date, heartRate: Double)?,
    baselineHeartRate: Double,
    latestHRV: (timestamp: Date, hrv: Double)?,
    baselineHRV: Double?,
    isWorkoutActive: Bool
    ) -> StressMetrics? {
    
    guard let hrReading = latestHeartRate else {
    return nil
    }
    
    // Check if HRV reading is recent enough (within 30 minutes)
    var currentHRV: Double?
    if let hrvReading = latestHRV {
    let timeDifference = abs(hrvReading.timestamp.timeIntervalSince(hrReading.timestamp))
    if timeDifference <= 30 * 60 { // 30 minutes
    currentHRV = hrvReading.hrv
    }
    }
    
    return calculateStressMetric(
    timestamp: hrReading.timestamp,
    heartRate: hrReading.heartRate,
    baselineHeartRate: baselineHeartRate,
    hrv: currentHRV,
    baselineHRV: baselineHRV,
    isWorkoutRelated: isWorkoutActive
    )
    }
    
    // MARK: - Statistical Analysis
    
    /// Calculate average stress over a time period (excluding workout-related stress)
    static func calculateAverageStress(from metrics: [StressMetrics]) -> Double {
    let validMetrics = metrics.filter { !$0.isExerciseRelated && $0.confidence > 0.5 }
    guard !validMetrics.isEmpty else { return 0 }
    
    let totalStress = validMetrics.reduce(0.0) { $0 + $1.stressLevel }
    return totalStress / Double(validMetrics.count)
    }
    
    /// Find periods of elevated stress
    static func findElevatedStressPeriods(
    from metrics: [StressMetrics],
    threshold: Double = 2.0,
    minimumDurationMinutes: Int = 5
    ) -> [(start: Date, end: Date, averageStress: Double)] {
    
    let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
    var periods: [(start: Date, end: Date, averageStress: Double)] = []
    
    var currentPeriodStart: Date?
    var currentPeriodMetrics: [StressMetrics] = []
    
    for metric in sortedMetrics {
    if metric.stressLevel >= threshold && !metric.isExerciseRelated {
    if currentPeriodStart == nil {
    // Start new period
    currentPeriodStart = metric.timestamp
    currentPeriodMetrics = [metric]
    } else {
    // Continue existing period
    currentPeriodMetrics.append(metric)
    }
    } else {
    // Check if we have a period to close
    if let start = currentPeriodStart,
    let end = currentPeriodMetrics.last?.timestamp,
    !currentPeriodMetrics.isEmpty {
    
    let duration = end.timeIntervalSince(start) / 60.0 // minutes
    
    if duration >= Double(minimumDurationMinutes) {
    let avgStress = currentPeriodMetrics.reduce(0.0) { $0 + $1.stressLevel } / Double(currentPeriodMetrics.count)
    periods.append((start, end, avgStress))
    }
    
    currentPeriodStart = nil
    currentPeriodMetrics = []
    }
    }
    }
    
    // Check if there's an ongoing period at the end
    if let start = currentPeriodStart,
    let end = currentPeriodMetrics.last?.timestamp,
    !currentPeriodMetrics.isEmpty {
    
    let duration = end.timeIntervalSince(start) / 60.0
    if duration >= Double(minimumDurationMinutes) {
    let avgStress = currentPeriodMetrics.reduce(0.0) { $0 + $1.stressLevel } / Double(currentPeriodMetrics.count)
    periods.append((start, end, avgStress))
    }
    }
    
    return periods
    }
    
    /// Calculate stress distribution (time spent in each zone)
    static func calculateStressDistribution(from metrics: [StressMetrics]) -> (low: TimeInterval, medium: TimeInterval, high: TimeInterval) {
    let validMetrics = metrics.filter { !$0.isExerciseRelated }
    
    let lowStress = validMetrics.filter { $0.stressLevel < 1.0 }
    let mediumStress = validMetrics.filter { $0.stressLevel >= 1.0 && $0.stressLevel < 2.0 }
    let highStress = validMetrics.filter { $0.stressLevel >= 2.0 }
    
    // Assuming each reading represents ~5 minutes
    let intervalMinutes: Double = 5.0
    
    return (
    low: TimeInterval(lowStress.count) * intervalMinutes * 60,
    medium: TimeInterval(mediumStress.count) * intervalMinutes * 60,
    high: TimeInterval(highStress.count) * intervalMinutes * 60
    )
    }
    
    /// Downsample metrics to reduce data points (for charting)
    static func downsampleMetrics(
    _ metrics: [StressMetrics],
    to targetCount: Int = 288 // 5-minute intervals in 24 hours
    ) -> [StressMetrics] {
    
    guard metrics.count > targetCount else {
    return metrics
    }
    
    let sortedMetrics = metrics.sorted { $0.timestamp < $1.timestamp }
    let strideValue = metrics.count / targetCount
    
    var downsampled: [StressMetrics] = []
    
    for i in stride(from: 0, to: sortedMetrics.count, by: strideValue) {
        let endIndex = min(i + strideValue, sortedMetrics.count)
        let slice = Array(sortedMetrics[i..<endIndex])
    
        // Average the slice
        guard !slice.isEmpty else { continue }
        
        let avgStress = slice.reduce(0.0) { $0 + $1.stressLevel } / Double(slice.count)
        let avgHR = slice.reduce(0.0) { $0 + $1.heartRate } / Double(slice.count)
        
        let hrvValues = slice.compactMap { $0.hrv }
        let avgHRV = hrvValues.isEmpty ? nil : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
        
        let isWorkoutRelated = slice.contains { $0.isExerciseRelated }
        let avgConfidence = slice.reduce(0.0) { $0 + $1.confidence } / Double(slice.count)
        
        let metric = StressMetrics(
        timestamp: slice[slice.count / 2].timestamp,
        stressLevel: avgStress,
        heartRate: avgHR,
        baselineHeartRate: slice.first!.baselineHeartRate,
        hrv: avgHRV,
        baselineHRV: slice.first!.baselineHRV,
        isExerciseRelated: isWorkoutRelated,
        confidence: avgConfidence
        )
        
        downsampled.append(metric)
    }
    
    return downsampled
    }
    
    // MARK: - Helper Methods
    
    /// Determine if heart rate elevation is significant for stress
    static func isSignificantElevation(currentHR: Double, baselineHR: Double) -> Bool {
    return (currentHR - baselineHR) >= lowStressHRThreshold
    }
    
    /// Determine if HRV depression is significant for stress
    static func isSignificantHRVDepression(currentHRV: Double, baselineHRV: Double) -> Bool {
    guard baselineHRV > 0 else { return false }
    let percentDepression = ((baselineHRV - currentHRV) / baselineHRV) * 100.0
    return percentDepression >= lowStressHRVThreshold
    }
    
    /// Get stress zone description
    static func getStressZoneDescription(for stressLevel: Double) -> String {
    switch stressLevel {
    case 0.0..<1.0:
    return "Low stress - your body is in a relaxed state"
    case 1.0..<2.0:
    return "Medium stress - elevated heart rate and activity"
    case 2.0...3.0:
    return "High stress - significant physiological stress response"
    default:
    return "Unknown"
    }
    }
}

// MARK: - Extensions

extension StressMetrics {
    /// Get a descriptive explanation of this stress reading
    func getExplanation() -> String {
    var explanation = "Your heart rate is \(Int(heartRate)) bpm"
    
    let elevation = heartRate - baselineHeartRate
    if elevation > 0 {
    explanation += ", which is \(Int(elevation)) bpm above your resting rate"
    } else {
    explanation += ", which is at or below your resting rate"
    }
    
    if let hrv = hrv, let baselineHRV = baselineHRV, baselineHRV > 0 {
    let percentDiff = ((baselineHRV - hrv) / baselineHRV) * 100.0
    if percentDiff > 0 {
    explanation += ". Your HRV is \(Int(abs(percentDiff)))% below baseline"
    } else {
    explanation += ". Your HRV is \(Int(abs(percentDiff)))% above baseline"
    }
    }
    
    if isExerciseRelated {
    explanation += ". This reading is from during or shortly after exercise"
    }
    
    explanation += "."
    
    return explanation
    }
}
