import SwiftUI

@available(iOS 18.0, *)
struct LoanApplicationView: View {
    let loan: LoanProduct

    @StateObject private var viewModel = LoanApplicationViewModel(service: ServiceContainer.loanService)
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var showDisbursementDetails = false

    private var minAmount: Double { max(Double(loan.minAmount) ?? 10_000, 1) }
    private var maxAmount: Double { max(Double(loan.maxAmount) ?? minAmount, minAmount) }
    private var interestRate: Double { Double(loan.baseInterestRate) ?? 0 }

    private var amountBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.requestedAmount) ?? minAmount },
            set: { viewModel.requestedAmount = String(Int($0.rounded())) }
        )
    }

    private var tenureBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.tenureMonths) },
            set: { viewModel.tenureMonths = max(Int($0.rounded()), 1) }
        )
    }

    private var minimumTenure: Double { 6 }
    private var maximumTenure: Double { 84 }

    private var estimatedEMI: Double {
        let principal = Double(viewModel.requestedAmount) ?? minAmount
        let monthlyRate = (interestRate / 12) / 100
        let periods = Double(max(viewModel.tenureMonths, 1))
        guard monthlyRate > 0 else { return principal / periods }
        let factor = pow(1 + monthlyRate, periods)
        return (principal * monthlyRate * factor) / (factor - 1)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    amountSection
                    tenureSection
                    branchSection
                    infoSection

                    if let error = viewModel.submissionError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }

            footerSection
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showDisbursementDetails) {
            DisbursementDetailsView(loan: loan, viewModel: viewModel)
                .environmentObject(router)
        }
        .task {
            viewModel.selectedProductId = loan.id
            // Inject the borrower profile ID from the authenticated session
            if viewModel.borrowerProfileId.isEmpty {
                viewModel.borrowerProfileId = sessionStore.borrowerProfileId
            }
            if viewModel.requestedAmount.isEmpty {
                viewModel.requestedAmount = String(Int(minAmount.rounded()))
            }
            if viewModel.tenureMonths <= 0 {
                viewModel.tenureMonths = Int(minimumTenure)
            }
            viewModel.preloadSubmissionContext()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customize your loan")
                .font(.largeTitle).bold()
            Text("Submitting a real application for \(loan.name).")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Loan Amount")
                    .font(.headline)
                Spacer()
                Text(formatCurrency(amountBinding.wrappedValue))
                    .font(.title2).bold()
                    .foregroundColor(.mainBlue)
            }

            Slider(value: amountBinding, in: minAmount...maxAmount, step: 1_000)
                .accentColor(.mainBlue)

            HStack {
                Text(formatCurrency(minAmount))
                Spacer()
                Text(formatCurrency(maxAmount))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var tenureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tenure (Months)")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.tenureMonths) Mos")
                    .font(.title2).bold()
                    .foregroundColor(.secondaryBlue)
            }

            Slider(value: tenureBinding, in: minimumTenure...maximumTenure, step: 1)
                .accentColor(.secondaryBlue)

            HStack {
                Text("\(Int(minimumTenure)) Mos")
                Spacer()
                Text("\(Int(maximumTenure)) Mos")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "building.2")
                    .foregroundColor(.mainBlue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing Branch")
                        .font(.headline)
                    Text("Choose the branch where you want your application to be processed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.isLoadingBranches {
                ProgressView("Loading branches...")
                    .font(.footnote)
            } else {
                Picker("Select Branch", selection: $viewModel.selectedBranchId) {
                    Text("Select a branch").tag("")
                    ForEach(viewModel.branches) { branch in
                        Text("\(branch.name) (\(branch.locationLabel))").tag(branch.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: viewModel.selectedBranchId) { _, newValue in
                    viewModel.updateSelectedBranch(newValue)
                }
            }

            if !viewModel.detectedBranchName.isEmpty {
                Text("Resolved branch: \(viewModel.detectedBranchName)")
                    .font(.caption)
                    .foregroundColor(.secondaryBlue)
            }

            let location = viewModel.selectedBranchLocation()
            if !location.isEmpty {
                Text("Location: \(location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let branchLoadError = viewModel.branchLoadError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(branchLoadError)
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Retry") {
                        viewModel.retryLoadingBranches()
                    }
                    .font(.caption.bold())
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .cardStyle()
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(.mainBlue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Base rate \(String(format: "%.2f%%", interestRate)) p.a.")
                        .font(.subheadline).bold()
                    Text("Required documents: \(loan.requiredDocuments.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let rule = loan.eligibilityRule {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Eligibility Snapshot")
                        .font(.subheadline).bold()
                    Text("Minimum age: \(rule.minAge)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Minimum monthly income: \(formatCurrency(rule.minMonthlyIncome))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if rule.minBureauScore > 0 {
                        Text("Minimum bureau score: \(rule.minBureauScore)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .cardStyle(tint: DS.primaryLight.opacity(0.5))
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            Divider()
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Estimated EMI")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(formatCurrency(estimatedEMI, minimumFractionDigits: 2))
                        .font(.title2).bold()
                        .foregroundColor(.primary)
                }

                Spacer()

                Button {
                    viewModel.submissionError = nil
                    showDisbursementDetails = true
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(DS.primary)
                        .clipShape(Capsule())
                }
                .disabled(!viewModel.canProceedToDisbursementDetails())
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .background(Color(UIColor.systemBackground))
    }

    private func formatCurrency(
        _ value: Double,
        minimumFractionDigits: Int = 0,
        maximumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.minimumFractionDigits = minimumFractionDigits
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? value.formatted()
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        return formatCurrency(value)
    }
}

private extension View {
    func cardStyle(tint: Color = .white) -> some View {
        self
            .padding(20)
            .background(tint)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

@available(iOS 18.0, *)
private struct DisbursementDetailsView: View {
    let loan: LoanProduct
    @ObservedObject var viewModel: LoanApplicationViewModel

    @EnvironmentObject private var router: AppRouter
    @FocusState private var focusedField: Field?

    private enum Field {
        case accountHolderName
        case bankName
        case accountNumber
        case ifscCode
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection
                    creditDetailsSection
                    securityNoteSection

                    if let error = viewModel.submissionError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }

            footerSection
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Credit Details")
        .navigationBarTitleDisplayMode(.inline)
        .textInputAutocapitalization(.words)
        .onAppear {
            if viewModel.disbursementAccountHolderName.isEmpty {
                viewModel.disbursementAccountHolderName = ""
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where should we credit your loan?")
                .font(.largeTitle).bold()
            Text("Add the bank account details where your \(loan.name) amount should be disbursed.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var creditDetailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            DisbursementInputField(
                title: "Account Holder Name",
                placeholder: "Enter account holder name",
                text: $viewModel.disbursementAccountHolderName
            )
            .focused($focusedField, equals: .accountHolderName)
            .submitLabel(.next)
            .onSubmit { focusedField = .bankName }

            DisbursementInputField(
                title: "Bank Name",
                placeholder: "Enter bank name",
                text: $viewModel.disbursementBankName
            )
            .focused($focusedField, equals: .bankName)
            .submitLabel(.next)
            .onSubmit { focusedField = .accountNumber }

            DisbursementInputField(
                title: "Account Number",
                placeholder: "Enter account number",
                text: $viewModel.disbursementAccountNumber,
                keyboardType: .numberPad
            )
            .focused($focusedField, equals: .accountNumber)
            .textInputAutocapitalization(.never)

            DisbursementInputField(
                title: "IFSC Code",
                placeholder: "Enter IFSC code",
                text: Binding(
                    get: { viewModel.disbursementIfscCode },
                    set: { viewModel.disbursementIfscCode = $0.uppercased() }
                ),
                keyboardType: .asciiCapable
            )
            .focused($focusedField, equals: .ifscCode)
            .textInputAutocapitalization(.characters)
            .submitLabel(.done)
            .onSubmit { focusedField = nil }
        }
        .cardStyle()
    }

    private var securityNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.mainBlue)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Used for disbursement only")
                        .font(.subheadline).bold()
                    Text("We’ll use these details to credit the sanctioned amount after approval. Please make sure the account belongs to you.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .cardStyle(tint: DS.primaryLight.opacity(0.5))
    }

    private var footerSection: some View {
        VStack(spacing: 16) {
            Divider()

            Button {
                focusedField = nil
                Task {
                    guard let application = await viewModel.submitApplication() else { return }
                    if loan.requiredDocuments.isEmpty {
                        router.push(.reviewApplication(application))
                    } else {
                        router.push(.documentUpload(application))
                    }
                }
            } label: {
                if viewModel.isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Text("Create Application")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .disabled(viewModel.isSubmitting)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }
}

private struct DisbursementInputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

@available(iOS 18.0, *)
#Preview {
    NavigationStack {
        LoanApplicationView(
            loan: LoanProduct(
                id: UUID().uuidString,
                name: "Personal Loan",
                category: .personal,
                interestType: .fixed,
                baseInterestRate: "10.5",
                minAmount: "10000",
                maxAmount: "500000",
                isRequiringCollateral: false,
                isActive: true,
                eligibilityRule: ProductEligibilityRule(
                    id: UUID().uuidString,
                    minAge: 21,
                    minMonthlyIncome: "30000",
                    minBureauScore: 700,
                    allowedEmploymentTypes: ["SALARIED"]
                ),
                fees: [],
                requiredDocuments: []
            )
        )
        .environmentObject(AppRouter())
    }
}
