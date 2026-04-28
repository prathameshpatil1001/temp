//
//  CardView.swift
//  lms_project
//

import SwiftUI

struct CardView<Content: View>: View {
    let content: Content
    
    @Environment(\.colorScheme) private var colorScheme
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(Theme.Spacing.md)
            .cardStyle(colorScheme: colorScheme)
    }
}

// MARK: - KPI Card

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Group {
            if let action = action {
                Button(action: action) {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
    }
    
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Coloured accent bar at top
            LinearGradient(
                colors: [color, color.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 5)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Icon + trend badge row
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(color)
                    }

                    Spacer()

                    if let subtitle = subtitle {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(subtitle)
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.top, Theme.Spacing.md)

                Spacer()

                // Value + title
                VStack(alignment: .leading, spacing: 3) {
                    Text(value)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, Theme.Spacing.md)
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 165)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(color.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(colorScheme == .dark ? 0.0 : 0.10), radius: 8, x: 0, y: 4)
    }
}
