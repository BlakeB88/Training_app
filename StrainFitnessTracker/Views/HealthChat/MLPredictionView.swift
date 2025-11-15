//
//  MLPredictionView.swift
//  StrainFitnessTracker
//
//  Upgraded with full WHOOP-style UI
//

import SwiftUI

struct MLPredictionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RecoveryPredictionCard()
            }
            .padding()
        }
        .navigationTitle("AI Recovery Prediction")
    }
}


// MARK: - Recovery Prediction Card (Upgraded WHOOP-style)

struct RecoveryPredictionCard: View {

    @StateObject private var trainer = OnDeviceMLTrainer.shared
    @State private var prediction: RecoveryPrediction?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {

        VStack(spacing: 20) {

            header

            if isLoading {
                loadingState
            }
            else if let p = prediction {
                predictionContent(p)
            }
            else if let error = error {
                errorState(error)
            }
            else {
                initialButton
            }

            Divider().padding(.vertical, 8)

            modelInfoFooter()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .onAppear {
            if trainer.hasTrainedModel() {
                loadPrediction()
            }
        }
    }
}


// MARK: Header

private extension RecoveryPredictionCard {

    var header: some View {
        HStack {
            Label("Tomorrow's Recovery", systemImage: "brain.head.profile")
                .font(.headline)

            Spacer()

            if isLoading {
                ProgressView().scaleEffect(0.8)
            }
        }
    }
}


// MARK: Loading State

private extension RecoveryPredictionCard {
    var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().scaleEffect(1.2)
            Text("Generating Prediction…")
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
}


// MARK: Initial Button

private extension RecoveryPredictionCard {
    var initialButton: some View {
        Button(action: loadPrediction) {
            Text("Predict Tomorrow’s Recovery")
                .padding()
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
    }
}


// MARK: Error State

private extension RecoveryPredictionCard {

    func errorState(_ error: String) -> some View {
        VStack(spacing: 10) {

            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)

            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Try Again", action: loadPrediction)
                .buttonStyle(.bordered)
        }
        .padding(.vertical, 20)
    }
}


// MARK: Prediction Content

private extension RecoveryPredictionCard {

    @ViewBuilder
    func predictionContent(_ p: RecoveryPrediction) -> some View {
        VStack(spacing: 24) {

            recoveryGauge(p)

            confidenceStrip(p)

            recommendationTile(p)

            factorChips(p)

            calibrationRow
        }
    }
}


// MARK: Recovery Gauge (WHOOP-style)

private extension RecoveryPredictionCard {

    func recoveryGauge(_ p: RecoveryPrediction) -> some View {
        VStack(spacing: 4) {

            ZStack {

                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: p.predictedRecovery / 100)
                    .stroke(
                        recoveryColor(p.predictedRecovery),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: p.predictedRecovery)

                VStack {
                    Text("\(Int(p.predictedRecovery))%")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(recoveryColor(p.predictedRecovery))

                    Text(p.recoveryLevel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 160, height: 160)
        }
    }

    func recoveryColor(_ value: Double) -> Color {
        switch value {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
}


// MARK: Confidence Strip

private extension RecoveryPredictionCard {

    func confidenceStrip(_ p: RecoveryPrediction) -> some View {
        VStack(alignment: .leading, spacing: 6) {

            Text("Confidence Interval")
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {

                    Capsule()
                        .fill(Color.gray.opacity(0.18))

                    let width = geo.size.width * p.confidence

                    Capsule()
                        .fill(Color.green.opacity(0.4))
                        .frame(width: width)
                }
            }
            .frame(height: 10)

            Text("\(Int(p.confidence * 100))% confidence")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}


// MARK: Recommendation Tile

private extension RecoveryPredictionCard {

    func recommendationTile(_ p: RecoveryPrediction) -> some View {
        HStack(alignment: .top, spacing: 10) {

            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)

            Text(p.recommendation)
                .font(.subheadline)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(10)
    }
}


// MARK: Key Factor Chips

private extension RecoveryPredictionCard {

    func factorChips(_ p: RecoveryPrediction) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            Text("Key Factors")
                .font(.headline)

            HStack {
                factorChip("Sleep", value: p.inputFeatures.sleepDuration, unit: "h")
                factorChip("HRV", value: p.inputFeatures.hrvAverage, unit: "ms")
            }

            HStack {
                factorChip("Strain", value: p.inputFeatures.todayStrain, unit: "")
                factorChip("Resting HR", value: p.inputFeatures.restingHeartRate, unit: "bpm")
            }
        }
    }

    func factorChip(_ title: String, value: Double?, unit: String) -> some View {
        VStack(spacing: 4) {

            Text(title)
                .font(.caption)

            if let value = value {
                Text("\(String(format: "%.1f", value)) \(unit)")
                    .font(.headline)
            } else {
                Text("–")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .frame(minWidth: 90)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}


// MARK: Calibration Indicator

private extension RecoveryPredictionCard {
    var calibrationRow: some View {
        HStack {
            Image(systemName: "tuningfork")
                .foregroundColor(.blue)

            Text("Model calibrated using last 7 days")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}


// MARK: Footer

private extension RecoveryPredictionCard {
    func modelInfoFooter() -> some View {
        HStack {
            Image(systemName: "cpu.fill").foregroundColor(.purple)
            Text("AI-powered Wellness Engine v1.0")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}


// MARK: Prediction Logic

private extension RecoveryPredictionCard {

    func loadPrediction() {
        Task {
            isLoading = true
            error = nil

            do {
                let pred = try await trainer.predictTomorrowRecovery()
                prediction = pred
            } catch {
                // Use the nice LocalizedError message if available
                if let mlError = error as? LocalizedError,
                   let desc = mlError.errorDescription {
                    self.error = desc
                } else {
                    self.error = error.localizedDescription
                }
            }

            isLoading = false
        }
    }
}
