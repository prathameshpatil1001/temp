import SwiftUI

// MARK: - Pipeline Progress Bar
struct PipelineProgressBar: View {
    let application: LoanApplication

    private let stages = LoanApplication.pipeline
    private let segmentSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let totalSpacing = segmentSpacing * CGFloat(stages.count - 1)
            let segWidth = (geo.size.width - totalSpacing) / CGFloat(stages.count)

            HStack(spacing: segmentSpacing) {
                ForEach(stages) { stage in
                    Capsule()
                        .fill(segmentColor(for: stage))
                        .frame(width: segWidth, height: 4)
                        .animation(.easeInOut(duration: 0.3).delay(Double(stage.id) * 0.05), value: application.status)
                }
            }
        }
        .frame(height: 4)
    }

    // MARK: - Color logic per segment
    private func segmentColor(for stage: PipelineStage) -> Color {
        let currentStep = application.status.pipelineStep
        let isRejected  = application.status == .rejected

        if isRejected {
            if stage.id <= currentStep {
                return Color.statusRejected
            } else {
                return Color.surfaceTertiary
            }
        } else {
            if stage.id <= currentStep {
                return Color.brandBlue
            } else {
                return Color.surfaceTertiary
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        let stages = LoanApplication.pipeline
        let _ = stages // suppress warning

        Group {
            PipelineProgressBar(application: LoanApplication(
                id: UUID(), leadId: nil, name: "A", phone: "", loanType: .home,
                loanAmount: 100, status: .underReview,
                createdAt: Date(), updatedAt: Date(),
                slaDays: nil, statusLabel: "Review"))

            PipelineProgressBar(application: LoanApplication(
                id: UUID(), leadId: nil, name: "A", phone: "", loanType: .home,
                loanAmount: 100, status: .approved,
                createdAt: Date(), updatedAt: Date(),
                slaDays: nil, statusLabel: "Approved"))

            PipelineProgressBar(application: LoanApplication(
                id: UUID(), leadId: nil, name: "A", phone: "", loanType: .home,
                loanAmount: 100, status: .rejected,
                createdAt: Date(), updatedAt: Date(),
                slaDays: nil, statusLabel: "Closed"))

            PipelineProgressBar(application: LoanApplication(
                id: UUID(), leadId: nil, name: "A", phone: "", loanType: .home,
                loanAmount: 100, status: .disbursed,
                createdAt: Date(), updatedAt: Date(),
                slaDays: nil, statusLabel: "Completed"))
        }
        .padding(.horizontal)
    }
    .padding()
}
