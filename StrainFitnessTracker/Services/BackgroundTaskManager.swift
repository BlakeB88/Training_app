//
//  BackgroundTaskManager.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

class BackgroundTaskManager {
    
    static let shared = BackgroundTaskManager()
    
    // Task identifiers - must match Info.plist
    private let syncTaskIdentifier = "com.straintracker.sync"
    private let refreshTaskIdentifier = "com.straintracker.refresh"
    
    private init() {}
    
    // MARK: - Registration
    
    func registerBackgroundTasks() {
        #if os(iOS)
        // Register sync task (runs less frequently, more time)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: syncTaskIdentifier,
            using: nil
        ) { task in
            self.handleSyncTask(task: task as! BGProcessingTask)
        }
        
        // Register refresh task (runs more frequently, less time)
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: refreshTaskIdentifier,
            using: nil
        ) { task in
            self.handleRefreshTask(task: task as! BGAppRefreshTask)
        }
        #else
        // macOS doesn't support BGTaskScheduler
        // Use Timer or other scheduling mechanism
        print("Background tasks not supported on macOS")
        #endif
    }
    
    // MARK: - Schedule Tasks
    
    func scheduleSync() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: syncTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600) // 4 hours
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background sync scheduled")
        } catch {
            print("Could not schedule sync: \(error)")
        }
        #else
        print("Background sync not available on macOS")
        #endif
    }
    
    func scheduleRefresh() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background refresh scheduled")
        } catch {
            print("Could not schedule refresh: \(error)")
        }
        #else
        print("Background refresh not available on macOS")
        #endif
    }
    
    // MARK: - Task Handlers
    
    #if os(iOS)
    private func handleSyncTask(task: BGProcessingTask) {
        // Schedule next sync
        scheduleSync()
        
        // Create operation
        let syncOperation = DataSyncOperation()
        
        // Handle expiration
        task.expirationHandler = {
            syncOperation.cancel()
        }
        
        // Complete task when operation finishes
        syncOperation.completionBlock = {
            task.setTaskCompleted(success: !syncOperation.isCancelled)
        }
        
        // Start operation
        OperationQueue().addOperation(syncOperation)
    }
    
    private func handleRefreshTask(task: BGAppRefreshTask) {
        // Schedule next refresh
        scheduleRefresh()
        
        // Quick refresh operation
        Task {
            await DataSyncService.shared.quickSync()
            task.setTaskCompleted(success: true)
        }
    }
    #endif
}

// MARK: - Data Sync Operation

class DataSyncOperation: Operation, @unchecked Sendable {
    
    override func main() {
        guard !isCancelled else { return }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        Task {
            await DataSyncService.shared.fullSync()
            semaphore.signal()
        }
        
        semaphore.wait()
    }
}
