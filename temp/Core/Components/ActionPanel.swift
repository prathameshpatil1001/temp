//
//  ActionPanel.swift
//  lms_project
//

import SwiftUI

// MARK: - Loan Officer Action Panel

struct LOActionPanel: View {
    let status: ApplicationStatus
    let onSendToManager: () -> Void
    let onReject: () -> Void
    let onRequestDocs: () -> Void
    
    @State private var showRejectAlert = false
    @Environment(\.colorScheme) private var colorScheme

    private var primaryActionTitle: String {
        switch status {
        case .pending, .officerReview, .underReview:
            return "Approve"
        case .officerApproved:
            return "Send to Manager"
        case .managerReview:
            return "Sent to Manager"
        case .managerApproved, .approved:
            return "Approved"
        case .officerRejected, .managerRejected, .rejected:
            return "Rejected"
        }
    }

    private var primaryActionIcon: String {
        switch status {
        case .pending, .officerReview, .underReview:
            return "checkmark.circle.fill"
        case .officerApproved:
            return "arrow.up.circle.fill"
        case .managerReview:
            return "hourglass.circle.fill"
        case .managerApproved, .approved:
            return "checkmark.seal.fill"
        case .officerRejected, .managerRejected, .rejected:
            return "xmark.circle.fill"
        }
    }

    private var isPrimaryActionEnabled: Bool {
        switch status {
        case .pending, .officerReview, .underReview, .officerApproved:
            return true
        case .managerReview, .managerApproved, .approved, .officerRejected, .managerRejected, .rejected:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Divider()
            
            HStack(spacing: Theme.Spacing.md) {
                // Request Documents
                Button(action: onRequestDocs) {
                    Label("Request Docs", systemImage: "doc.badge.plus")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Reject
                Button {
                    showRejectAlert = true
                } label: {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.critical)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.critical.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                
                // Send to Manager
                Button(action: onSendToManager) {
                    Label(primaryActionTitle, systemImage: primaryActionIcon)
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(isPrimaryActionEnabled ? Theme.Colors.adaptivePrimary(colorScheme) : Theme.Colors.neutral.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
                .disabled(!isPrimaryActionEnabled)
            }
        }
        .padding(Theme.Spacing.md)
        .alert("Reject Application", isPresented: $showRejectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reject", role: .destructive) { onReject() }
        } message: {
            Text("Are you sure you want to reject this application?")
        }
    }
}

// MARK: - Manager Action Panel

struct ManagerActionPanel: View {
    let onApprove: () -> Void
    let onRejectWithRemarks: () -> Void   // triggers remarks sheet
    let onSendBack: () -> Void
    var onEditTerms: (() -> Void)? = nil
    var onAssignOfficer: (() -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Divider()

            // Row 1: Secondary actions
            HStack(spacing: Theme.Spacing.md) {
                // Send Back
                Button(action: onSendBack) {
                    Label("Send Back", systemImage: "arrow.uturn.left")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)

                // Reject
                Button(action: onRejectWithRemarks) {
                    Label("Reject", systemImage: "xmark.circle")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.Colors.critical)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Layout.buttonHeight)
                        .background(Theme.Colors.critical.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                }
                .buttonStyle(.plain)
            }

            // Row 2: Edit actions + final Approve
            HStack(spacing: Theme.Spacing.md) {
                // Edit Terms (calls UpdateLoanApplicationTerms)
                Button { onEditTerms?() } label: {
                    Label("Edit Terms", systemImage: "pencil.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)

                // Reassign Officer
                Button { onAssignOfficer?() } label: {
                    Label("Reassign", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                                .stroke(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.25), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Approve
                Button(action: onApprove) {
                    Label("Approve", systemImage: "checkmark.circle.fill")
                        .font(Theme.Typography.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Theme.Colors.success)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Spacing.md)
    }
}
