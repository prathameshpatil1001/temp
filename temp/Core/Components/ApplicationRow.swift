//
//  ApplicationRow.swift
//  lms_project
//

import SwiftUI

struct ApplicationRow: View {
    let application: LoanApplication
    let isSelected: Bool
    var useMinimalStyle: Bool = false
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // Borrower Avatar with Status Ring
            ZStack {
                Circle()
                    .fill((useMinimalStyle ? Theme.Colors.primary : application.status.color).opacity(0.10))
                    .frame(width: 50, height: 50)
                
                Text(application.borrower.name.prefix(1))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(useMinimalStyle ? Theme.Colors.primary : application.status.color)
                
                if !useMinimalStyle {
                    Circle()
                        .stroke(application.status.color.opacity(0.2), lineWidth: 1.5)
                        .frame(width: 50, height: 50)
                }
            }
            
            // Main Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(application.borrower.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    StatusBadge(status: application.status)
                }
                
                HStack(spacing: 8) {
                    Text(application.loan.type.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.quaternary)
                    
                    Text(application.loan.amount.currencyFormatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.primary)
                }
                
                HStack {
                    // SLA Indicator
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
                    
                    // Risk badge
                    if application.riskLevel == .high {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("High Risk")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(Theme.Colors.critical)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.critical.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            isSelected
            ? (colorScheme == .dark ? Theme.Colors.adaptiveSurfaceSecondary(colorScheme) : Theme.Colors.lightBlue)
            : Color.clear
        )
        .overlay(
            Group {
                if isSelected {
                    Rectangle()
                        .fill(Theme.Colors.mainBlue)
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
