import SwiftUI

// MARK: - App Color Theme
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Borrower-aligned Brand Palette
    static let mainBlue      = Color(hex: "#1A56E8")
    static let secondaryBlue = Color(hex: "#0E3BB5")
    static let skyBlue       = Color(hex: "#5B8CFF")
    static let headerBlueTop = Color(hex: "#5C83F6")
    static let headerBlueMid = Color(hex: "#7FA1FA")
    static let headerBlueBottom = Color(hex: "#B9CCFB")
    static let homeBackground = Color(hex: "#F8F9FC")
    static let lightBlue     = Color(hex: "#EEF2FD")
    static let alertRed      = Color(hex: "#EF4444")

    // Mapped Identifiers
    static let brandBlue      = mainBlue
    static let brandBlueSoft  = lightBlue

    // Status colors - Unified!
    static let statusNew      = mainBlue
    static let statusNewBg    = lightBlue
    
    static let statusPending  = Color(hex: "#F59E0B")
    static let statusPendingBg = Color(hex: "#FFF7E8")
    
    static let statusSubmitted = mainBlue
    static let statusSubmittedBg = lightBlue
    
    static let statusRejected = alertRed
    static let statusRejectedBg = Color(hex: "#FEECEE")
    
    static let statusApproved = Color(hex: "#00C48C")
    static let statusApprovedBg = Color(hex: "#EAFBF5")
    
    static let statusDisbursed = Color(hex: "#00C48C")
    static let statusDisbursedBg = Color(hex: "#EAFBF5")

    // Neutral
    static let textPrimary    = Color(hex: "#0F1B3D")
    static let textSecondary  = Color(hex: "#6B7A99")
    static let textTertiary   = Color(hex: "#9AA6BF")
    static let surfacePrimary = Color.white
    static let surfaceSecondary = homeBackground
    static let surfaceTertiary = Color(hex: "#F1F4FB")
    static let borderLight    = Color(hex: "#E2E6F0")
    static let borderMedium   = Color(hex: "#D5DCEB")
    static let surfaceGlass   = Color.white.opacity(0.84)
}

// MARK: - Typography
struct AppFont {
    static func largeTitle()   -> Font { .system(size: 28, weight: .bold,     design: .rounded) }
    static func title()        -> Font { .system(size: 22, weight: .bold,     design: .rounded) }
    static func title2()       -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func headline()     -> Font { .system(size: 16, weight: .semibold, design: .rounded) }
    static func body()         -> Font { .system(size: 15, weight: .regular,  design: .rounded) }
    static func bodyMedium()   -> Font { .system(size: 15, weight: .medium,   design: .rounded) }
    static func subhead()      -> Font { .system(size: 13, weight: .regular,  design: .rounded) }
    static func subheadMed()   -> Font { .system(size: 13, weight: .medium,   design: .rounded) }
    static func caption()      -> Font { .system(size: 12, weight: .regular,  design: .rounded) }
    static func captionMed()   -> Font { .system(size: 12, weight: .medium,   design: .rounded) }
    static func mono()         -> Font { .system(size: 13, weight: .regular,  design: .monospaced) }
}

// MARK: - Spacing
struct AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat  = 8
    static let sm: CGFloat  = 12
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
    static let xxl: CGFloat = 32
}

// MARK: - Corner Radius
struct AppRadius {
    static let sm: CGFloat  = 10
    static let md: CGFloat  = 16
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
    static let full: CGFloat = 999
}

// MARK: - Shadow
struct AppShadow {
    static let card = Shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    static let soft = Shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    static let elevated = Shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }
    func softShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 1)
    }
    func elevatedCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
}
