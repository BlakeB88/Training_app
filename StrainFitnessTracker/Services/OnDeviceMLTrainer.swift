//
//  OnDeviceMLTrainer.swift
//  StrainFitnessTracker
//
//  On-device ML training that updates daily as you collect more data
//

import Foundation
import CreateML
import CoreML
import Combine
import TabularData

@MainActor
class OnDeviceMLTrainer: ObservableObject {
    
    static let shared = OnDeviceMLTrainer()
    
    // MARK: - Published Properties
    @Published var isTraining = false
    @Published var modelAccuracy: Double?
    @Published var trainingProgress: Double = 0.0
    @Published var lastTrainingDate: Date?
    @Published var trainingDataCount: Int = 0
    @Published var modelVersion: Int = 0
    
    // MARK: - Private Properties
    private let repository = MetricsRepository()
    private let featureService = MLFeatureService.shared
    
    private let userDefaults = UserDefaults.standard
    private let lastTrainingKey = "lastMLTrainingDate"
    private let modelVersionKey = "mlModelVersion"
    private let minimumDataPoints = 14 // Need at least 2 weeks
    
    // Model file paths
    private var modelURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("RecoveryPredictor.mlmodel")
    }
    
    private var compiledModelURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("RecoveryPredictor.mlmodelc")
    }
    
    private init() {
        self.lastTrainingDate = userDefaults.object(forKey: lastTrainingKey) as? Date
        self.modelVersion = userDefaults.integer(forKey: modelVersionKey)
    }
    
    // MARK: - Main Training Function
    
    /// Train or retrain the model with all available data
    func trainModel(force: Bool = false) async throws {
        print("🤖 Starting model training...")
        
        // Check if we should train today
        guard force || shouldTrainToday() else {
            print("⏭️  Skipping training - already trained today")
            return
        }
        
        isTraining = true
        trainingProgress = 0.0
        
        defer {
            isTraining = false
        }
        
        do {
            // 1. Collect training data
            print("📊 Collecting training data...")
            trainingProgress = 0.1
            let trainingData = try await collectTrainingData()
            
            guard trainingData.count >= minimumDataPoints else {
                throw MLTrainingError.insufficientData(count: trainingData.count, required: minimumDataPoints)
            }
            
            trainingDataCount = trainingData.count
            print("✅ Collected \(trainingData.count) training samples")
            
            // 2. Prepare data for CreateML
            print("🔧 Preparing data...")
            trainingProgress = 0.3
            let mlDataTable = try prepareMLDataTable(from: trainingData)
            
            // 3. Train the model
            print("🏋️ Training model...")
            trainingProgress = 0.4
            let trainedModel = try await trainCreateMLModel(data: mlDataTable)
            
            // 4. Evaluate model
            print("📈 Evaluating model...")
            trainingProgress = 0.8
            let accuracy = evaluateModel(trainedModel, on: trainingData)
            modelAccuracy = accuracy
            
            print("✅ Model accuracy: \(String(format: "%.2f", accuracy * 100))%")
            
            // 5. Save model
            print("💾 Saving model...")
            trainingProgress = 0.9
            try saveModel(trainedModel)
            
            // 6. Update metadata
            modelVersion += 1
            lastTrainingDate = Date()
            userDefaults.set(lastTrainingDate, forKey: lastTrainingKey)
            userDefaults.set(modelVersion, forKey: modelVersionKey)
            
            trainingProgress = 1.0
            print("✅ Model v\(modelVersion) trained successfully!")
            
        } catch {
            print("❌ Training failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Data Collection
    
    private func collectTrainingData() async throws -> [MLDailyMetrics] {
        // Get all available data (up to 180 days)
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -180, to: endDate)!
        
        print("  📅 Fetching data from \(startDate.formatted(.dateTime.month().day())) to \(endDate.formatted(.dateTime.month().day()))")
        
        let mlMetrics = try await featureService.generateMLMetricsBatch(
            from: startDate,
            to: endDate
        )
        
        // Filter to only include samples with target variable (tomorrow's recovery)
        let validSamples = mlMetrics.filter { $0.tomorrowRecovery != nil && $0.hasCompleteData }
        
        print("  ✅ Valid samples: \(validSamples.count) / \(mlMetrics.count)")
        
        return validSamples
    }
    
    // MARK: - CreateML Training
    
    private func prepareMLDataTable(from metrics: [MLDailyMetrics]) throws -> DataFrame {
        // Create DataFrame columns
        var dataFrame = DataFrame()
        
        // Target variable
        dataFrame.append(column: Column(name: "tomorrow_recovery", contents: metrics.map { $0.tomorrowRecovery ?? 0.0 }))
        
        // Sleep features
        dataFrame.append(column: Column(name: "sleep_duration", contents: metrics.map { $0.sleepDuration ?? 0.0 }))
        dataFrame.append(column: Column(name: "sleep_efficiency", contents: metrics.map { $0.sleepEfficiency ?? 0.0 }))
        dataFrame.append(column: Column(name: "restorative_sleep_pct", contents: metrics.map { $0.restorativeSleepPercentage ?? 0.0 }))
        dataFrame.append(column: Column(name: "sleep_debt", contents: metrics.map { $0.sleepDebt ?? 0.0 }))
        dataFrame.append(column: Column(name: "sleep_consistency", contents: metrics.map { $0.sleepConsistency ?? 0.0 }))
        dataFrame.append(column: Column(name: "avg_sleep_7d", contents: metrics.map { $0.avgSleepLast7Days ?? $0.sleepDuration ?? 8.0 }))
        
        // Physiological features
        dataFrame.append(column: Column(name: "hrv", contents: metrics.map { $0.hrvAverage ?? 0.0 }))
        dataFrame.append(column: Column(name: "hrv_deviation", contents: metrics.map { $0.hrvDeviation ?? 0.0 }))
        dataFrame.append(column: Column(name: "rhr", contents: metrics.map { $0.restingHeartRate ?? 60.0 }))
        dataFrame.append(column: Column(name: "rhr_deviation", contents: metrics.map { $0.rhrDeviation ?? 0.0 }))
        dataFrame.append(column: Column(name: "avg_hrv_7d", contents: metrics.map { $0.avgHRVLast7Days ?? $0.hrvAverage ?? 0.0 }))
        dataFrame.append(column: Column(name: "avg_rhr_7d", contents: metrics.map { $0.avgRHRLast7Days ?? $0.restingHeartRate ?? 60.0 }))
        
        // Strain features
        dataFrame.append(column: Column(name: "today_strain", contents: metrics.map { $0.todayStrain }))
        dataFrame.append(column: Column(name: "avg_strain_7d", contents: metrics.map { $0.avgStrainLast7Days ?? $0.todayStrain }))
        dataFrame.append(column: Column(name: "avg_strain_3d", contents: metrics.map { $0.avgStrainLast3Days ?? $0.todayStrain }))
        dataFrame.append(column: Column(name: "days_since_rest", contents: metrics.map { Double($0.daysSinceRestDay ?? 0) }))
        
        // Stress features
        dataFrame.append(column: Column(name: "avg_stress", contents: metrics.map { $0.averageStress ?? 0.0 }))
        dataFrame.append(column: Column(name: "max_stress", contents: metrics.map { $0.maxStress ?? 0.0 }))
        dataFrame.append(column: Column(name: "avg_stress_7d", contents: metrics.map { $0.avgStressLast7Days ?? $0.averageStress ?? 0.0 }))
        
        // Rolling averages
        dataFrame.append(column: Column(name: "avg_recovery_7d", contents: metrics.map { $0.avgRecoveryLast7Days ?? $0.todayRecovery ?? 70.0 }))
        dataFrame.append(column: Column(name: "avg_sleep_eff_7d", contents: metrics.map { $0.avgSleepEfficiencyLast7Days ?? $0.sleepEfficiency ?? 80.0 }))
        
        // Trends
        dataFrame.append(column: Column(name: "recovery_trend_3d", contents: metrics.map { $0.recoveryTrend3Day ?? 0.0 }))
        dataFrame.append(column: Column(name: "sleep_trend_3d", contents: metrics.map { $0.sleepTrend3Day ?? 0.0 }))
        dataFrame.append(column: Column(name: "hrv_trend_3d", contents: metrics.map { $0.hrvTrend3Day ?? 0.0 }))
        
        // Environmental
        dataFrame.append(column: Column(name: "day_of_week", contents: metrics.map { Double($0.dayOfWeek) }))
        dataFrame.append(column: Column(name: "is_weekend", contents: metrics.map { $0.isWeekend ? 1.0 : 0.0 }))
        dataFrame.append(column: Column(name: "is_rest_day", contents: metrics.map { $0.isRestDay ? 1.0 : 0.0 }))

        // Derived balance & normalization features
        dataFrame.append(column: Column(name: "sleep_duration_zscore", contents: metrics.map { $0.sleepDurationZScore ?? 0.0 }))
        dataFrame.append(column: Column(name: "hrv_zscore", contents: metrics.map { $0.hrvZScore ?? 0.0 }))
        dataFrame.append(column: Column(name: "rhr_zscore", contents: metrics.map { $0.rhrZScore ?? 0.0 }))
        dataFrame.append(column: Column(name: "strain_balance", contents: metrics.map { $0.strainBalance ?? 0.0 }))
        dataFrame.append(column: Column(name: "stress_load", contents: metrics.map { $0.stressLoad ?? 0.0 }))
        dataFrame.append(column: Column(name: "recovery_baseline_delta", contents: metrics.map { $0.recoveryBaselineDelta ?? 0.0 }))
        dataFrame.append(column: Column(name: "sleep_to_strain_ratio", contents: metrics.map { $0.sleepToStrainRatio ?? 0.0 }))
        dataFrame.append(column: Column(name: "hrv_to_strain_ratio", contents: metrics.map { $0.hrvToStrainRatio ?? 0.0 }))

        return dataFrame
    }
    
    private func trainCreateMLModel(data: DataFrame) async throws -> MLBoostedTreeRegressor {
            print("  🎯 Training boosted tree regressor...")

            // MLBoostedTreeRegressor automatically uses 20% of data for validation
            let regressor = try MLBoostedTreeRegressor(
                trainingData: data,
                targetColumn: "tomorrow_recovery"
            )

            let trainingError = regressor.trainingMetrics.rootMeanSquaredError
            let validationError = regressor.validationMetrics.rootMeanSquaredError

            print("  📊 Training RMSE: \(String(format: "%.2f", trainingError))")
            print("  📊 Validation RMSE: \(String(format: "%.2f", validationError))")

            return regressor
        }
    
    // MARK: - Model Evaluation
    
    private func evaluateModel(_ model: MLBoostedTreeRegressor, on data: [MLDailyMetrics]) -> Double {
        var totalError: Double = 0.0
        var validPredictions = 0
        
        for metric in data {
            guard let actual = metric.tomorrowRecovery else { continue }
            
            // Create prediction input (simplified for evaluation)
            do {
                let predicted = try makePrediction(model: model, input: metric)
                let error = abs(predicted - actual)
                totalError += error
                validPredictions += 1
            } catch {
                // Skip failed predictions
                continue
            }
        }
        
        guard validPredictions > 0 else { return 0.0 }
        
        let meanAbsoluteError = totalError / Double(validPredictions)
        let accuracy = max(0, 1.0 - (meanAbsoluteError / 100.0)) // Convert to 0-1 scale
        
        return accuracy
    }
    
    private func makePrediction(model: MLBoostedTreeRegressor, input: MLDailyMetrics) throws -> Double {

        // 1. Build single-row DataFrame
        var inputFrame = DataFrame()

        inputFrame.append(column: Column(name: "sleep_duration", contents: [input.sleepDuration ?? 8.0]))
        inputFrame.append(column: Column(name: "sleep_efficiency", contents: [input.sleepEfficiency ?? 80.0]))
        inputFrame.append(column: Column(name: "restorative_sleep_pct", contents: [input.restorativeSleepPercentage ?? 30.0]))
        inputFrame.append(column: Column(name: "sleep_debt", contents: [input.sleepDebt ?? 0.0]))
        inputFrame.append(column: Column(name: "sleep_consistency", contents: [input.sleepConsistency ?? 80.0]))
        inputFrame.append(column: Column(name: "avg_sleep_7d", contents: [input.avgSleepLast7Days ?? 8.0]))

        inputFrame.append(column: Column(name: "hrv", contents: [input.hrvAverage ?? 50.0]))
        inputFrame.append(column: Column(name: "hrv_deviation", contents: [input.hrvDeviation ?? 0.0]))
        inputFrame.append(column: Column(name: "rhr", contents: [input.restingHeartRate ?? 60.0]))
        inputFrame.append(column: Column(name: "rhr_deviation", contents: [input.rhrDeviation ?? 0.0]))
        inputFrame.append(column: Column(name: "avg_hrv_7d", contents: [input.avgHRVLast7Days ?? 50.0]))
        inputFrame.append(column: Column(name: "avg_rhr_7d", contents: [input.avgRHRLast7Days ?? 60.0]))

        inputFrame.append(column: Column(name: "today_strain", contents: [input.todayStrain]))
        inputFrame.append(column: Column(name: "avg_strain_7d", contents: [input.avgStrainLast7Days ?? input.todayStrain]))
        inputFrame.append(column: Column(name: "avg_strain_3d", contents: [input.avgStrainLast3Days ?? input.todayStrain]))
        inputFrame.append(column: Column(name: "days_since_rest", contents: [Double(input.daysSinceRestDay ?? 0)]))

        inputFrame.append(column: Column(name: "avg_stress", contents: [input.averageStress ?? 0.0]))
        inputFrame.append(column: Column(name: "max_stress", contents: [input.maxStress ?? 0.0]))
        inputFrame.append(column: Column(name: "avg_stress_7d", contents: [input.avgStressLast7Days ?? 0.0]))

        inputFrame.append(column: Column(name: "avg_recovery_7d", contents: [input.avgRecoveryLast7Days ?? 70.0]))
        inputFrame.append(column: Column(name: "avg_sleep_eff_7d", contents: [input.avgSleepEfficiencyLast7Days ?? 80.0]))

        inputFrame.append(column: Column(name: "recovery_trend_3d", contents: [input.recoveryTrend3Day ?? 0.0]))
        inputFrame.append(column: Column(name: "sleep_trend_3d", contents: [input.sleepTrend3Day ?? 0.0]))
        inputFrame.append(column: Column(name: "hrv_trend_3d", contents: [input.hrvTrend3Day ?? 0.0]))

        inputFrame.append(column: Column(name: "day_of_week", contents: [Double(input.dayOfWeek)]))
        inputFrame.append(column: Column(name: "is_weekend", contents: [input.isWeekend ? 1.0 : 0.0]))
        inputFrame.append(column: Column(name: "is_rest_day", contents: [input.isRestDay ? 1.0 : 0.0]))

        inputFrame.append(column: Column(name: "sleep_duration_zscore", contents: [input.sleepDurationZScore ?? 0.0]))
        inputFrame.append(column: Column(name: "hrv_zscore", contents: [input.hrvZScore ?? 0.0]))
        inputFrame.append(column: Column(name: "rhr_zscore", contents: [input.rhrZScore ?? 0.0]))
        inputFrame.append(column: Column(name: "strain_balance", contents: [input.strainBalance ?? 0.0]))
        inputFrame.append(column: Column(name: "stress_load", contents: [input.stressLoad ?? 0.0]))
        inputFrame.append(column: Column(name: "recovery_baseline_delta", contents: [input.recoveryBaselineDelta ?? 0.0]))
        inputFrame.append(column: Column(name: "sleep_to_strain_ratio", contents: [input.sleepToStrainRatio ?? 0.0]))
        inputFrame.append(column: Column(name: "hrv_to_strain_ratio", contents: [input.hrvToStrainRatio ?? 0.0]))


        // ---- 1. Predict ----
        let outputColumn = try model.predictions(from: inputFrame)   // THIS RETURNS AnyColumn


        // ---- 2. Extract the single value ----
        guard outputColumn.count > 0,
                let value = outputColumn[0] as? Double else {
            throw MLTrainingError.predictionFailed
        }
        
        return value
    }


    // MARK: - Model Persistence
    
    private func saveModel(_ model: MLBoostedTreeRegressor) throws {
        let metadata = MLModelMetadata(
            author: "StrainFitnessTracker",
            shortDescription: "Recovery prediction model",
            license: "Private",
            version: "\(modelVersion)"
        )
        
        // 1. Export a temporary .mlmodel package
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("TempRecoveryPredictor.mlmodel")
        
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try FileManager.default.removeItem(at: tempURL)
        }

        try model.write(to: tempURL, metadata: metadata)
        
        print("💾 MLModel (uncompiled) exported to: \(tempURL)")

        // 2. Compile it
        let compiledURL = try MLModel.compileModel(at: tempURL)

        // 3. Move compiled model into **your Documents directory**
        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            try FileManager.default.removeItem(at: compiledModelURL)
        }
        
        try FileManager.default.copyItem(at: compiledURL, to: compiledModelURL)
        
        print("✅ Compiled MLModel saved to: \(compiledModelURL.path)")
    }
    
    // MARK: - Prediction with Trained Model
    
    /// Load the latest trained model and make a prediction
    func predictTomorrowRecovery() async throws -> RecoveryPrediction {
        print("🔮 Making recovery prediction...")
        
        // 1. Load the model
        guard FileManager.default.fileExists(atPath: compiledModelURL.path) else {
            throw MLTrainingError.modelNotFound
        }
        
        let mlModel = try await MLModel.load(contentsOf: compiledModelURL)
        
        // 2. Get today's features
        let todayFeatures = try await featureService.generateMLMetrics(for: Date())
        
        // 3. Prepare input
        let inputDict: [String: Double] = [
            "sleep_duration": todayFeatures.sleepDuration ?? 8.0,
            "sleep_efficiency": todayFeatures.sleepEfficiency ?? 80.0,
            "restorative_sleep_pct": todayFeatures.restorativeSleepPercentage ?? 30.0,
            "sleep_debt": todayFeatures.sleepDebt ?? 0.0,
            "sleep_consistency": todayFeatures.sleepConsistency ?? 80.0,
            "avg_sleep_7d": todayFeatures.avgSleepLast7Days ?? 8.0,
            
            "hrv": todayFeatures.hrvAverage ?? 50.0,
            "hrv_deviation": todayFeatures.hrvDeviation ?? 0.0,
            "rhr": todayFeatures.restingHeartRate ?? 60.0,
            "rhr_deviation": todayFeatures.rhrDeviation ?? 0.0,
            "avg_hrv_7d": todayFeatures.avgHRVLast7Days ?? 50.0,
            "avg_rhr_7d": todayFeatures.avgRHRLast7Days ?? 60.0,
            
            "today_strain": todayFeatures.todayStrain,
            "avg_strain_7d": todayFeatures.avgStrainLast7Days ?? todayFeatures.todayStrain,
            "avg_strain_3d": todayFeatures.avgStrainLast3Days ?? todayFeatures.todayStrain,
            "days_since_rest": Double(todayFeatures.daysSinceRestDay ?? 0),
            
            "avg_stress": todayFeatures.averageStress ?? 0.0,
            "max_stress": todayFeatures.maxStress ?? 0.0,
            "avg_stress_7d": todayFeatures.avgStressLast7Days ?? 0.0,
            
            "avg_recovery_7d": todayFeatures.avgRecoveryLast7Days ?? 70.0,
            "avg_sleep_eff_7d": todayFeatures.avgSleepEfficiencyLast7Days ?? 80.0,
            
            "recovery_trend_3d": todayFeatures.recoveryTrend3Day ?? 0.0,
            "sleep_trend_3d": todayFeatures.sleepTrend3Day ?? 0.0,
            "hrv_trend_3d": todayFeatures.hrvTrend3Day ?? 0.0,
            
            "day_of_week": Double(todayFeatures.dayOfWeek),
            "is_weekend": todayFeatures.isWeekend ? 1.0 : 0.0,
            "is_rest_day": todayFeatures.isRestDay ? 1.0 : 0.0
        ]
        
        // 4. Make prediction
        let provider = try MLDictionaryFeatureProvider(dictionary: inputDict)
        let prediction = try await mlModel.prediction(from: provider)
        
        guard let predictedValue = prediction.featureValue(for: "tomorrow_recovery")?.doubleValue else {
            throw MLTrainingError.predictionFailed
        }
        
        // Clamp to valid range
        let clampedPrediction = min(max(predictedValue, 0), 100)
        
        print("✅ Predicted tomorrow's recovery: \(String(format: "%.1f%%", clampedPrediction))")
        
        return RecoveryPrediction(
            predictedRecovery: clampedPrediction,
            confidence: modelAccuracy ?? 0.8,
            modelVersion: modelVersion,
            predictionDate: Date(),
            inputFeatures: todayFeatures
        )
    }
    
    // MARK: - Helper Methods
    
    private func shouldTrainToday() -> Bool {
        guard let lastTraining = lastTrainingDate else {
            return true // Never trained before
        }
        
        // Train once per day
        return !Calendar.current.isDateInToday(lastTraining)
    }
    
    func hasTrainedModel() -> Bool {
        return FileManager.default.fileExists(atPath: compiledModelURL.path)
    }
    
    func getModelInfo() -> String {
        var info = "Model Version: v\(modelVersion)\n"
        
        if let lastTraining = lastTrainingDate {
            info += "Last Trained: \(lastTraining.formatted(.dateTime.month().day().hour().minute()))\n"
        } else {
            info += "Last Trained: Never\n"
        }
        
        info += "Training Samples: \(trainingDataCount)\n"
        
        if let accuracy = modelAccuracy {
            info += "Accuracy: \(String(format: "%.1f%%", accuracy * 100))"
        } else {
            info += "Accuracy: Unknown"
        }
        
        return info
    }
}

// MARK: - Supporting Types

struct RecoveryPrediction: Codable {
    let predictedRecovery: Double
    let confidence: Double
    let modelVersion: Int
    let predictionDate: Date
    let inputFeatures: MLDailyMetrics
    
    var recoveryLevel: String {
        switch predictedRecovery {
        case 85...100: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        default: return "Poor"
        }
    }
    
    var recommendation: String {
        switch predictedRecovery {
        case 85...100:
            return "You're ready to push hard! Great day for high-intensity training."
        case 70..<85:
            return "Good recovery. Moderate to hard training recommended."
        case 50..<70:
            return "Fair recovery. Consider moderate intensity or skill work."
        default:
            return "Low recovery predicted. Rest day or active recovery recommended."
        }
    }
}

enum MLTrainingError: LocalizedError {
    case insufficientData(count: Int, required: Int)
    case modelNotFound
    case predictionFailed
    case trainingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .insufficientData(let count, let required):
            return "Need at least \(required) days of data (have \(count))"
        case .modelNotFound:
            return "No trained model found. Train model first."
        case .predictionFailed:
            return "Failed to make prediction"
        case .trainingFailed(let reason):
            return "Training failed: \(reason)"
        }
    }
}
