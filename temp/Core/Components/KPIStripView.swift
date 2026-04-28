//
//  KPIStripView.swift
//  lms_project
//

import SwiftUI

struct KPIStripView: View {
    let cards: [KPIData]
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            ForEach(cards) { card in
                KPICard(
                    title: card.title,
                    value: card.value,
                    icon: card.icon,
                    color: card.color,
                    subtitle: card.subtitle
                )
            }
        }
    }
}

// MARK: - KPI Data

struct KPIData: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
}
