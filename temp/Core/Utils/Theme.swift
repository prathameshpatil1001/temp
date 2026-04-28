//
//  Theme.swift
//  lms_project
//

import SwiftUI
import UIKit

// MARK: - Theme

enum Theme {
    
    // MARK: - Colors
    
    enum Colors {
        // Specific Palette
        static let mainBlue      = Color(hex: "#002FDC")
        static let secondaryBlue = Color(hex: "#264BE3")
        static let lightBlue     = Color(hex: "#E8F2FA")
        static let alertRed      = Color(hex: "#ED1E48")
        
        static let headerBlueTop    = Color(hex: "#4E68F5")
        static let headerBlueMid    = Color(hex: "#4C72F6")
        static let headerBlueBottom = Color(hex: "#6F92FF")
        static let homeBackground   = Color(hex: "#EEF3FB")

        // Primary palette (mapped)
        // Keep light mode as-is, but force subtle-blue tokens in dark mode globally.
        static let primary      = dynamicAdaptiveColor(lightHex: "#002FDC", darkHex: "#7C92E8")
        static let secondary    = dynamicAdaptiveColor(lightHex: "#264BE3", darkHex: "#9EAFEF")
        static let primaryLight = lightBlue
        static let accent       = dynamicAdaptiveColor(lightHex: "#264BE3", darkHex: "#9EAFEF")

        // Semantic
        static let critical = alertRed
        static let warning  = Color(hex: "#FF9500")
        static let success  = Color(hex: "#34C759")
        static let neutral  = Color(hex: "#8E8E93")

        // Surfaces (light mode)
        static let background        = homeBackground
        static let surface           = Color.white
        static let surfaceSecondary  = Color.white
        static let border            = Color.black.opacity(0.06)

        // Surfaces (dark mode) - Aligned with Manager palette
        static let backgroundDark       = Color(hex: "#111622")
        static let surfaceDark          = Color(hex: "#1A2130")
        static let surfaceSecondaryDark = Color(hex: "#232C3E")
        static let borderDark           = Color(hex: "#313C52")
        
        // Brand Blues (Dark) - Aligned with Manager palette
        static let primaryDark          = Color(hex: "#7C92E8")
        static let secondaryDark        = Color(hex: "#9EAFEF")
        static let lightBlueDark        = Color(hex: "#9EAFEF")

        // Header style (Adaptive) - keep light gradient, use solid subtle-blue in dark mode
        static func headerGradient(_ colorScheme: ColorScheme) -> LinearGradient {
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [primaryDark, primaryDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [headerBlueTop, headerBlueMid, headerBlueBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        // Adaptive helpers
        static func adaptiveBackground(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? backgroundDark : background
        }

        static func adaptiveSurface(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceDark : surface
        }

        static func adaptiveSurfaceSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? surfaceSecondaryDark : surfaceSecondary
        }

        static func adaptiveBorder(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? borderDark : border
        }
        
        static func adaptivePrimary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? primaryDark : primary
        }
        
        static func adaptiveSecondary(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? secondaryDark : secondary
        }
        
        static func adaptiveSuccess(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#22C55E") : success
        }
        
        static func adaptiveCritical(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#FF4D6D") : critical
        }
        
        static func adaptiveWarning(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark ? Color(hex: "#FACC15") : warning
        }

        private static func dynamicAdaptiveColor(lightHex: String, darkHex: String) -> Color {
            Color(uiColor: UIColor { trait in
                UIColor(hex: trait.userInterfaceStyle == .dark ? darkHex : lightHex)
            })
        }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let sm: CGFloat = 8  // Increased slightly for modern look
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 100
    }
    
    // MARK: - Typography
    
    enum Typography {
        static let titleLarge = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let headline = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let caption = Font.system(size: 13, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .semibold)
        static let mono = Font.system(size: 15, weight: .medium, design: .monospaced)
    }
    
    // MARK: - Shadows
    
    enum Shadows {
        static let subtle = Color.black.opacity(0.04)
        static let card = Color.black.opacity(0.06)
        static let elevation = Color.black.opacity(0.1)
        
        static func applyCardShadow<V: View>(_ view: V, colorScheme: ColorScheme) -> some View {
            view.shadow(color: colorScheme == .dark ? Color.clear : card, radius: 10, x: 0, y: 4)
        }
    }
    
    // MARK: - Layout
    
    enum Layout {
        static let buttonHeight: CGFloat = 48
        static let rowMinHeight: CGFloat = 64
        static let badgeHeight: CGFloat = 24
        static let iconSize: CGFloat = 20
        static let avatarSize: CGFloat = 40
        static let splitLeftRatio: CGFloat = 0.4
        static let splitRightRatio: CGFloat = 0.6
        static let messageSplitLeft: CGFloat = 0.35
        static let messageSplitRight: CGFloat = 0.65
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}
