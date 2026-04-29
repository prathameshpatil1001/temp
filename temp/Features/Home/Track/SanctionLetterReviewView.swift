import SwiftUI

@available(iOS 18.0, *)
struct SanctionLetterReviewView: View {
    let application: BorrowerLoanApplication
    let acceptAction: () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionStore
    @State private var latestApplication: BorrowerLoanApplication?
    @State private var product: LoanProduct?
    @State private var isSubmitting = false
    @State private var isLoadingReadiness = false
    @State private var errorMessage: String?

    private let loanService: LoanServiceProtocol = ServiceContainer.loanService

    private var currentApplication: BorrowerLoanApplication {
        latestApplication ?? application
    }

    private var content: BorrowerSanctionLetterContent {
        BorrowerSanctionLetterSupport.makeLetter(
            for: currentApplication,
            borrowerName: session.userName,
            mobileNumber: session.userPhone
        )
    }

    private var mandatoryRequirements: [ProductRequiredDocument] {
        product?.requiredDocuments.filter(\.isMandatory) ?? []
    }

    private var approvedRequirementIDs: Set<String> {
        Set(
            currentApplication.documents
                .filter { $0.verificationStatus == .pass }
                .map(\.requiredDocId)
        )
    }

    private var approvedMandatoryCount: Int {
        mandatoryRequirements.filter { approvedRequirementIDs.contains($0.id) }.count
    }

    private var pendingMandatoryRequirements: [ProductRequiredDocument] {
        mandatoryRequirements.filter { !approvedRequirementIDs.contains($0.id) }
    }

    private var readinessMessage: String? {
        if isLoadingReadiness {
            return "Checking mandatory document approvals before final acceptance."
        }
        if product == nil {
            return "Unable to verify mandatory document approvals right now."
        }
        if pendingMandatoryRequirements.isEmpty {
            return nil
        }
        return "All mandatory documents must be verified before you can accept the sanction letter."
    }

    private var canAcceptSanctionLetter: Bool {
        !isSubmitting && !isLoadingReadiness && product != nil && pendingMandatoryRequirements.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    letterHeader
                    introCopy
                    identityTable
                    termsTable
                    documentApprovalSection
                    conditionsSection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task {
                            isSubmitting = true
                            errorMessage = nil
                            do {
                                try await acceptAction()
                                dismiss()
                            } catch {
                                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to accept sanction letter."
                            }
                            isSubmitting = false
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isSubmitting ? "Accepting..." : "Accept Sanction Letter")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canAcceptSanctionLetter ? DS.primary : DS.primary.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canAcceptSanctionLetter)

                    Text(readinessMessage ?? "Acceptance will create the real loan record and update the application to disbursed.")
                        .font(.footnote)
                        .foregroundColor(readinessMessage == nil ? .secondary : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Sanction Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadReadinessData()
            }
        }
    }

    private var letterHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Date: \(content.sanctionDate)")
                .font(.headline)

            Text("Dear \(content.applicantName),")
                .font(.title3.weight(.semibold))

            Text("Thank you for choosing ABC Bank. Based on your application and the information provided, we are pleased to extend a loan offer on the preliminary terms and conditions below.")
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var introCopy: some View {
        VStack(spacing: 0) {
            tableRow("Application No.", content.applicationNumber)
            tableRow("Sanctioned Date", content.sanctionDate)
            tableRow("Applicant Name", content.applicantName)
            tableRow("Mobile No.", content.mobileNumber, isLast: true)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var identityTable: some View {
        VStack(spacing: 0) {
            tableRow("Loan Type", content.loanType)
            tableRow("Loan Amount Sanctioned", content.sanctionedAmount)
            tableRow("Reference Interest Rate", content.referenceInterestRate)
            tableRow("Floating Interest Rate", content.floatingInterestRate)
            tableRow("Loan Tenor", content.loanTenor)
            tableRow("Total Processing Charges", content.processingCharges)
            tableRow("Origination Fee (Inclusive of GST)", content.originationFee)
            tableRow("Sanction Letter Validity", content.validity)
            tableRow("Amount of EMI (INR)", content.emiAmount)
            tableRow("Property Address", content.propertyAddress, isLast: true)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var termsTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acceptance Summary")
                .font(.headline)

            HStack(spacing: 12) {
                summaryPill(title: "Status", value: pendingMandatoryRequirements.isEmpty ? "Pending Acceptance" : "Docs Pending")
                summaryPill(title: "Version", value: "v1")
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var documentApprovalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document Approval Status")
                .font(.headline)

            HStack(spacing: 12) {
                summaryPill(title: "Mandatory Approved", value: "\(approvedMandatoryCount)/\(mandatoryRequirements.count)")
                summaryPill(title: "Application Status", value: BorrowerSanctionLetterSupport.statusTitle(for: currentApplication))
            }

            if let readinessMessage {
                Text(readinessMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !pendingMandatoryRequirements.isEmpty {
                ForEach(pendingMandatoryRequirements, id: \.id) { requirement in
                    HStack(spacing: 10) {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text(requirement.requirementType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text(documentStatusText(for: requirement))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var conditionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Additional conditions to comply prior to loan disbursal:")
                .font(.headline)

            ForEach(Array(content.conditions.enumerated()), id: \.offset) { index, condition in
                Text("\(index + 1). \(condition)")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func tableRow(_ label: String, _ value: String, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .frame(width: 150, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.mainBlue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DS.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func documentStatusText(for requirement: ProductRequiredDocument) -> String {
        if let document = currentApplication.documents.first(where: { $0.requiredDocId == requirement.id }) {
            return document.verificationStatus.displayName
        }
        return "Not Uploaded"
    }

    private func loadReadinessData() async {
        isLoadingReadiness = true
        defer { isLoadingReadiness = false }

        do {
            async let fetchedApplication = loanService.getLoanApplication(applicationId: application.id)
            async let fetchedProduct = loanService.getLoanProduct(productId: application.loanProductId)
            let (detail, fetchedLoanProduct) = try await (fetchedApplication, fetchedProduct)
            latestApplication = detail
            product = fetchedLoanProduct
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to verify document readiness."
        }
    }
}
