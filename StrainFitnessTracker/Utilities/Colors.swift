//
//  Colors.swift
//  StrainFitnessTracker
//
//  App color scheme maintaining current branding
//

import SwiftUI

extension Color {
    // MARK: - Background Colors
    static let appBackground = Color(hex: "000000") // Pure black
    static let cardBackground = Color(hex: "1C1C1E") // Dark charcoal
    static let secondaryCardBackground = Color(hex: "2C2C2E") // Medium-dark gray
    
    // MARK: - Primary Accent Colors (From Current Branding)
    static let accentBlue = Color(hex: "007AFF") // iOS blue - main accent
    static let primaryAccent = accentBlue
    
    // MARK: - Metric Colors
    static let sleepBlue = Color(hex: "5AC8FA") // Light blue for sleep
    static let recoveryGreen = Color(hex: "32D74B") // Bright green for recovery
    static let strainBlue = Color(hex: "007AFF") // Standard blue for strain
    
    // MARK: - Status Colors
    static let positiveGreen = Color(hex: "32D74B")
    static let warningOrange = Color(hex: "FF9F0A")
    static let dangerRed = Color(hex: "FF453A")
    
    // MARK: - Trend Colors
    static let trendPositive = Color(hex: "32D74B")
    static let trendNegative = Color(hex: "FF9F0A")
    static let trendNeutral = Color(hex: "8E8E93")
    
    // MARK: - Text Colors
    static let primaryText = Color.white
    static let secondaryText = Color(hex: "8E8E93") // Light gray
    static let tertiaryText = Color(hex: "636366")
    
    // MARK: - Stress Colors
    static let stressLow = Color(hex: "32D74B")
    static let stressMedium = Color(hex: "5AC8FA")
    static let stressHigh = Color(hex: "FF9F0A")
    
    // MARK: - Recovery Zone Colors
    static let recoveryZoneGreen = Color(hex: "32D74B")
    static let recoveryZoneYellow = Color(hex: "FF9F0A")
    static let recoveryZoneRed = Color(hex: "FF453A")
    
    // MARK: - Chart Colors
    static let chartLine = Color(hex: "007AFF")
    static let chartSecondaryLine = Color(hex: "8E8E93")
    static let chartGrid = Color(hex: "3A3A3C")
    
    // MARK: - Helper
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
