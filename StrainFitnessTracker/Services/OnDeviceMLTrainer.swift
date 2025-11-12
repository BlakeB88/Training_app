//
//  OnDeviceMLTrainer.swift
//  StrainFitnessTracker
//
//  On-device ML training that updates daily as you collect more data
//

import Foundation
import CreateML
import CoreML

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
    
    private func prepareMLDataTable(from metrics: [MLDailyMetrics]) throws -> MLDataTable {
        // Convert to dictionary format for CreateML
        var rows: [[String: MLDataValueConvertible]] = []
        
        for metric in metrics {
            var row: [String: MLDataValueConvertible] = [:]
            
            // Target variable
            row["tomorrow_recovery"] = metric.tomorrowRecovery ?? 0.0
            
            // Sleep features
            row["sleep_duration"] = metric.sleepDuration ?? 0.0
            row["sleep_efficiency"] = metric.sleepEfficiency ?? 0.0
            row["restorative_sleep_pct"] = metric.restorativeSleepPercentage ?? 0.0
            row["sleep_debt"] = metric.sleepDebt ?? 0.0
            row["sleep_consistency"] = metric.sleepConsistency ?? 0.0
            row["avg_sleep_7d"] = metric.avgSleepLast7Days ?? metric.sleepDuration ?? 8.0
            
            // Physiological features
            row["hrv"] = metric.hrvAverage ?? 0.0
            row["hrv_deviation"] = metric.hrvDeviation ?? 0.0
            row["rhr"] = metric.restingHeartRate ?? 60.0
            row["rhr_deviation"] = metric.rhrDeviation ?? 0.0
            row["avg_hrv_7d"] = metric.avgHRVLast7Days ?? metric.hrvAverage ?? 0.0
            row["avg_rhr_7d"] = metric.avgRHRLast7Days ?? metric.restingHeartRate ?? 60.0
            
            // Strain features
            row["today_strain"] = metric.todayStrain
            row["avg_strain_7d"] = metric.avgStrainLast7Days ?? metric.todayStrain
            row["avg_strain_3d"] = metric.avgStrainLast3Days ?? metric.todayStrain
            row["days_since_rest"] = Double(metric.daysSinceRestDay ?? 0)
            
            // Stress features
            row["avg_stress"] = metric.averageStress ?? 0.0
            row["max_stress"] = metric.maxStress ?? 0.0
            row["avg_stress_7d"] = metric.avgStressLast7Days ?? metric.averageStress ?? 0.0
            
            // Rolling averages
            row["avg_recovery_7d"] = metric.avgRecoveryLast7Days ?? metric.todayRecovery ?? 70.0
            row["avg_sleep_eff_7d"] = metric.avgSleepEfficiencyLast7Days ?? metric.sleepEfficiency ?? 80.0
            
            // Trends (with fallback to 0 if nil)
            row["recovery_trend_3d"] = metric.recoveryTrend3Day ?? 0.0
            row["sleep_trend_3d"] = metric.sleepTrend3Day ?? 0.0
            row["hrv_trend_3d"] = metric.hrvTrend3Day ?? 0.0
            
            // Environmental
            row["day_of_week"] = Double(metric.dayOfWeek)
            row["is_weekend"] = metric.isWeekend ? 1.0 : 0.0
            row["is_rest_day"] = metric.isRestDay ? 1.0 : 0.0
            
            rows.append(row)
        }
        
        return try MLDataTable(dictionary: Dictionary(uniqueKeysWithValues: rows[0].keys.map { key in
            (key, rows.map { $0[key]! })
        }))
    }
    
    private func trainCreateMLModel(data: MLDataTable) async throws -> MLRegressor {
        print("  🎯 Training boosted tree regressor...")
        
        // Split data: 80% train, 20% validation
        let (trainingData, validationData) = data.randomSplit(by: 0.8)
        
        // Train a Boosted Tree Regressor (works well for tabular data)
        let regressor = try MLBoostedTreeRegressor(
            trainingData: trainingData,
            targetColumn: "tomorrow_recovery",
            featureColumns: nil, // Use all columns except target
            maxIterations: 100,
            validationData: validationData
        )
        
        // Get training metrics
        let trainingError = regressor.trainingMetrics.rootMeanSquaredError
        let validationError = regressor.validationMetrics.rootMeanSquaredError
        
        print("  📊 Training RMSE: \(String(format: "%.2f", trainingError))")
        print("  📊 Validation RMSE: \(String(format: "%.2f", validationError))")
        
        return regressor
    }
    
    // MARK: - Model Evaluation
    
    private func evaluateModel(_ model: MLRegressor, on data: [MLDailyMetrics]) -> Double {
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
    
    private func makePrediction(model: MLRegressor, input: MLDailyMetrics) throws -> Double {
        let inputDict: [String: Double] = [
            "sleep_duration": input.sleepDuration ?? 8.0,
            "sleep_efficiency": input.sleepEfficiency ?? 80.0,
            "restorative_sleep_pct": input.restorativeSleepPercentage ?? 30.0,
            "sleep_debt": input.sleepDebt ?? 0.0,
            "sleep_consistency": input.sleepConsistency ?? 80.0,
            "avg_sleep_7d": input.avgSleepLast7Days ?? 8.0,
            
            "hrv": input.hrvAverage ?? 50.0,
            "hrv_deviation": input.hrvDeviation ?? 0.0,
            "rhr": input.restingHeartRate ?? 60.0,
            "rhr_deviation": input.rhrDeviation ?? 0.0,
            "avg_hrv_7d": input.avgHRVLast7Days ?? 50.0,
            "avg_rhr_7d": input.avgRHRLast7Days ?? 60.0,
            
            "today_strain": input.todayStrain,
            "avg_strain_7d": input.avgStrainLast7Days ?? input.todayStrain,
            "avg_strain_3d": input.avgStrainLast3Days ?? input.todayStrain,
            "days_since_rest": Double(input.daysSinceRestDay ?? 0),
            
            "avg_stress": input.averageStress ?? 0.0,
            "max_stress": input.maxStress ?? 0.0,
            "avg_stress_7d": input.avgStressLast7Days ?? 0.0,
            
            "avg_recovery_7d": input.avgRecoveryLast7Days ?? 70.0,
            "avg_sleep_eff_7d": input.avgSleepEfficiencyLast7Days ?? 80.0,
            
            "recovery_trend_3d": input.recoveryTrend3Day ?? 0.0,
            "sleep_trend_3d": input.sleepTrend3Day ?? 0.0,
            "hrv_trend_3d": input.hrvTrend3Day ?? 0.0,
            
            "day_of_week": Double(input.dayOfWeek),
            "is_weekend": input.isWeekend ? 1.0 : 0.0,
            "is_rest_day": input.isRestDay ? 1.0 : 0.0
        ]
        
        let prediction = try model.prediction(from: inputDict)
        return prediction
    }
    
    // MARK: - Model Persistence
    
    private func saveModel(_ model: MLRegressor) throws {
        // Save as CoreML model
        let metadata = MLModelMetadata(
            author: "StrainFitnessTracker",
            shortDescription: "Recovery prediction model",
            version: "\(modelVersion)",
            license: "Private"
        )
        
        try model.write(to: modelURL, metadata: metadata)
        
        print("  💾 Model saved to: \(modelURL.path)")
        
        // Compile for faster loading
        let compiledURL = try MLModel.compileModel(at: modelURL)
        
        // Move compiled model to expected location
        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            try FileManager.default.removeItem(at: compiledModelURL)
        }
        try FileManager.default.moveItem(at: compiledURL, to: compiledModelURL)
        
        print("  ✅ Model compiled to: \(compiledModelURL.path)")
    }
    
    // MARK: - Prediction with Trained Model
    
    /// Load the latest trained model and make a prediction
    func predictTomorrowRecovery() async throws -> RecoveryPrediction {
        print("🔮 Making recovery prediction...")
        
        // 1. Load the model
        guard FileManager.default.fileExists(atPath: compiledModelURL.path) else {
            throw MLTrainingError.modelNotFound
        }
        
        let mlModel = try MLModel(contentsOf: compiledModelURL)
        
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
        let prediction = try mlModel.prediction(from: provider)
        
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

