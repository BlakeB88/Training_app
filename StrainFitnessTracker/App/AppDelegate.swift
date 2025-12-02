//
//  AppDelegate.swift
//  StrainFitnessTracker
//
//  Registers background tasks so the recovery model can train daily.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        MLTrainingScheduler.shared.registerBackgroundTasks()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            await MLTrainingScheduler.shared.handleAppForeground()
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        MLTrainingScheduler.shared.handleAppBackground()
    }
}

