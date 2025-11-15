//
//  MLPredictionView.swift
//  StrainFitnessTracker
//
//  UI for showing ML predictions and model status
//

import SwiftUI

// MARK: - Recovery Prediction Card

struct RecoveryPredictionCard: View {
    @StateObject private var trainer = OnDeviceMLTrainer.shared
    @State private var prediction: RecoveryPrediction?
    @State private var isLoading = false
    @State private var error: String?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text("Tomorrow's Recovery")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let prediction = prediction {
                // Prediction display
                predictionContent(prediction)
            } else if let error = error {
                // Error state
                errorContent(error)
            } else {
                // Initial state
                Button("Predict Tomorrow's Recovery") {
                    loadPrediction()
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Model info
            modelInfoFooter()
            // DEBUG: Force Training Button
            Button("Force Train Model Now") {
                Task {
                    do {
                        print("🚀 DEBUG: Forcing model training...")
                        try await OnDeviceMLTrainer.shared.trainModel(force: true)
                        print("✅ DEBUG: Training complete. Trying prediction...")
                        loadPrediction()
                    } catch {
                        print("❌ DEBUG: Training error:", error.localizedDescription)
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onAppear {
            if trainer.hasTrainedModel() {
                loadPrediction()
            }
        }
    }
    
    @ViewBuilder
    private func predictionContent(_ prediction: RecoveryPrediction) -> some View {
        VStack(spacing: 12) {
            // Big recovery number
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.0f", prediction.predictedRecovery))
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(recoveryColor(prediction.predictedRecovery))
                
                Text("%")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
            
            // Recovery level
            Text(prediction.recoveryLevel)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Divider()
            
            // Recommendation
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                
                Text(prediction.recommendation)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            // Confidence
            HStack {
                Text("Confidence:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: prediction.confidence)
                    .tint(.green)
                
                Text("\(Int(prediction.confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private func errorContent(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                loadPrediction()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    @ViewBuilder
    private func modelInfoFooter() -> some View {
        HStack {
            Image(systemName: "cpu")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("Model v\(trainer.modelVersion)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let accuracy = trainer.modelAccuracy {
                Text("•")
                    .foregroundColor(.secondary)
                
                Text("\(Int(accuracy * 100))% accurate")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let lastTraining = trainer.lastTrainingDate {
                Text("Updated \(lastTraining, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func loadPrediction() {
        isLoading = true
        error = nil
        
        Task {
            do {
                prediction = try await trainer.predictTomorrowRecovery()
                isLoading = false
            } catch {
                self.error = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func recoveryColor(_ value: Double) -> Color {
        switch value {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - ML Training Status View

struct MLTrainingStatusView: View {
    @StateObject private var trainer = OnDeviceMLTrainer.shared
    private let scheduler = MLTrainingScheduler.shared
    @State private var showingTrainingSheet = false
    
    var body: some View {
        List {
            Section("Model Status") {
                HStack {
                    Label("Model Version", systemImage: "cpu")
                    Spacer()
                    Text("v\(trainer.modelVersion)")
                        .foregroundColor(.secondary)
                }
                
                if let lastTraining = trainer.lastTrainingDate {
                    HStack {
                        Label("Last Trained", systemImage: "clock")
                        Spacer()
                        Text(lastTraining, style: .relative)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Label("Last Trained", systemImage: "clock")
                        Spacer()
                        Text("Never")
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Label("Training Data", systemImage: "chart.bar")
                    Spacer()
                    Text("\(trainer.trainingDataCount) days")
                        .foregroundColor(.secondary)
                }
                
                if let accuracy = trainer.modelAccuracy {
                    HStack {
                        Label("Accuracy", systemImage: "target")
                        Spacer()
                        Text("\(Int(accuracy * 100))%")
                            .foregroundColor(accuracyColor(accuracy))
                            .fontWeight(.medium)
                    }
                }
            }
            
            Section("Actions") {
                Button(action: {
                    showingTrainingSheet = true
                }) {
                    if trainer.isTraining {
                        HStack {
                            ProgressView()
                            Text("Training...")
                        }
                    } else {
                        Label("Train Model Now", systemImage: "brain")
                    }
                }
                .disabled(trainer.isTraining)
                
                if trainer.hasTrainedModel() {
                    NavigationLink {
                        PredictionDetailView()
                    } label: {
                        Label("View Prediction", systemImage: "crystal.ball")
                    }
                }
            }
            
            Section("Info") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About On-Device Learning")
                        .font(.headline)
                    
                    Text("Your recovery model trains automatically each night using your personal health data. The more days you track, the more accurate predictions become.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("ML Model")
        .sheet(isPresented: $showingTrainingSheet) {
            TrainingProgressSheet()
        }
    }
    
    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 0.9...1.0: return .green
        case 0.75..<0.9: return .blue
        case 0.6..<0.75: return .orange
        default: return .red
        }
    }
}

// MARK: - Training Progress Sheet

struct TrainingProgressSheet: View {
    @StateObject private var trainer = OnDeviceMLTrainer.shared
    @Environment(\.dismiss) private var dismiss
    @State private var trainingStarted = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // Progress animation
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: trainer.trainingProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut, value: trainer.trainingProgress)
                    
                    Image(systemName: "brain")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
                
                VStack(spacing: 8) {
                    Text(trainingStatusText())
                        .font(.title3)
                        .fontWeight(.medium)
                    
                    Text("\(Int(trainer.trainingProgress * 100))% Complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if trainer.trainingDataCount > 0 {
                    Text("Training on \(trainer.trainingDataCount) days of data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !trainer.isTraining && trainingStarted {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Training Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !trainer.isTraining && !trainingStarted {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                startTraining()
            }
        }
    }
    
    private func startTraining() {
        trainingStarted = true
        Task {
            await MLTrainingScheduler.shared.trainNow()
        }
    }
    
    private func trainingStatusText() -> String {
        switch trainer.trainingProgress {
        case 0..<0.2: return "Collecting data..."
        case 0.2..<0.4: return "Preparing features..."
        case 0.4..<0.8: return "Training model..."
        case 0.8..<1.0: return "Evaluating..."
        default: return "Complete!"
        }
    }
}

// MARK: - Prediction Detail View

struct PredictionDetailView: View {
    @StateObject private var trainer = OnDeviceMLTrainer.shared
    @State private var prediction: RecoveryPrediction?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading prediction...")
            } else if let prediction = prediction {
                ScrollView {
                    VStack(spacing: 20) {
                        // Main prediction
                        RecoveryPredictionCard()
                            .padding()
                        
                        // Feature importance
                        featureImportanceSection(prediction)
                    }
                }
            } else {
                Text("Unable to load prediction")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Recovery Prediction")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPrediction()
        }
    }
    
    @ViewBuilder
    private func featureImportanceSection(_ prediction: RecoveryPrediction) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Factors")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 8) {
                featureRow("Sleep Duration", value: prediction.inputFeatures.sleepDuration, unit: "h", optimal: 8.0)
                featureRow("HRV", value: prediction.inputFeatures.hrvAverage, unit: "ms", optimal: 50.0)
                featureRow("Resting HR", value: prediction.inputFeatures.restingHeartRate, unit: "bpm", optimal: 60.0, inverse: true)
                featureRow("Strain", value: prediction.inputFeatures.todayStrain, unit: "", optimal: 10.0, inverse: true)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func featureRow(_ label: String, value: Double?, unit: String, optimal: Double, inverse: Bool = false) -> some View {
        if let value = value {
            HStack {
                Text(label)
                    .font(.subheadline)
                
                Spacer()
                
                Text("\(String(format: "%.1f", value)) \(unit)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(featureColor(value, optimal: optimal, inverse: inverse))
            }
        }
    }
    
    private func featureColor(_ value: Double, optimal: Double, inverse: Bool) -> Color {
        let ratio = value / optimal
        
        if inverse {
            // Lower is better (like strain, RHR)
            switch ratio {
            case 0..<0.9: return .green
            case 0.9..<1.1: return .blue
            case 1.1..<1.3: return .orange
            default: return .red
            }
        } else {
            // Higher is better (like sleep, HRV)
            switch ratio {
            case 1.1...: return .green
            case 0.9..<1.1: return .blue
            case 0.7..<0.9: return .orange
            default: return .red
            }
        }
    }
    
    private func loadPrediction() {
        Task {
            do {
                prediction = try await trainer.predictTomorrowRecovery()
                isLoading = false
            } catch {
                print("❌ Failed to load prediction: \(error)")
                isLoading = false
            }
        }
    }
}

// MARK: - Preview

struct MLPredictionView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RecoveryPredictionCard()
                .padding()
        }
    }
}

struct MLPredictionView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                RecoveryPredictionCard()
                    .padding()
            }
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

