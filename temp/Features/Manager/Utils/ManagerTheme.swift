//
//  ManagerTheme.swift
//  lms_project
//

import SwiftUI

enum ManagerTheme {
    enum Colors {
        static func background(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.backgroundDark : Theme.Colors.background
        }

        static func surface(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.surfaceDark : Theme.Colors.surface
        }

        static func surfaceSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.surfaceSecondaryDark : Theme.Colors.surfaceSecondary
        }

        static func border(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.borderDark : Theme.Colors.border
        }

        static func primary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.primaryDark : Theme.Colors.primary
        }

        static func secondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Theme.Colors.secondaryDark : Theme.Colors.secondary
        }

        static func textPrimary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#E5EBF8") : .primary
        }

        static func textSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#AEB9CF") : .secondary
        }

        static func textTertiary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#8B97B1") : Color.secondary.opacity(0.7)
        }
    }
}
