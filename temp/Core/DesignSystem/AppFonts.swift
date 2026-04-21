// Core/DesignSystem/AppFonts.swift
// LoanOS Borrower App
// Central font helpers for consistent typography across features.

import SwiftUI

enum AppFonts {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
