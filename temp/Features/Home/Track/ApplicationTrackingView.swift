import SwiftUI
import Combine

private enum TrackingStepState {
    case completed
    case current
    case pending
}

private struct TimelineStepItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let state: TrackingStepState
}

@available(iOS 18.0, *)
struct ApplicationTrackingView: View {
    let application: BorrowerLoanApplication

    @StateObject private var viewModel = TrackViewModel()
    @State private var currentApplication: BorrowerLoanApplication
    @State private var showSanctionLetter = false

    init(application: BorrowerLoanApplication) {
        self.application = application
        _currentApplication = State(initialValue: application)
    }

    private var timelineSteps: [TimelineStepItem] {
        [
            TimelineStepItem(
                title: "Application Submitted",
                detail: "The bank received your application and basic details.",
                state: submissionState
            ),
            TimelineStepItem(
                title: "Officer Review",
                detail: "Loan officer validates documents, terms, and risk indicators.",
                state: officerState
            ),
            TimelineStepItem(
                title: "Manager Decision",
                detail: "Manager approval is required before any disbursement can happen.",
                state: managerState
            ),
            TimelineStepItem(
                title: "Sanction Letter",
                detail: "Review the sanction letter in the borrower app and accept the offered terms.",
                state: sanctionLetterState
            ),
            TimelineStepItem(
                title: "Disbursement",
                detail: "Disbursal is completed after the sanction letter is accepted.",
                state: disbursementState
            )
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                }

                if currentApplication.status == .managerApproved {
                    sanctionLetterCallout
                }

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(timelineSteps.enumerated()), id: \.element.id) { index, step in
                        TimelineRow(
                            step: step,
                            isLast: index == timelineSteps.count - 1
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Track Status")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchApplicationDetail(applicationId: currentApplication.id)
        }
        .sheet(isPresented: $showSanctionLetter) {
            SanctionLetterReviewView(application: currentApplication) {
                let updated = try await viewModel.acceptSanctionLetter(for: currentApplication)
                currentApplication = updated
            }
        }
        .onReceive(viewModel.$selectedApplication.compactMap { $0 }) { detailed in
            if detailed.id == currentApplication.id {
                currentApplication = detailed
            }
        }
    }

    private var summaryCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Application ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(currentApplication.referenceNumber)
                    .font(.headline)
                Text(BorrowerSanctionLetterSupport.statusTitle(for: currentApplication))
                    .font(.caption.weight(.semibold))
                    .foregroundColor(currentApplication.status == .managerApproved ? .orange : .green)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Applied Amount")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatCurrency(currentApplication.requestedAmount))
                    .font(.headline)
                    .foregroundColor(.mainBlue)
            }
        }
        .padding(20)
        .background(DS.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DS.primary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var sanctionLetterCallout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Sanction letter ready")
                .font(.headline)
            Text("Your manager has approved this application. Review the sanction letter and accept it to trigger real loan creation and disbursal.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showSanctionLetter = true
            } label: {
                Text("Review Sanction Letter")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(DS.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }

    private var submissionState: TrackingStepState {
        currentApplication.status == .draft ? .current : .completed
    }

    private var officerState: TrackingStepState {
        switch currentApplication.status {
        case .draft:
            return .pending
        case .submitted, .underReview, .officerReview:
            return .current
        case .officerApproved, .officerRejected, .managerReview, .managerApproved, .managerRejected, .approved, .rejected, .disbursed:
            return .completed
        default:
            return .pending
        }
    }

    private var managerState: TrackingStepState {
        switch currentApplication.status {
        case .officerApproved, .managerReview:
            return .current
        case .managerApproved, .managerRejected, .approved, .rejected, .disbursed:
            return .completed
        default:
            return .pending
        }
    }

    private var sanctionLetterState: TrackingStepState {
        if currentApplication.status == .managerApproved {
            return .current
        }
        if currentApplication.status == .disbursed {
            return .completed
        }
        return .pending
    }

    private var disbursementState: TrackingStepState {
        switch currentApplication.status {
        case .disbursed:
            return .completed
        default:
            return .pending
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}

private struct TimelineRow: View {
    let step: TimelineStepItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(circleColor.opacity(step.state == .current ? 0.2 : 1.0))
                        .frame(width: 24, height: 24)

                    if step.state == .current {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 12, height: 12)
                    } else if step.state == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2)
                        .frame(minHeight: 60)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(step.state == .pending ? .secondary : .primary)

                Text(step.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 20)
            }
            .padding(.top, 2)
        }
    }

    private var circleColor: Color {
        switch step.state {
        case .completed:
            return Color(hex: "#00C48C")
        case .current:
            return .mainBlue
        case .pending:
            return Color.gray.opacity(0.3)
        }
    }

    private var lineColor: Color {
        switch step.state {
        case .completed:
            return Color(hex: "#00C48C")
        case .current, .pending:
            return Color.gray.opacity(0.2)
        }
    }
}
