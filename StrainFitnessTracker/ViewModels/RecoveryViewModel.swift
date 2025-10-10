import Foundation
import Combine

@MainActor
class RecoveryViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedDate: Date
    @Published var dailyMetrics: SimpleDailyMetrics?
    @Published var weeklyMetrics: [SimpleDailyMetrics] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRefreshing = false // ✅ NEW: Track refresh state
    
    // MARK: - Computed Properties
    var currentRecovery: Double? {
        dailyMetrics?.recovery
    }
    
    var recoveryLevel: String? {
        guard let recovery = currentRecovery else { return nil }
        return recovery.recoveryLevel()
    }
    
    var recoveryComponents: RecoveryComponents? {
        dailyMetrics?.recoveryComponents
    }
    
    var sleepDuration: Double? {
        dailyMetrics?.sleepDuration
    }
    
    var sleepFormatted: String? {
        guard let duration = sleepDuration else { return nil }
        let hours = Int(duration)
        let minutes = Int((duration - Double(hours)) * 60)
        return String(format: "%dh %dm", hours, minutes)
    }
    
    var hrvAverage: Double? {
        dailyMetrics?.hrvAverage
    }
    
    var restingHeartRate: Double? {
        dailyMetrics?.restingHeartRate
    }
    
    // ✅ FIXED: Recovery is now ALWAYS calculated during sync
    var hasRecoveryData: Bool {
        dailyMetrics?.recovery != nil
    }
    
    var weeklyAverageRecovery: Double? {
        let recoveries = weeklyMetrics.compactMap { $0.recovery }
        guard !recoveries.isEmpty else { return nil }
        return recoveries.reduce(0.0, +) / Double(recoveries.count)
    }
    
    /// Multi-night sleep data for chart display
    var recentSleepDurations: [Double]? {
        dailyMetrics?.recentSleepDurations
    }
    
    /// Baseline metrics for context
    var baselineMetrics: BaselineMetrics? {
        dailyMetrics?.baselineMetrics
    }
    
    // MARK: - Dependencies
    private let repository: MetricsRepository
    private let dataSyncService: DataSyncService // ✅ NEW: For triggering refreshes
    
    // MARK: - Initialization
    init(
        repository: MetricsRepository? = nil,
        dataSyncService: DataSyncService? = nil,
        selectedDate: Date = Date()
    ) {
        self.repository = repository ?? MetricsRepository()
        self.dataSyncService = dataSyncService ?? DataSyncService.shared // ✅ NEW
        self.selectedDate = selectedDate
    }
    
    // MARK: - Public Methods
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load daily metrics
            dailyMetrics = try repository.fetchDailyMetrics(for: selectedDate)
            
            // Load weekly metrics
            let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: selectedDate)!
            weeklyMetrics = try repository.fetchDailyMetrics(from: weekStart, to: selectedDate)
            
            // ✅ NEW: Log recovery status
            if let recovery = dailyMetrics?.recovery {
                print("✅ Recovery loaded: \(String(format: "%.1f", recovery))")
            } else {
                print("⚠️ No recovery data available")
            }
            
        } catch {
            errorMessage = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectDate(_ date: Date) async {
        selectedDate = date
        await loadData()
    }
    
    func previousDay() async {
        let previous = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
        await selectDate(previous)
    }
    
    func nextDay() async {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
        await selectDate(next)
    }
    
    func goToToday() async {
        await selectDate(Date())
    }
    
    // MARK: - ✅ NEW: Refresh Methods
    
    /// Force refresh today's recovery (quick refresh)
    func refreshTodayRecovery() async {
        guard Calendar.current.isDateInToday(selectedDate) else {
            errorMessage = "Can only refresh today's data"
            return
        }
        
        isRefreshing = true
        errorMessage = nil
        
        print("🔄 Force refreshing recovery for today...")
        
        await dataSyncService.syncDate(selectedDate, forceRefresh: true)
        await loadData()
        
        isRefreshing = false
    }
    
    /// Refresh entire week (slower, comprehensive)
    func refreshWeek() async {
        isRefreshing = true
        errorMessage = nil
        
        print("🔄 Refreshing entire week...")
        
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: selectedDate)!
        var currentDate = weekStart
        let endDate = selectedDate
        
        while currentDate <= endDate {
            await dataSyncService.syncDate(currentDate, forceRefresh: true)
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        await loadData()
        
        isRefreshing = false
    }
    
    /// Recalculate recovery for selected date (in-place calculation)
    func recalculateRecovery() async {
        guard let metrics = dailyMetrics else {
            errorMessage = "No metrics available"
            return
        }
        
        isRefreshing = true
        errorMessage = nil
        
        print("🔋 Recalculating recovery for \(selectedDate.formatted())...")
        
        do {
            // Get baseline metrics from historical data
            let historicalMetrics = try repository.fetchRecentDailyMetrics(days: 28)
            var baselineMetrics = calculateBaselinesFromSimpleMetrics(historicalMetrics, forDate: selectedDate)
            
            // If no baseline yet, create one with defaults
            if baselineMetrics == nil && !historicalMetrics.isEmpty {
                let validMetrics = historicalMetrics.filter { $0.hrvAverage != nil && $0.restingHeartRate != nil }
                if !validMetrics.isEmpty {
                    let hrvValues = validMetrics.compactMap { $0.hrvAverage }
                    let hrvBaseline = hrvValues.reduce(0.0, +) / Double(hrvValues.count)
                    let rhrValues = validMetrics.compactMap { $0.restingHeartRate }
                    let rhrBaseline = rhrValues.reduce(0.0, +) / Double(rhrValues.count)
                    
                    baselineMetrics = BaselineMetrics(
                        hrvBaseline: hrvBaseline,
                        hrvStandardDeviation: 15,
                        rhrBaseline: rhrBaseline,
                        rhrStandardDeviation: 5,
                        acuteStrain: nil,
                        chronicStrain: nil,
                        respiratoryRateBaseline: nil,
                        calculatedDate: selectedDate,
                        daysOfData: validMetrics.count
                    )
                }
            }
            
            // Get yesterday's strain
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)
            let recentStrain = yesterday.flatMap { try? repository.fetchDailyMetrics(for: $0)?.strain }
            
            // Recalculate recovery with all available data
            let recovery = RecoveryCalculator.calculateRecoveryScore(
                hrvCurrent: metrics.hrvAverage,
                hrvBaseline: baselineMetrics?.hrvBaseline ?? (metrics.hrvAverage.map { $0 * 0.95 }),
                hrvStdDev: baselineMetrics?.hrvStandardDeviation,
                rhrCurrent: metrics.restingHeartRate,
                rhrBaseline: baselineMetrics?.rhrBaseline ?? (metrics.restingHeartRate.map { $0 * 1.05 }),
                rhrStdDev: baselineMetrics?.rhrStandardDeviation,
                sleepDuration: metrics.sleepDuration ?? 0,
                recentSleepDurations: metrics.recentSleepDurations ?? [],
                sleepEfficiency: metrics.sleepEfficiency,
                sleepConsistency: metrics.sleepConsistency,
                recentStrain: recentStrain,
                acuteStrain: baselineMetrics?.acuteStrain,
                chronicStrain: baselineMetrics?.chronicStrain,
                respiratoryRate: metrics.respiratoryRate,
                respiratoryBaseline: baselineMetrics?.respiratoryRateBaseline
            )
            
            let components = RecoveryCalculator.recoveryComponents(
                hrvCurrent: metrics.hrvAverage,
                hrvBaseline: baselineMetrics?.hrvBaseline ?? (metrics.hrvAverage.map { $0 * 0.95 }),
                rhrCurrent: metrics.restingHeartRate,
                rhrBaseline: baselineMetrics?.rhrBaseline ?? (metrics.restingHeartRate.map { $0 * 1.05 }),
                sleepDuration: metrics.sleepDuration ?? 0,
                respiratoryRate: metrics.respiratoryRate
            )
            
            // Update metrics
            var updatedMetrics = metrics
            updatedMetrics.recovery = recovery
            updatedMetrics.recoveryComponents = components
            updatedMetrics.baselineMetrics = baselineMetrics
            updatedMetrics.lastUpdated = Date()
            
            try repository.saveDailyMetrics(updatedMetrics)
            dailyMetrics = updatedMetrics
            
            print("✅ Recovery recalculated: \(String(format: "%.1f", recovery))")
            
        } catch {
            errorMessage = "Failed to recalculate recovery: \(error.localizedDescription)"
            print("❌ Recalculation error: \(error)")
        }
        
        isRefreshing = false
    }
}

