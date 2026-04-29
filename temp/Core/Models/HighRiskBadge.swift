//
//  HighRiskBadge.swift
//  lms_project
//
//  Created by Apple on 28/04/26.
//

import SwiftUI

struct HighRiskBadge: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 4) {
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
