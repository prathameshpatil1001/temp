//
//  Extensions.swift
//  lms_project
//

import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// Formats date as "Dec 4, 2024"
    var shortFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    /// Formats date as "Dec 4, 2024 at 10:30 AM"
    var fullFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Formats time as "10:30 AM"
    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
    
    /// Relative time string: "2 hours ago", "Yesterday", etc.
    var relativeFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// Days remaining until this date (negative if past)
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
}

// MARK: - Number Extensions

extension Double {
    /// Formats as currency: "₹25,00,000"
    var currencyFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        formatter.locale = Locale(identifier: "en_IN")
        return formatter.string(from: NSNumber(value: self)) ?? "₹0"
    }
    
    /// Formats as percentage: "29%"
    var percentFormatted: String {
        return "\(Int(self * 100))%"
    }
    
    /// Formats as compact number: "25L", "5Cr"
    var compactFormatted: String {
        if self >= 10_000_000 {
            return String(format: "%.1fCr", self / 10_000_000)
        } else if self >= 100_000 {
            return String(format: "%.1fL", self / 100_000)
        } else if self >= 1_000 {
            return String(format: "%.0fK", self / 1_000)
        }
        return String(format: "%.0f", self)
    }
}

extension Int {
    /// Formats as currency
    var currencyFormatted: String {
        Double(self).currencyFormatted
    }
    
    /// Formats as compact number
    var compactFormatted: String {
        Double(self).compactFormatted
    }
}

// MARK: - View Extensions

extension View {
    /// Applies card styling
    func cardStyle(colorScheme: ColorScheme) -> some View {
        self
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1.0)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.04), radius: 6, x: 0, y: 2)
    }
    
    /// Conditional modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
