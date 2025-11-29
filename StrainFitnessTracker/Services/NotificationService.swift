//
//  NotificationService.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    // MARK: - Notification Identifiers
    
    enum NotificationIdentifier: String {
        case morningRecovery = "morning_recovery"
        case highStrain = "high_strain"
        case lowRecovery = "low_recovery"
        case workoutReminder = "workout_reminder"
        case sleepReminder = "sleep_reminder"
        case workoutCompleted = "workout_completed"
        case sleepScoreReady = "sleep_score_ready"
    }
    
    private init() {}
    
    // MARK: - Authorization
    
    func requestAuthorization() async throws {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        isAuthorized = try await notificationCenter.requestAuthorization(options: options)
    }
    
    func checkAuthorizationStatus() async {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }
    
    // MARK: - Schedule Notifications
    
    /// Schedule morning recovery notification
    func scheduleMorningRecoveryNotification(recovery: Double, time: DateComponents = DateComponents(hour: 7, minute: 0)) {
        let content = UNMutableNotificationContent()
        content.title = "Your Recovery Score"
        content.body = recoveryMessage(for: recovery)
        content.sound = .default
        content.badge = 1
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.morningRecovery.rawValue,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling morning recovery notification: \(error)")
            }
        }
    }
    
    /// Notify when strain is high
    func notifyHighStrain(strain: Double) {
        guard strain >= 15.0 else { return } // High strain threshold
        
        let content = UNMutableNotificationContent()
        content.title = "High Strain Alert"
        content.body = "Your strain is \(strain.formatted(.number.precision(.fractionLength(1)))). Consider taking it easy tomorrow."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.highStrain.rawValue,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    /// Notify when recovery is low
    func notifyLowRecovery(recovery: Double) {
        guard recovery <= 33 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Low Recovery"
        content.body = "Your recovery is \(Int(recovery))%. Focus on rest and recovery today."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.lowRecovery.rawValue,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }
    
    /// Schedule sleep reminder
    func scheduleSleepReminder(time: DateComponents = DateComponents(hour: 22, minute: 0)) {
        let content = UNMutableNotificationContent()
        content.title = "Time for Bed"
        content.body = "Get quality sleep to improve your recovery score."
        content.sound = .default
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.sleepReminder.rawValue,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request)
    }

    /// Notify when a workout is completed with its strain
    func notifyWorkoutCompletion(workout: WorkoutSummary, totalStrain: Double) {
        let content = UNMutableNotificationContent()
        content.title = "\(workout.workoutType.emoji) \(workout.workoutTypeName) Logged"
        content.body = "Strain: \(workout.strainFormatted) · Daily total: \(totalStrain.formatted(.number.precision(.fractionLength(1))))"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.workoutCompleted.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
    }

    /// Notify when a new sleep score is available
    func notifySleepScore(score: Double, durationHours: Double?) {
        let roundedScore = Int(score.rounded())
        let durationText: String
        if let durationHours = durationHours {
            durationText = String(format: " · %.1fh slept", durationHours)
        } else {
            durationText = ""
        }

        let content = UNMutableNotificationContent()
        content.title = "Sleep score ready"
        content.body = "Score: \(roundedScore)\(durationText)"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.sleepScoreReady.rawValue,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
    }
    
    // MARK: - Cancel Notifications
    
    func cancelNotification(_ identifier: NotificationIdentifier) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier.rawValue])
    }
    
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }
    
    // MARK: - Helper Methods
    
    private func recoveryMessage(for recovery: Double) -> String {
        switch recovery {
        case 67...100:
            return "🟢 \(Int(recovery))% - You're ready to push hard today!"
        case 34...66:
            return "🟡 \(Int(recovery))% - Moderate training recommended."
        case 0...33:
            return "🔴 \(Int(recovery))% - Focus on recovery today."
        default:
            return "Recovery data unavailable."
        }
    }
}
