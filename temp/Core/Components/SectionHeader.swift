//
//  SectionHeader.swift
//  lms_project
//

import SwiftUI

struct SectionHeader: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil
    var infoAction: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .lastTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.Colors.primary)
                    }
                    
                    HStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        if let infoAction = infoAction {
                            Button(action: infoAction) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.Colors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.leading, icon != nil ? 22 : 0)
                }
            }
            
            Spacer()
            
            if let actionLabel = actionLabel, let action = action {
                Button(action: action) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    func description(_ text: String) -> SectionHeader {
        var copy = self
        copy.subtitle = text
        return copy
    }
    
    func info(action: @escaping () -> Void) -> SectionHeader {
        var copy = self
        copy.infoAction = action
        return copy
    }
}
