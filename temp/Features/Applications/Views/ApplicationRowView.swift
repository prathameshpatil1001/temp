import SwiftUI

struct ApplicationRowView: View {
    let application: LoanApplication
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            HStack(alignment: .top, spacing: AppSpacing.sm) {

                // Avatar
                AvatarView(
                    initials: application.initials,
                    color: application.name.avatarColor,
                    size: 48
                )
                .padding(.top, 2)

                // Content
                VStack(alignment: .leading, spacing: AppSpacing.xs) {

                    // Row 1: Name + Status badge + Chevron
                    HStack(alignment: .center, spacing: AppSpacing.xs) {
                        Text(application.name)
                            .font(AppFont.bodyMedium())
                            .foregroundColor(Color.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        ApplicationStatusBadge(status: application.status)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.textTertiary)
                    }

                    // Row 2: Loan type + amount
                    HStack(spacing: 4) {
                        Image(systemName: application.loanType.icon)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color.textTertiary)
                        Text(application.loanType.rawValue)
                            .font(AppFont.subhead())
                            .foregroundColor(Color.textSecondary)
                        Text("·")
                            .foregroundColor(Color.textTertiary)
                        Text(application.formattedAmount)
                            .font(AppFont.subheadMed())
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                    }

                    // Row 3: Pipeline progress bar
                    PipelineProgressBar(application: application)

                    // Row 4: Status label (e.g. "2 days left", "Completed")
                    statusLabelView
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm + 2)
            .background(Color.surfacePrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status label row
    @ViewBuilder
    private var statusLabelView: some View {
        HStack(spacing: 5) {
            // Icon based on status
            if application.status == .rejected {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusRejected)
            } else if application.status == .disbursed {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusDisbursed)
            } else if let days = application.slaDays, days <= 2 {
                Image(systemName: "clock.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color.statusPending)
            } else {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundColor(Color.textTertiary)
            }

            Text(application.statusLabel)
                .font(AppFont.caption())
                .foregroundColor(statusLabelColor)
        }
    }

    private var statusLabelColor: Color {
        switch application.status {
        case .rejected:    return Color.statusRejected
        case .disbursed:   return Color.statusDisbursed
        case .underReview:
            if let days = application.slaDays, days <= 2 { return Color.statusPending }
            return Color.textSecondary
        default:           return Color.textSecondary
        }
    }
}

#Preview {
    let sample = LoanApplication(
        id: UUID(), leadId: nil, name: "Rohit Verma", phone: "9900112233",
        loanType: .business, loanAmount: 5_000_000, status: .underReview,
        createdAt: Date(), updatedAt: Date(), slaDays: 2, statusLabel: "2 days left",
        bankName: "HDFC", sanctionedAmount: nil, disbursedAmount: nil, rmName: "Vikram"
    )
    ApplicationRowView(application: sample)
        .padding()
}
