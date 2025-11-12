//
//  NutritionQuery.swift
//  StrainFitnessTracker
//
//  Created for ML Recovery Prediction
//

import Foundation
import HealthKit

/// Handles nutrition and hydration data from HealthKit
class NutritionQuery {
    
    private let healthStore: HKHealthStore
    
    init(healthStore: HKHealthStore = HKHealthStore()) {
        self.healthStore = healthStore
    }
    
    // MARK: - Calorie Queries
    
    /// Fetch total calories consumed for a day
    func fetchCaloriesConsumed(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let calorieType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: calorieType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let calories = result?.sumQuantity()?.doubleValue(for: .kilocalorie())
                continuation.resume(returning: calories)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Macronutrient Queries
    
    /// Fetch protein intake for a day
    func fetchProtein(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) else {
            return nil
        }
        
        return try await fetchNutrient(type: proteinType, from: startDate, to: endDate)
    }
    
    /// Fetch carbohydrate intake for a day
    func fetchCarbohydrates(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let carbType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) else {
            return nil
        }
        
        return try await fetchNutrient(type: carbType, from: startDate, to: endDate)
    }
    
    /// Fetch fat intake for a day
    func fetchFat(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) else {
            return nil
        }
        
        return try await fetchNutrient(type: fatType, from: startDate, to: endDate)
    }
    
    // MARK: - Hydration Queries
    
    /// Fetch water intake for a day
    func fetchWaterIntake(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: waterType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Convert to fluid ounces
                let water = result?.sumQuantity()?.doubleValue(for: .fluidOunceUS())
                continuation.resume(returning: water)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Caffeine Queries
    
    /// Fetch caffeine intake for a day
    func fetchCaffeine(from startDate: Date, to endDate: Date) async throws -> Double? {
        guard let caffeineType = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) else {
            return nil
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: caffeineType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                // Return in milligrams
                let caffeine = result?.sumQuantity()?.doubleValue(for: .gramUnit(with: .milli))
                continuation.resume(returning: caffeine)
            }
            
            healthStore.execute(query)
        }
    }
    
    /// Fetch last caffeine intake time
    func fetchLastCaffeineTime(for date: Date) async throws -> Date? {
        guard let caffeineType = HKQuantityType.quantityType(forIdentifier: .dietaryCaffeine) else {
            return nil
        }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: caffeineType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let lastTime = (samples as? [HKQuantitySample])?.first?.startDate
                continuation.resume(returning: lastTime)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - Helper Methods
    
    private func fetchNutrient(type: HKQuantityType, from startDate: Date, to endDate: Date) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let value = result?.sumQuantity()?.doubleValue(for: .gram())
                continuation.resume(returning: value)
            }
            
            healthStore.execute(query)
        }
    }
}

// MARK: - Nutrition Data Model

struct NutritionData: Codable {
    let date: Date
    let caloriesConsumed: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?
    let waterIntake: Double?
    let caffeine: Double?
    let lastCaffeineTime: Date?
    
    var macroRatio: MacroRatio? {
        guard let p = protein, let c = carbohydrates, let f = fat else {
            return nil
        }
        let total = p + c + f
        guard total > 0 else { return nil }
        
        return MacroRatio(
            proteinPercent: (p / total) * 100,
            carbPercent: (c / total) * 100,
            fatPercent: (f / total) * 100
        )
    }
    
    var hoursSinceLastCaffeine: Double? {
        guard let lastTime = lastCaffeineTime else { return nil }
        return Date().timeIntervalSince(lastTime) / 3600
    }
}

struct MacroRatio: Codable {
    let proteinPercent: Double
    let carbPercent: Double
    let fatPercent: Double
}
