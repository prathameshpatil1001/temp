// MARK: - DSTExtensions.swift

import SwiftUI
import Foundation

// MARK: - Color

extension Color {
    static let dstBlue    = Color(red: 0.12, green: 0.35, blue: 0.75)
    static let dstBlueBG  = Color(red: 0.88, green: 0.93, blue: 1.0)
}

// MARK: - Date

extension Date {
    var shortTime: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: self)
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies a standard card background with rounded corners
    func cardStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
