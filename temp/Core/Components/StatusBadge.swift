//
//  StatusBadge.swift
//  lms_project
//

import SwiftUI

struct StatusBadge: View {
    let status: ApplicationStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.1))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(status.color.opacity(0.15), lineWidth: 0.5)
            )
    }
}

// MARK: - Generic Badge

struct GenericBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Document Status Badge

struct DocStatusBadge: View {
    let status: DocumentStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 9, weight: .black))
            Text(status.displayName)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.08))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(status.color.opacity(0.1), lineWidth: 0.5)
        )
    }
}
