//
//  ManagerApplicationRow.swift
//  lms_project
//

import SwiftUI

struct ManagerApplicationRow: View {
    let application: LoanApplication
    let isSelected: Bool
    var useMinimalStyle: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill((useMinimalStyle ? ManagerTheme.Colors.primary(colorScheme) : application.status.color).opacity(0.10))
                    .frame(width: 50, height: 50)

                Text(application.borrower.name.prefix(1))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(useMinimalStyle ? ManagerTheme.Colors.primary(colorScheme) : application.status.color)

                if !useMinimalStyle {
                    Circle()
                        .stroke(application.status.color.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 50, height: 50)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(application.borrower.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(ManagerTheme.Colors.textPrimary(colorScheme))

                    Spacer()

                    StatusBadge(status: application.status)
                }

                HStack(spacing: 8) {
                    Text(application.loan.type.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ManagerTheme.Colors.textSecondary(colorScheme))

                    Text("•")
                        .foregroundStyle(ManagerTheme.Colors.textTertiary(colorScheme))

                    Text(application.loan.amount.currencyFormatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(ManagerTheme.Colors.primary(colorScheme))
                }

                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: application.slaStatus.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(slaColor)

                        Text(slaText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(slaColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(slaColor.opacity(0.1))
                    .clipShape(Capsule())

                    Spacer()

                    if application.riskLevel == .high {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("High Risk")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.Colors.adaptiveCritical(colorScheme))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.adaptiveCritical(colorScheme).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isSelected
            ? (colorScheme == .dark ? ManagerTheme.Colors.surfaceSecondary(colorScheme) : Theme.Colors.lightBlue)
            : Color.clear
        )
        .overlay(
            Group {
                if isSelected {
                    Rectangle()
                        .fill(ManagerTheme.Colors.primary(colorScheme))
                        .frame(width: 4)
                        .padding(.vertical, 8)
                }
            },
            alignment: .leading
        )
        .contentShape(Rectangle())
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var slaColor: Color {
        switch application.slaStatus {
        case .onTrack: return Theme.Colors.neutral
        case .urgent: return Theme.Colors.warning
        case .overdue: return Theme.Colors.critical
        }
    }

    private var slaText: String {
        let days = application.slaDeadline.daysRemaining
        if days < 0 { return "Overdue by \(abs(days))d" }
        if days == 0 { return "Due today" }
        return "\(days)d remaining"
    }
}
