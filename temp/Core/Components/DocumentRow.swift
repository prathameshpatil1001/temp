//
//  DocumentRow.swift
//  lms_project
//

import SwiftUI

struct DocumentRow: View {
    let document: LoanDocument
    var onUpload: (() -> Void)? = nil
    var onView: (() -> Void)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Document Icon
            Image(systemName: document.type.icon)
                .font(.system(size: 18))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 36, height: 36)
                .background(Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            
            // Document Info
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(document.label)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(.primary)
                
                if let uploadedAt = document.uploadedAt {
                    Text("Uploaded \(uploadedAt.relativeFormatted)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Status Badge
            DocStatusBadge(status: document.status)
            
            // Actions
            if document.status == .pending {
                if let onUpload = onUpload {
                    Button(action: onUpload) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if let onView = onView {
                    Button(action: onView) {
                        Image(systemName: "eye.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.Colors.neutral)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.sm)
    }
}
