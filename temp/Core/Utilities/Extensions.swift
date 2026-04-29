// Utils/Extensions.swift
// LoanOS — Borrower App
// SwiftUI and Foundation extensions used throughout the app.

import SwiftUI

// ═══════════════════════════════════════════════════════════════
// MARK: - View Extension
// ═══════════════════════════════════════════════════════════════

extension View {
    /// Slide-in + fade-in animation helper used on screen-appear.
    func slide(_ appeared: Bool, delay: Double = 0) -> some View {
        self.offset(y: appeared ? 0 : 20).opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5).delay(delay), value: appeared)
    }
}

// ═══════════════════════════════════════════════════════════════
// MARK: - Color Extension
// ═══════════════════════════════════════════════════════════════

extension Color {
    /// Initialises a `Color` from a CSS-style hex string (e.g. "#1A56E8").
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4&0xF)*17,(int&0xF)*17)
        case 6:  (a,r,g,b) = (255,int>>16,int>>8&0xFF,int&0xFF)
        case 8:  (a,r,g,b) = (int>>24,int>>16&0xFF,int>>8&0xFF,int&0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255,
                  blue: Double(b)/255, opacity: Double(a)/255)
    }
}
