//
//  MLFeatureService.swift
//  StrainFitnessTracker
//
//  Service for generating ML-ready features with rolling averages and trends
//

import Foundation

@MainActor
class MLFeatureService {
    
    static let shared = MLFeatureService()
    
    private let repository: MetricsRepository
    private let nutritionQuery: NutritionQuery
    
    private init() {
        self.repository = MetricsRepository()
        self.nutritionQuery = NutritionQuery()
    }
    
    // MARK: - Generate ML Metrics
    
    /// Generate complete ML metrics for a date with all rolling features
    func generateMLMetrics(for date: Date) async throws -> MLDailyMetrics {
        print("🤖 Generating ML metrics for \(date.formatted(.dateTime.month().day()))...")
        
        // 1. Get base metrics
        guard let simple = try repository.fetchDailyMetrics(for: date) else {
            throw MLFeatureError.missingBaseMetrics
        }
        
        // 2. Start with base conversion
        var mlMetrics = MLDailyMetrics(from: simple)
        
        // 3. Fetch historical data for rolling features
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: date)!
        let historical = try repository.fetchDailyMetrics(from: sevenDaysAgo, to: date)
        
        // 4. Calculate rolling averages
        mlMetrics = addRollingAverages(to: mlMetrics, historical: historical)
        
        // 5. Calculate trends
        mlMetrics = addTrends(to: mlMetrics, historical: historical)
        
        // 6. Calculate deviations from baseline
        mlMetrics = addDeviations(to: mlMetrics, historical: historical)
        
        // 7. Add strain features
        mlMetrics = addStrainFeatures(to: mlMetrics, historical: historical)
        
        // 8. Add circadian features
        mlMetrics = addCircadianFeatures(to: mlMetrics, historical: historical)

        // 9. Add nutrition data
        mlMetrics = await addNutritionFeatures(to: mlMetrics, date: date)

        // 10. Add derived balance & normalization features
        mlMetrics = addDerivedBalanceFeatures(to: mlMetrics, historical: historical)

        // 11. Add tomorrow's recovery if available (target variable)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: date)!
        if let tomorrowMetrics = try? repository.fetchDailyMetrics(for: tomorrow) {
            mlMetrics.tomorrowRecovery = tomorrowMetrics.recovery
        }

