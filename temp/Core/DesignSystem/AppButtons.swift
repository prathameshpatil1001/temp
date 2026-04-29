// Core/DesignSystem/AppButtons.swift
// LoanOS Borrower App
// Reusable button styles used across auth and onboarding flows.

import SwiftUI

struct PrimaryBtn: View {
    let title: String
    var icon: String? = nil
    var style: BStyle = .blue
    var isLoading: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    enum BStyle { case blue, success, danger }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(fillColor)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.2)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .shadow(color: shadowColor.opacity(disabled ? 0 : 0.18), radius: 14, x: 0, y: 8)
            .opacity(disabled ? 0.45 : 1)
        }
        .disabled(isLoading || disabled)
        .buttonStyle(TapScale())
    }

    private var fillColor: Color {
        switch style {
        case .blue: DS.primary
        case .success: DS.success
        case .danger: DS.danger
        }
    }

    private var shadowColor: Color {
        switch style {
        case .blue: DS.primary
        case .success: DS.success
        case .danger: DS.danger
        }
    }
}

struct SecondaryBtn: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                }

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
            }
            .foregroundColor(DS.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(DS.primaryLight)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(DS.primary.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(TapScale())
    }
}

struct TapScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22), value: configuration.isPressed)
    }
}

