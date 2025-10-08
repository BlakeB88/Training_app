//
//  Date+Extensions.swift
//  StrainFitnessTracker
//
//  Created by Blake Burnley on 10/7/25.
//

import Foundation

extension Date {
    
    // MARK: - Start/End of Day
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    // MARK: - Start/End of Week
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var endOfWeek: Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekOfYear = 1
        components.second = -1
        return calendar.date(byAdding: components, to: startOfWeek) ?? self
    }
    
    // MARK: - Date Arithmetic
    func adding(days: Int) -> Date {
        return Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func subtracting(days: Int) -> Date {
        return adding(days: -days)
    }
    
    func adding(hours: Int) -> Date {
        return Calendar.current.date(byAdding: .hour, value: hours, to: self) ?? self
    }
    
    // MARK: - Date Comparisons
    func isSameDay(as date: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isToday() -> Bool {
        return isSameDay(as: Date())
    }
    
    func isYesterday() -> Bool {
        return isSameDay(as: Date().subtracting(days: 1))
    }
    
    func daysAgo() -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: Date().startOfDay)
        return components.day ?? 0
    }
    
    // MARK: - Date Range
    func dateRange(to endDate: Date) -> [Date] {
        var dates: [Date] = []
        var currentDate = self.startOfDay
        let end = endDate.startOfDay
        
        while currentDate <= end {
            dates.append(currentDate)
            currentDate = currentDate.adding(days: 1)
        }
        
        return dates
    }
    
    // MARK: - Formatting
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formattedRelative() -> String {
        if isToday() {
            return "Today"
        } else if isYesterday() {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: self)
        }
    }
    
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    func formattedDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }
    
    func formattedShortDayOfWeek() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
}
