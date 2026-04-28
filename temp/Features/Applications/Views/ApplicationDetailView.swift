import SwiftUI

// MARK: - Application Detail View (DST)
/// Rich status-tracker view for a submitted loan application.
/// Mirrors the borrower-side ActiveLoanDetailsView but shows application pipeline
/// stages (not EMI/repayment data) since DST manages pre-disbursement stages.
struct ApplicationDetailView: View {
    let application: LoanApplication

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerCard
                statusTimelineCard
                infoCard
                commissionCard
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .background(Color.surfaceSecondary.ignoresSafeArea())
        .navigationTitle("Application Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(spacing: AppSpacing.sm) {
            // Avatar
            ZStack {
                Circle()
                    .fill(application.name.avatarColor.opacity(0.15))
                    .frame(width: 72, height: 72)
                Text(application.initials)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(application.name.avatarColor)
            }

            Text(application.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Color.textPrimary)

            ApplicationStatusBadge(status: application.status)

            HStack(spacing: 6) {
                Image(systemName: application.loanType.icon)
                    .font(.system(size: 13))
                    .foregroundColor(Color.textTertiary)
                Text(application.loanType.rawValue)
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                Text("·")
                    .foregroundColor(Color.textTertiary)
                Text(application.formattedAmount)
                    .font(AppFont.subheadMed())
                    .foregroundColor(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Status Timeline Card

    private var statusTimelineCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Application Timeline")
                .font(AppFont.headline())
                .foregroundColor(Color.textPrimary)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ApplicationPipelineStage.allCases.enumerated()), id: \.element) { idx, stage in
                    let stageState = stateFor(stage)
                    HStack(alignment: .top, spacing: 16) {
                        // Vertical line + dot
                        VStack(spacing: 0) {
                            // Top connector
                            if idx > 0 {
                                Rectangle()
                                    .fill(lineColor(for: idx))
                                    .frame(width: 2, height: 16)
                            } else {
                                Spacer().frame(height: 16)
                            }

                            // Step dot
                            ZStack {
                                Circle()
                                    .fill(dotBackground(for: stageState))
                                    .frame(width: 28, height: 28)

                                switch stageState {
                                case .completed:
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                case .active:
                                    Circle()
                                        .fill(Color.brandBlue)
                                        .frame(width: 10, height: 10)
                                case .rejected:
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                case .pending:
                                    Circle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 8, height: 8)
                                }
                            }

                            // Bottom connector (don't draw after last)
                            if idx < ApplicationPipelineStage.allCases.count - 1 {
                                Rectangle()
                                    .fill(lineColor(for: idx + 1))
                                    .frame(width: 2)
                                    .frame(minHeight: 24)
                            }
                        }
                        .frame(width: 28)

                        // Label
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stage.title)
                                .font(stageState == .active ? AppFont.bodyMedium() : AppFont.body())
                                .foregroundColor(stageState == .pending ? Color.textTertiary : Color.textPrimary)

                            Text(stage.subtitle(for: application.status))
                                .font(AppFont.caption())
                                .foregroundColor(stageState == .active
                                    ? Color.brandBlue
                                    : stageState == .rejected
                                        ? Color.statusRejected
                                        : Color.textTertiary)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Info Card

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow("Bank / Branch", application.bankName ?? "—")
            Divider().padding(.leading, AppSpacing.md)
            infoRow("RM Assigned", application.rmName ?? "—")
            Divider().padding(.leading, AppSpacing.md)
            infoRow("Submitted On", formattedDate(application.createdAt))
            if let sanctioned = application.sanctionedAmount {
                Divider().padding(.leading, AppSpacing.md)
                infoRow("Sanctioned Amount", formatAmount(sanctioned))
            }
            if let disbursed = application.disbursedAmount {
                Divider().padding(.leading, AppSpacing.md)
                infoRow("Disbursed Amount", formatAmount(disbursed))
            }
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Commission Card

    private var commissionCard: some View {
        HStack(spacing: AppSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brandBlue.opacity(0.10))
                    .frame(width: 48, height: 48)
                Image(systemName: "indianrupeesign.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color.brandBlue)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Estimated Commission (0.25%)")
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                Text("30-45 days after sanction")
                    .font(AppFont.caption())
                    .foregroundColor(Color.textTertiary)
            }
            Spacer()
            Text(estimatedCommission)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.textPrimary)
        }
        .padding(AppSpacing.md)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.subheadMed())
                .foregroundColor(Color.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 13)
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }

    private func formatAmount(_ v: Double) -> String {
        let lakhs = v / 100_000
        if lakhs >= 100 { return "₹\(String(format: "%.0f", lakhs / 100))Cr" }
        if v.truncatingRemainder(dividingBy: 100_000) == 0 { return "₹\(Int(lakhs))L" }
        return "₹\(String(format: "%.1f", lakhs))L"
    }

    private var estimatedCommission: String {
        let commission = application.loanAmount * 0.0025
        return formatAmount(commission)
    }

    // Timeline state resolution
    enum StageState { case completed, active, rejected, pending }

    private func stateFor(_ stage: ApplicationPipelineStage) -> StageState {
        let currentStep = application.status.pipelineStep
        let stageStep   = stage.step

        // If overall status is rejected and this is the review stage → show rejected
        if (application.status == .rejected) && stage == .review { return .rejected }

        if stageStep < currentStep  { return .completed }
        if stageStep == currentStep { return .active }
        return .pending
    }

    private func dotBackground(for state: StageState) -> Color {
        switch state {
        case .completed: return Color.brandBlue
        case .active:    return Color.brandBlue.opacity(0.15)
        case .rejected:  return Color.statusRejected
        case .pending:   return Color(.systemGray5)
        }
    }

    private func lineColor(for stageIndex: Int) -> Color {
        // Line above index is colored when stage at that index is completed/active
        let stage = ApplicationPipelineStage.allCases[stageIndex]
        let s = stateFor(stage)
        return (s == .completed || s == .active) ? Color.brandBlue.opacity(0.35) : Color(.systemGray5)
    }
}

// MARK: - Pipeline Stage Enum (DST view)

enum ApplicationPipelineStage: CaseIterable, Hashable {
    case applied
    case submitted
    case review
    case approved
    case disbursed

    var step: Int {
        switch self {
        case .applied:   return 0
        case .submitted: return 1
        case .review:    return 2
        case .approved:  return 3
        case .disbursed: return 4
        }
    }

    var title: String {
        switch self {
        case .applied:   return "Applied"
        case .submitted: return "Submitted"
        case .review:    return "Under Review"
        case .approved:  return "Approved"
        case .disbursed: return "Disbursed"
        }
    }

    func subtitle(for status: ApplicationStatus) -> String {
        switch self {
        case .applied:
            return "Application created"
        case .submitted:
            return status.pipelineStep >= 1 ? "Submitted for review" : "Awaiting submission"
        case .review:
            if status == .rejected { return "Application rejected" }
            return status.pipelineStep >= 2 ? "Under review by team" : "Not yet started"
        case .approved:
            return status.pipelineStep >= 3 ? "Loan sanctioned ✓" : "Pending approval"
        case .disbursed:
            return status.pipelineStep >= 4 ? "Funds disbursed ✓" : "Awaiting disbursement"
        }
    }
}