// MARK: - Chart Data
extension RecoveryViewModel {
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    var weeklyRecoveryChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let recovery = metrics.recovery else { return nil }
            return ChartDataPoint(date: metrics.date, value: recovery)
        }
    }
    
    var weeklySleepChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let sleep = metrics.sleepDuration else { return nil }
            return ChartDataPoint(date: metrics.date, value: sleep)
        }
    }
    
    var weeklyHRVChartData: [ChartDataPoint] {
        weeklyMetrics.compactMap { metrics in
            guard let hrv = metrics.hrvAverage else { return nil }
            return ChartDataPoint(date: metrics.date, value: hrv)
        }
    }
}

// MARK: - Helper Methods
extension RecoveryViewModel {
    
    private func calculateBaselinesFromSimpleMetrics(_ metrics: [SimpleDailyMetrics], forDate date: Date) -> BaselineMetrics? {
        guard !metrics.isEmpty else { return nil }
        
        let validMetrics = metrics.filter { $0.hrvAverage != nil && $0.restingHeartRate != nil }
        guard validMetrics.count >= AppConstants.Baseline.minimumDaysForBaseline else { return nil }
        
        let hrvValues = validMetrics.compactMap { $0.hrvAverage }
        let hrvBaseline = hrvValues.isEmpty ? nil : hrvValues.reduce(0.0, +) / Double(hrvValues.count)
        let hrvStdDev = hrvValues.isEmpty ? nil : standardDeviation(hrvValues)
        
        let rhrValues = validMetrics.compactMap { $0.restingHeartRate }
        let rhrBaseline = rhrValues.isEmpty ? nil : rhrValues.reduce(0.0, +) / Double(rhrValues.count)
        let rhrStdDev = rhrValues.isEmpty ? nil : standardDeviation(rhrValues)
        
        let recentMetrics = metrics.suffix(7)
        let acuteStrain = recentMetrics.isEmpty ? nil : recentMetrics.reduce(0.0) { $0 + $1.strain } / Double(recentMetrics.count)
        let chronicStrain = metrics.isEmpty ? nil : metrics.reduce(0.0) { $0 + $1.strain } / Double(metrics.count)
        
        return BaselineMetrics(
            hrvBaseline: hrvBaseline,
            hrvStandardDeviation: hrvStdDev,
            rhrBaseline: rhrBaseline,
            rhrStandardDeviation: rhrStdDev,
            acuteStrain: acuteStrain,
            chronicStrain: chronicStrain,
            respiratoryRateBaseline: nil,
            calculatedDate: date,
            daysOfData: validMetrics.count
        )
    }
    
    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0.0, +) / Double(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        let variance = squaredDifferences.reduce(0.0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}
