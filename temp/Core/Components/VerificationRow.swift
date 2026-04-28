//
//  VerificationRow.swift
//  lms_project
//

import SwiftUI

struct VerificationRow: View {
    let item: VerificationItem
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Match/Mismatch Icon
            Image(systemName: item.isMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(item.isMatch ? Theme.Colors.success : Theme.Colors.warning)
            
            // Field Label
            VStack(alignment: .leading, spacing: 2) {
                Text(item.field)
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: Theme.Spacing.sm) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Declared")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.tertiary)
                        Text(item.declaredValue)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Extracted")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.tertiary)
                        Text(item.extractedValue)
                            .font(Theme.Typography.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(item.isMatch ? Color.primary : Theme.Colors.warning)
                    }
                }
            }
            
            Spacer()
            
            // Status
            Text(item.isMatch ? "Match" : "Mismatch")
                .font(Theme.Typography.caption2)
                .foregroundStyle(item.isMatch ? Theme.Colors.success : Theme.Colors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background((item.isMatch ? Theme.Colors.success : Theme.Colors.warning).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}
