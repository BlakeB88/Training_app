//
//  StressMonitorViewModel.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/8/25.
//

import Foundation
import Combine
import HealthKit

@MainActor
class StressMonitorViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentStress: StressMetrics?
    @Published var todayStressData: [StressMetrics] = []
    @Published var dailySummary: DailyStressSummary?
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    
    // MARK: - Computed Properties
    
    var currentStressLevel: Double {
    currentStress?.stressLevel ?? 0.0
    }
    
    var currentStressZone: StressZone {
    currentStress?.stressZone ?? .low
    }
    
    var currentHeartRate: Double? {
    currentStress?.heartRate
    }
    
    var baselineHeartRate: Double? {
    currentStress?.baselineHeartRate
    }
    
    var todayAverageStress: Double {
    dailySummary?.averageStress ?? 0.0
    }
    
    var todayMaxStress: Double {
    dailySummary?.maxStress ?? 0.0
    }
    
    var timeInHighStress: TimeInterval {
    dailySummary?.timeInHighStress ?? 0
    }
    
    var timeInMediumStress: TimeInterval {
    dailySummary?.timeInMediumStress ?? 0
    }
    
    var timeInLowStress: TimeInterval {
    dailySummary?.timeInLowStress ?? 0
    }
    
    var longestHighStressPeriod: (start: Date, duration: TimeInterval)? {
    dailySummary?.longestHighStressPeriod
    }
    
    var hasDataForToday: Bool {
    !todayStressData.isEmpty
    }
    
    var isExerciseRelated: Bool {
    currentStress?.isExerciseRelated ?? false
    }
    
    // MARK: - Dependencies
    
    private let healthKitManager: HealthKitManager
    private let stressQuery: StressQuery
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    private let updateInterval: TimeInterval = 5 * 60 // Update every 5 minutes
    
    // MARK: - Initialization
    init(
        healthKitManager: HealthKitManager,
        stressQuery: StressQuery? = nil
    ) {
        self.healthKitManager = healthKitManager
        self.stressQuery = stressQuery ?? StressQuery(healthStore: healthKitManager.healthStore)
    }
    
    // MARK: - Public Methods
    
    /// Initialize stress monitoring
    func initialize() async {
    isLoading = true
    errorMessage = nil
    
    // Load today's stress data
    await loadTodayStressData()
    
    // Start observing heart rate changes
    startHeartRateObserver()
    
    // Start periodic updates
    startPeriodicUpdates()
    
    isLoading = false
    }
    
    /// Refresh current stress reading
    func refreshCurrentStress() async {
    do {
    // Fetch latest readings
    async let latestHR = stressQuery.fetchLatestHeartRate()
    async let latestHRV = stressQuery.fetchLatestHRV()
    async let baselineRHR = stressQuery.fetchRestingHeartRate()
    async let baselineHRV = stressQuery.fetchBaselineHRV()
    
    let hrReading = try await latestHR
    let hrvReading = try await latestHRV
    let rhr = try await baselineRHR
    let baseHRV = try await baselineHRV
    
    guard let hr = hrReading, let baseline = rhr else {
    errorMessage = "Unable to fetch heart rate data"
    return
    }
    
    // Check if workout is active
    let isWorkout = try await stressQuery.isWorkoutActive(at: hr.timestamp, bufferMinutes: 60)
    
    // Use HRV reading directly (it's already a tuple)
    let hrvTuple = hrvReading
    
    // Calculate current stress
    let stress = StressCalculator.calculateCurrentStress(
    latestHeartRate: hr,
    baselineHeartRate: baseline,
    latestHRV: hrvTuple,
    baselineHRV: baseHRV,
    isWorkoutActive: isWorkout
    )
    
    currentStress = stress
    lastUpdateTime = Date()
    
    // Add to today's data if valid
    if let stress = stress, !stress.isExerciseRelated {
    addStressReading(stress)
    }
    
    } catch {
    errorMessage = "Failed to refresh stress data: \(error.localizedDescription)"
    print("❌ Error refreshing stress: \(error)")
    }
    }
    
    /// Load all stress data for today
    func loadTodayStressData() async {
    isLoading = true
    errorMessage = nil
    
    do {
    let today = Calendar.current.startOfDay(for: Date())
    let now = Date()
    
    // Fetch all context data for today
    let contextData = try await stressQuery.fetchStressContextData(from: today, to: now)
    
    guard contextData.baselineRestingHeartRate != nil else {
    errorMessage = "No baseline heart rate available. Wear your Apple Watch for a few days to establish a baseline."
    isLoading = false
    return
    }
    
    // Calculate stress metrics for all readings
    let stressMetrics = StressCalculator.calculateDailyStress(
    from: contextData,
    date: today
    )
    
    // Filter out exercise-related readings for display
    todayStressData = stressMetrics.filter { !$0.isExerciseRelated }
    
    // Create daily summary
    dailySummary = DailyStressSummary(
    date: today,
    stressReadings: stressMetrics
    )
    
    // Set current stress to most recent reading
    if let latest = stressMetrics.last {
    currentStress = latest
    lastUpdateTime = latest.timestamp
    }
    
    } catch {
    errorMessage = "Failed to load stress data: \(error.localizedDescription)"
    print("❌ Error loading stress data: \(error)")
    }
    
    isLoading = false
    }
    
    /// Get stress data for charting (downsampled)
    func getChartData() -> [StressMetrics] {
    guard !todayStressData.isEmpty else { return [] }
    
    // Downsample to 288 points (5-minute intervals)
    return StressCalculator.downsampleMetrics(todayStressData, to: 288)
    }
    
    /// Get stress explanation for current reading
    func getCurrentStressExplanation() -> String {
    guard let stress = currentStress else {
    return "No stress data available"
    }
    
    if stress.isExerciseRelated {
    return "Your heart rate is elevated after recent activity. It is normal for your body to have slightly higher stress as a residual effect of exercise."
    }
    
    return stress.getExplanation()
    }
    
    /// Get formatted time for longest high stress period
    func getFormattedHighStressPeriod() -> String? {
    guard let period = longestHighStressPeriod else { return nil }
    
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    let startTime = formatter.string(from: period.start)
    
    let durationMinutes = Int(period.duration / 60)
    
    return "Started at \(startTime) and lasted for \(durationMinutes) minutes"
    }
    
    // MARK: - Private Methods
    
    private func addStressReading(_ stress: StressMetrics) {
    // Add to today's data
    todayStressData.append(stress)
    
    // Keep only last 24 hours of data
    let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)
    todayStressData = todayStressData.filter { $0.timestamp >= oneDayAgo }
    
    // Update daily summary
    let today = Calendar.current.startOfDay(for: Date())
    dailySummary = DailyStressSummary(
    date: today,
    stressReadings: todayStressData
    )
    }
    
    private func startHeartRateObserver() {
    healthKitManager.startObservingHeartRate { [weak self] in
    Task { @MainActor in
    await self?.refreshCurrentStress()
    }
    }
    }
    
    private func startPeriodicUpdates() {
    // Update every 5 minutes
    updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
    Task { @MainActor in
    await self?.refreshCurrentStress()
    }
    }
    }
    
    private func stopPeriodicUpdates() {
    updateTimer?.invalidate()
    updateTimer = nil
    }
    
    // MARK: - Deinit
    
    deinit {
    // Invalidate timer directly since deinit is nonisolated
    updateTimer?.invalidate()
    }
}