        print("✅ ML metrics generated successfully")
        return mlMetrics
    }
    
    /// Generate ML metrics for multiple dates (batch processing)
    func generateMLMetricsBatch(from startDate: Date, to endDate: Date) async throws -> [MLDailyMetrics] {
        var allMetrics: [MLDailyMetrics] = []
        
        let calendar = Calendar.current
        var currentDate = startDate
        
        var skipped = 0

        while currentDate <= endDate {
            do {
                let metrics = try await generateMLMetrics(for: currentDate)
                allMetrics.append(metrics)
            } catch {
                skipped += 1
                print("⚠️ Skipping ML metrics for \(currentDate.formatted(.dateTime.month().day())): \(error)")
            }

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        print("📊 Generated \(allMetrics.count) ML metric records")
        return allMetrics
    }
    
    // MARK: - Rolling Averages
    
    private func addRollingAverages(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics
        
        // Last 7 days (excluding today)
        let last7Days = historical.suffix(8).dropLast()
        
        // Recovery average
        let recoveryValues = last7Days.compactMap { $0.recovery }
        updated.avgRecoveryLast7Days = recoveryValues.isEmpty ? nil : recoveryValues.reduce(0, +) / Double(recoveryValues.count)
        
        // HRV average
        let hrvValues = last7Days.compactMap { $0.hrvAverage }
        updated.avgHRVLast7Days = hrvValues.isEmpty ? nil : hrvValues.reduce(0, +) / Double(hrvValues.count)
        
        // RHR average
        let rhrValues = last7Days.compactMap { $0.restingHeartRate }
        updated.avgRHRLast7Days = rhrValues.isEmpty ? nil : rhrValues.reduce(0, +) / Double(rhrValues.count)
        
        // Sleep efficiency average
        let sleepEffValues = last7Days.compactMap { $0.sleepEfficiency }
        updated.avgSleepEfficiencyLast7Days = sleepEffValues.isEmpty ? nil : sleepEffValues.reduce(0, +) / Double(sleepEffValues.count)
        
        // Sleep duration average
        let sleepDurValues = last7Days.compactMap { $0.sleepDuration }
        updated.avgSleepLast7Days = sleepDurValues.isEmpty ? nil : sleepDurValues.reduce(0, +) / Double(sleepDurValues.count)
        
        // Stress average
        let stressValues = last7Days.compactMap { $0.averageStress }
        updated.avgStressLast7Days = stressValues.isEmpty ? nil : stressValues.reduce(0, +) / Double(stressValues.count)
        
        // Sleep debt (cumulative)
        let sleepDebtValues = last7Days.compactMap { $0.sleepDebt }
        updated.sleepDebtLast7Days = sleepDebtValues.isEmpty ? nil : sleepDebtValues.reduce(0, +)
        
        return updated
    }
    
    // MARK: - Trends
    
    private func addTrends(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics
        
        // Last 3 days (for trend calculation)
        let last3Days = Array(historical.suffix(4).dropLast())
        
        guard last3Days.count >= 2 else { return updated }
        
        // Recovery trend (linear slope)
        let recoveryValues = last3Days.compactMap { $0.recovery }
        if recoveryValues.count >= 2 {
            updated.recoveryTrend3Day = calculateSlope(recoveryValues)
        }
        
        // Sleep trend
        let sleepValues = last3Days.compactMap { $0.sleepDuration }
        if sleepValues.count >= 2 {
            updated.sleepTrend3Day = calculateSlope(sleepValues)
        }
        
        // HRV trend
        let hrvValues = last3Days.compactMap { $0.hrvAverage }
        if hrvValues.count >= 2 {
            updated.hrvTrend3Day = calculateSlope(hrvValues)
        }
        
        return updated
    }
    
    // MARK: - Deviations
    
    private func addDeviations(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics
        
        let last7Days = historical.suffix(8).dropLast()
        
        // HRV deviation
        if let currentHRV = metrics.hrvAverage {
            let hrvValues = last7Days.compactMap { $0.hrvAverage }
            if !hrvValues.isEmpty {
                let avg = hrvValues.reduce(0, +) / Double(hrvValues.count)
                updated.hrvDeviation = ((currentHRV - avg) / avg) * 100 // percentage
            }
        }
        
        // RHR deviation
        if let currentRHR = metrics.restingHeartRate {
            let rhrValues = last7Days.compactMap { $0.restingHeartRate }
            if !rhrValues.isEmpty {
                let avg = rhrValues.reduce(0, +) / Double(rhrValues.count)
                updated.rhrDeviation = currentRHR - avg // absolute difference
            }
        }
        
        return updated
    }
    
    // MARK: - Strain Features
    
    private func addStrainFeatures(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics
        
        // Days since rest day (strain < 5.0)
        var daysSinceRest = 0
        for dayMetrics in historical.reversed() {
            if dayMetrics.strain < 5.0 {
                break
            }
            daysSinceRest += 1
        }
        updated.daysSinceRestDay = daysSinceRest
        
        // 7-day strain average
        let last7Days = historical.suffix(8).dropLast()
        let strainValues = last7Days.map { $0.strain }
        updated.avgStrainLast7Days = strainValues.isEmpty ? nil : strainValues.reduce(0, +) / Double(strainValues.count)
        
        // 3-day strain average
        let last3Days = Array(historical.suffix(4).dropLast())
        let strain3Day = last3Days.map { $0.strain }
        updated.avgStrainLast3Days = strain3Day.isEmpty ? nil : strain3Day.reduce(0, +) / Double(strain3Day.count)
        
        // Cumulative strain
        updated.cumulativeStrainLast7Days = strainValues.reduce(0, +)
        
        // Is rest day
        updated.isRestDay = metrics.todayStrain < 5.0
        
        return updated
    }
    
    // MARK: - Circadian Features
    
    private func addCircadianFeatures(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics
        
        // Calculate average bedtime
        let last7Days = historical.suffix(8).dropLast()
        let bedtimes = last7Days.compactMap { $0.sleepStart }
        
        if !bedtimes.isEmpty, let currentBedtime = metrics.bedtime {
            let avgBedtime = calculateAverageBedtime(bedtimes)
            let variance = abs(currentBedtime.timeIntervalSince(avgBedtime)) / 3600 // hours
            updated.bedtimeConsistency = variance
        }
        
        // Calculate average wake time
        let wakeTimes = last7Days.compactMap { $0.sleepEnd }
        
        if !wakeTimes.isEmpty, let currentWakeTime = metrics.wakeTime {
            let avgWakeTime = calculateAverageWakeTime(wakeTimes)
            let variance = abs(currentWakeTime.timeIntervalSince(avgWakeTime)) / 3600 // hours
            updated.wakeTimeConsistency = variance
        }
        
        return updated
    }
    
    // MARK: - Nutrition Features
    
    private func addNutritionFeatures(to metrics: MLDailyMetrics, date: Date) async -> MLDailyMetrics {
        var updated = metrics

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        do {
            async let caloriesTask = nutritionQuery.fetchCaloriesConsumed(from: startOfDay, to: endOfDay)
            async let proteinTask = nutritionQuery.fetchProtein(from: startOfDay, to: endOfDay)
            async let carbsTask = nutritionQuery.fetchCarbohydrates(from: startOfDay, to: endOfDay)
            async let fatTask = nutritionQuery.fetchFat(from: startOfDay, to: endOfDay)
            async let waterTask = nutritionQuery.fetchWaterIntake(from: startOfDay, to: endOfDay)
            async let caffeineTask = nutritionQuery.fetchCaffeine(from: startOfDay, to: endOfDay)
            async let lastCaffeineTask = nutritionQuery.fetchLastCaffeineTime(for: date)

            let (calories, protein, carbs, fat, water, caffeine, lastCaffeine) = try await (
                caloriesTask, proteinTask, carbsTask, fatTask, waterTask, caffeineTask, lastCaffeineTask
            )

            updated.caloriesConsumed = calories
            updated.protein = protein
            updated.carbohydrates = carbs
            updated.fat = fat
            updated.waterIntake = water
            updated.caffeine = caffeine

            if let consumed = calories, let burned = metrics.activeCalories {
                updated.calorieDeficit = consumed - burned
            }

            if let lastCaffeineTime = lastCaffeine {
                updated.hoursSinceLastCaffeine = Date().timeIntervalSince(lastCaffeineTime) / 3600
            }

        } catch {
            print("⚠️ Nutrition features failed for \(date.formatted(.dateTime.month().day())): \(error)")
            // Continue with nutrition fields empty
        }

        return updated
    }

    // MARK: - Derived Balance Features

    private func addDerivedBalanceFeatures(to metrics: MLDailyMetrics, historical: [SimpleDailyMetrics]) -> MLDailyMetrics {
        var updated = metrics

        let last7Days = historical.suffix(8).dropLast()

        // Z-score normalized sleep duration
        if let sleepDuration = metrics.sleepDuration {
            let history = last7Days.compactMap { $0.sleepDuration }
            updated.sleepDurationZScore = calculateZScore(current: sleepDuration, history: history)
        }

        // Z-score normalized HRV
        if let hrv = metrics.hrvAverage {
            let history = last7Days.compactMap { $0.hrvAverage }
            updated.hrvZScore = calculateZScore(current: hrv, history: history)
        }

        // Z-score normalized resting heart rate (lower is better)
        if let rhr = metrics.restingHeartRate {
            let history = last7Days.compactMap { $0.restingHeartRate }
            if let zScore = calculateZScore(current: rhr, history: history) {
                // Invert so higher score still means better recovery readiness
                updated.rhrZScore = -zScore
            }
        }

        // Recovery compared to rolling baseline
        if let todayRecovery = metrics.todayRecovery, let baseline = metrics.avgRecoveryLast7Days {
            updated.recoveryBaselineDelta = todayRecovery - baseline
        }

        // Strain vs baseline
        if let baseline = metrics.avgStrainLast7Days {
            updated.strainBalance = metrics.todayStrain - baseline
        }

        // Sleep vs strain relationship
        if let sleep = metrics.sleepDuration {
            let denominator = max(metrics.todayStrain, 1.0)
            updated.sleepToStrainRatio = sleep / denominator
        }

        if let hrv = metrics.hrvAverage {
            let denominator = max(metrics.todayStrain, 1.0)
            updated.hrvToStrainRatio = hrv / denominator
        }

        // Composite stress load score
        if let averageStress = metrics.averageStress {
            let highStressHours = metrics.timeInHighStress ?? 0
            let maxStress = metrics.maxStress ?? averageStress
            let readingCount = Double(metrics.stressReadingCount ?? 0)

            let exposureWeight = max(1.0, readingCount / 4.0)
            updated.stressLoad = averageStress * (1 + highStressHours) + maxStress * 0.25 + exposureWeight
        }

        return updated
    }


    // MARK: - Helper Methods

    private func calculateSlope(_ values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let n = Double(values.count)
        let xValues = Array(0..<values.count).map { Double($0) }
        
        let sumX = xValues.reduce(0, +)
        let sumY = values.reduce(0, +)
        let sumXY = zip(xValues, values).map(*).reduce(0, +)
        let sumXX = xValues.map { $0 * $0 }.reduce(0, +)
        
        let slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
        return slope
    }
    
    private func calculateAverageBedtime(_ times: [Date]) -> Date {
        let calendar = Calendar.current
        let seconds = times.map { time -> Double in
            let hour = Double(calendar.component(.hour, from: time))
            let minute = Double(calendar.component(.minute, from: time))
            return (hour * 3600) + (minute * 60)
        }
        
        let avgSeconds = seconds.reduce(0, +) / Double(seconds.count)
        let hours = Int(avgSeconds / 3600)
        let minutes = Int((avgSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        
        var components = DateComponents()
        components.hour = hours
        components.minute = minutes
        
        return calendar.date(from: components) ?? Date()
    }
    
    private func calculateAverageWakeTime(_ times: [Date]) -> Date {
        return calculateAverageBedtime(times) // Same logic
    }

    private func calculateZScore(current: Double, history: [Double]) -> Double? {
        guard history.count >= 2 else { return nil }

        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { partial, value in
            let delta = value - mean
            return partial + (delta * delta)
        }

        let standardDeviation = sqrt(variance / Double(history.count))
        guard standardDeviation > 0 else { return nil }

        return (current - mean) / standardDeviation
    }
}

// MARK: - Errors

enum MLFeatureError: LocalizedError {
    case missingBaseMetrics
    case insufficientHistoricalData
    
    var errorDescription: String? {
        switch self {
        case .missingBaseMetrics:
            return "Base metrics not found for the specified date"
        case .insufficientHistoricalData:
            return "Not enough historical data to calculate features"
        }
    }
}
