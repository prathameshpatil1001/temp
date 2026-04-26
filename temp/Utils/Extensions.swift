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