// MARK: - Helper Extensions

extension StressMonitorViewModel {
    
    /// Get stress readings for a specific time range
    func getStressReadings(from startDate: Date, to endDate: Date) -> [StressMetrics] {
    return todayStressData.filter { reading in
    reading.timestamp >= startDate && reading.timestamp <= endDate
    }
    }
    
    /// Check if stress is elevated at a specific time
    func isStressElevated(at date: Date, threshold: Double = 2.0) -> Bool {
    guard let reading = todayStressData.first(where: {
    abs($0.timestamp.timeIntervalSince(date)) < 5 * 60 // Within 5 minutes
    }) else {
    return false
    }
    
    return reading.stressLevel >= threshold && !reading.isExerciseRelated
    }
    
    /// Get average stress for a time range
    func getAverageStress(from startDate: Date, to endDate: Date) -> Double {
    let readings = getStressReadings(from: startDate, to: endDate)
    return StressCalculator.calculateAverageStress(from: readings)
    }
    
    /// Find elevated stress periods in today's data
    func getElevatedStressPeriods(threshold: Double = 2.0, minimumMinutes: Int = 5) -> [(start: Date, end: Date, averageStress: Double)] {
    return StressCalculator.findElevatedStressPeriods(
    from: todayStressData,
    threshold: threshold,
    minimumDurationMinutes: minimumMinutes
    )
    }
}

// MARK: - Formatting Helpers

extension StressMonitorViewModel {
    
    func formatStressLevel(_ level: Double) -> String {
    return String(format: "%.1f", level)
    }
    
    func formatHeartRate(_ hr: Double) -> String {
    return String(format: "%.0f bpm", hr)
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
    let hours = Int(duration) / 3600
    let minutes = (Int(duration) % 3600) / 60
    
    if hours > 0 {
    return "\(hours)h \(minutes)m"
    } else {
    return "\(minutes) min"
    }
    }
    
    func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
    }
    
    func getStressZoneColor(_ zone: StressZone) -> String {
    return zone.colorHex
    }
}
