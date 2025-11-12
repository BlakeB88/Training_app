//
//  MLTrainingScheduler.swift
//  StrainFitnessTracker
//
//  Automatically trains model daily in the background
//

import Foundation
import BackgroundTasks
import UIKit

class MLTrainingScheduler {
    
    static let shared = MLTrainingScheduler()
    
    private let trainer = OnDeviceMLTrainer.shared
    private let taskIdentifier = "com.straintracker.ml.training"
    
    private init() {}
    
    // MARK: - Background Task Registration
    
    func registerBackgroundTasks() {
        #if os(iOS)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleMLTrainingTask(task: task as! BGProcessingTask)
        }
        
        print("✅ ML training background task registered")
        #endif
    }
    
    // MARK: - Schedule Training
    
    func scheduleNextTraining() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        
        // Run at night when device is charging
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = true
        
        // Schedule for 3 AM tomorrow
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 3
        components.minute = 0
        
        if let scheduledTime = calendar.date(from: components) {
            request.earliestBeginDate = scheduledTime
            
            do {
                try BGTaskScheduler.shared.submit(request)
                print("✅ Next ML training scheduled for: \(scheduledTime.formatted())")
            } catch {
                print("❌ Failed to schedule ML training: \(error)")
            }
        }
        #endif
    }
    
    // MARK: - Manual Training Trigger
    
    @MainActor
    func trainNow() async {
        print("🚀 Manual training triggered")
        
        do {
            try await trainer.trainModel(force: true)
            
            // Schedule next automatic training
            scheduleNextTraining()
            
            // Send notification
            sendTrainingCompleteNotification()
            
        } catch {
            print("❌ Training failed: \(error)")
            sendTrainingFailedNotification(error: error)
        }
    }
    
    // MARK: - Background Task Handler
    
    #if os(iOS)
    private func handleMLTrainingTask(task: BGProcessingTask) {
        print("🌙 Background ML training started")
        
        // Schedule next run
        scheduleNextTraining()
        
        // Set expiration handler
        task.expirationHandler = {
            print("⏰ Background task expired")
            task.setTaskCompleted(success: false)
        }
        
        // Perform training
        Task { @MainActor in
            do {
                try await trainer.trainModel(force: false)
                task.setTaskCompleted(success: true)
                print("✅ Background training completed")
                
                sendTrainingCompleteNotification()
                
            } catch {
                print("❌ Background training failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    #endif
    
    // MARK: - Training on App Launch
    
    @MainActor
    func trainOnLaunchIfNeeded() async {
        // Check if we should train
        guard await shouldTrainOnLaunch() else {
            print("ℹ️  Skipping launch training")
            return
        }
        
        print("🚀 Training on app launch")
        
        Task {
            do {
                try await trainer.trainModel(force: false)
                scheduleNextTraining()
            } catch {
                print("❌ Launch training failed: \(error)")
            }
        }
    }
    
    private func shouldTrainOnLaunch() async -> Bool {
        // Only train if:
        // 1. Never trained before, OR
        // 2. Last training was yesterday or earlier
        
        guard let lastTraining = trainer.lastTrainingDate else {
            return true // Never trained
        }
        
        let calendar = Calendar.current
        return !calendar.isDateInToday(lastTraining)
    }
    
    // MARK: - Notifications
    
    private func sendTrainingCompleteNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Recovery Model Updated"
        content.body = "Your prediction model learned from \(trainer.trainingDataCount) days of data"
        content.sound = .default
        
        if let accuracy = trainer.modelAccuracy {
            content.body += " (Accuracy: \(String(format: "%.0f%%", accuracy * 100)))"
        }
        
        let request = UNNotificationRequest(
            identifier: "ml_training_complete",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func sendTrainingFailedNotification(error: Error) {
        let content = UNMutableNotificationContent()
        content.title = "Model Training Issue"
        content.body = "Unable to update prediction model. Check app for details."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "ml_training_failed",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}

// MARK: - App Lifecycle Integration

extension MLTrainingScheduler {
    
    /// Call this from SceneDelegate or App when entering background
    func handleAppBackground() {
        scheduleNextTraining()
    }
    
    /// Call this from SceneDelegate or App when becoming active
    @MainActor
    func handleAppForeground() async {
        await trainOnLaunchIfNeeded()
    }
}
