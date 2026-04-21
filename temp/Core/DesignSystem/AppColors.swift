// Core/DesignSystem/AppColors.swift
// LoanOS Borrower App
// Centralized app color tokens and compatibility color aliases.

import SwiftUI

enum DS {
    static let primary       = Color(hex: "#1A56E8")
    static let primaryLight  = Color(hex: "#EEF2FD")
    static let surface       = Color(hex: "#F8F9FC")
    static let card          = Color.white
    static let textPrimary   = Color(hex: "#0F1B3D")
    static let textSecondary = Color(hex: "#6B7A99")
    static let border        = Color(hex: "#E2E6F0")
    static let success       = Color(hex: "#0ECB7A")
    static let warning       = Color(hex: "#F59E0B")
    static let purple        = Color(hex: "#7C3AED")
    static let danger        = Color(hex: "#EF4444")

    static let gradient = LinearGradient(
        colors: [Color(hex: "#1A56E8"), Color(hex: "#0E3BB5")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let successGradient = LinearGradient(
        colors: [Color(hex: "#0ECB7A"), Color(hex: "#059A5C")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    static let mainBlue = DS.primary
    static let secondaryBlue = DS.primary
    static let lightBlue = DS.primaryLight
    static let alertRed = DS.danger
    static let homeBackground = DS.surface
}
