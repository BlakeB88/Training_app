//
//  TimeInterval+Extensions.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/9/25.
//

import Foundation

extension TimeInterval {
    
    // MARK: - Time Formatting
    
    /// Format as minutes (e.g., "45 min" or "1h 23min")
    var asMinutes: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes) min"
        }
    }
    
    /// Format as hours and minutes (e.g., "1:23")
    var asHoursMinutes: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        return String(format: "%d:%02d", hours, minutes)
    }
    
    /// Format as detailed duration (e.g., "1h 23m 45s")
    var asDetailedDuration: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        var components: [String] = []
        if hours > 0 {
            components.append("\(hours)h")
        }
        if minutes > 0 {
            components.append("\(minutes)m")
        }
        if seconds > 0 || components.isEmpty {
            components.append("\(seconds)s")
        }
        
        return components.joined(separator: " ")
    }
    
    /// Format for workout display (e.g., "45:32")
    var asWorkoutTime: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Convert to hours as Double
    var asHours: Double {
        return self / 3600.0
    }
    
    /// Convert to minutes as Double
    var asMinutesDouble: Double {
        return self / 60.0
    }
}

// MARK: - Distance Extensions for Double

extension Double {
    
    /// Format distance in kilometers (e.g., "5.2 km" or "450 m")
    var asKilometers: String {
        if self >= 1000 {
            return String(format: "%.1f km", self / 1000)
        } else {
            return String(format: "%.0f m", self)
        }
    }
    
    /// Format distance in miles
    var asMiles: String {
        let miles = self * 0.000621371 // meters to miles
        return String(format: "%.2f mi", miles)
    }
    
    /// Format for swimming distance (e.g., "1500m" or "1.5km")
    var asSwimmingDistance: String {
        if self >= 1000 {
            return String(format: "%.1fkm", self / 1000)
        } else {
            return String(format: "%.0fm", self)
        }
    }
}
