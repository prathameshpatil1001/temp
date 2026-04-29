import SwiftUI

@available(iOS 18.0, *)
struct ReviewApplicationView: View {
    let application: BorrowerLoanApplication

    @EnvironmentObject private var router: AppRouter

    @State private var currentApplication: BorrowerLoanApplication
    @State private var product: LoanProduct?
    @State private var isConsentGiven = false
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let loanService: LoanServiceProtocol

    init(
        application: BorrowerLoanApplication,
        loanService: LoanServiceProtocol = ServiceContainer.loanService
    ) {
        self.application = application
        self.loanService = loanService
        _currentApplication = State(initialValue: application)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection

                    if isLoading {
                        ProgressView()
                            .padding(.top, 20)
                    } else if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal, 20)
                    } else {
                        loanSummarySection
                        disbursementDetailsSection
                        documentsSection
                        consentSection
                    }

                    Spacer().frame(height: 100)
                }
            }

            footerSection
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadData()
        }
    }

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Review Details")
                .font(.largeTitle).bold()
            Text("Please confirm the live application details before continuing.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.horizontal, 20)
    }

    private var loanSummarySection: some View {
        ReviewSectionCard(title: "Loan Details") {
            VStack(spacing: 16) {
                ReviewDataRow(label: "Application ID", value: currentApplication.referenceNumber)
                ReviewDataRow(label: "Product", value: currentApplication.loanProductName)
                ReviewDataRow(label: "Loan Amount", value: formatCurrency(currentApplication.requestedAmount))
                ReviewDataRow(label: "Tenure", value: "\(currentApplication.tenureMonths) Months")
                ReviewDataRow(label: "Interest Rate", value: "\(currentApplication.offeredInterestRate)% p.a.")
                ReviewDataRow(label: "Processing Fee", value: formatCurrency(String(processingFeeAmount)))
                ReviewDataRow(label: "Total Payment", value: formatCurrency(String(totalPaymentAmount)))
                ReviewDataRow(label: "Branch", value: currentApplication.branchName.isEmpty ? currentApplication.branchId : currentApplication.branchName)
                Divider()
                ReviewDataRow(label: "Current Status", value: currentApplication.status.displayName, isHighlight: true)
            }
        }
    }

    private var documentsSection: some View {
        ReviewSectionCard(title: "Documents") {
            if currentApplication.documents.isEmpty {
                Text("No application documents have been attached yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(currentApplication.documents) { document in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(document.verificationStatus.color)
                            Text(documentName(for: document))
                                .font(.subheadline)
                            Spacer()
                            Text(document.verificationStatus.displayName)
                                .font(.caption).bold()
                                .foregroundColor(document.verificationStatus.color)
                        }
                    }
                }
            }
        }
    }

    private var disbursementDetailsSection: some View {
        ReviewSectionCard(title: "Disbursement Account") {
            VStack(spacing: 16) {
                ReviewDataRow(
                    label: "Account Holder",
                    value: fallbackValue(currentApplication.disbursementAccountHolderName)
                )
                ReviewDataRow(
                    label: "Bank Name",
                    value: fallbackValue(currentApplication.disbursementBankName)
                )
                ReviewDataRow(
                    label: "Account Number",
                    value: maskedAccountNumber(currentApplication.disbursementAccountNumber)
                )
                ReviewDataRow(
                    label: "IFSC Code",
                    value: fallbackValue(currentApplication.disbursementIfscCode)
                )
            }
        }
    }

    private var consentSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                isConsentGiven.toggle()
            } label: {
                Image(systemName: isConsentGiven ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(isConsentGiven ? .mainBlue : .secondary)
            }

            Text("I confirm that these application details are correct and I authorize the bank to continue processing this loan request.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private var footerSection: some View {
        VStack {
            Divider()
            Button {
                router.push(.submitConfirmation(currentApplication))
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isConsentGiven ? DS.primary : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!isConsentGiven)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private func reloadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detailedApplication = loanService.getLoanApplication(applicationId: currentApplication.id)
            async let fetchedProduct = loanService.getLoanProduct(productId: currentApplication.loanProductId)
            currentApplication = try await detailedApplication
            product = try await fetchedProduct
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load application summary"
        }
        isLoading = false
    }

    private func documentName(for document: BorrowerApplicationDocument) -> String {
        product?.requiredDocuments
            .first(where: { $0.id == document.requiredDocId })?
            .requirementType
            .displayName ?? document.requiredDocId
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let amount = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? raw
    }

    private func maskedAccountNumber(_ accountNumber: String) -> String {
        let trimmed = accountNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 4 else { return fallbackValue(trimmed) }
        return String(repeating: "•", count: max(trimmed.count - 4, 0)) + String(trimmed.suffix(4))
    }

    private var processingFeeAmount: Double {
        guard let fee = product?.fees.first(where: { $0.type == .processing }),
              let requestedAmount = Double(currentApplication.requestedAmount),
              let feeValue = Double(fee.value) else {
            return 0
        }
        
        switch fee.calcMethod {
        case .flat:
            return feeValue
        case .percentage:
            return (requestedAmount * feeValue) / 100.0
        default:
            return 0
        }
    }

    private func fallbackValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not provided" : trimmed
    }

    private var totalPaymentAmount: Double {
        guard let principal = Double(currentApplication.requestedAmount),
              let rate = Double(currentApplication.offeredInterestRate) else {
            return 0
        }
        let n = Double(currentApplication.tenureMonths)
        
        let totalAmountAndInterest: Double
        if rate > 0 {
            let r = (rate / 12) / 100
            let emi = (principal * r * pow(1 + r, n)) / (pow(1 + r, n) - 1)
            totalAmountAndInterest = emi * n
        } else {
            totalAmountAndInterest = principal
        }
        
        return totalAmountAndInterest + processingFeeAmount
    }
}

private struct ReviewSectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

private struct ReviewDataRow: View {
    let label: String
    let value: String
    var isHighlight: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isHighlight ? .title3 : .subheadline)
                .fontWeight(isHighlight ? .bold : .semibold)
                .foregroundColor(isHighlight ? .mainBlue : .primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
