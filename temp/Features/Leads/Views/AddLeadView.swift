import SwiftUI
import GRPCCore

struct AddLeadView: View {
    @ObservedObject var viewModel: LeadsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedType = LoanType.home
    @State private var amountText = ""
    @State private var showTypePicker = false
    @State private var didAttemptSubmit = false

    // Borrower Profile Resolution
    @State private var borrowerStatus: BorrowerStatus = .unknown
    @State private var showBorrowerLookupErrorAlert = false
    @State private var borrowerLookupErrorMessage = ""
    @State private var showBorrowerSignupPrompt = false
    @State private var isCheckingBorrower = false
    private let borrowerLookupService = BorrowerLookupService()

    enum BorrowerStatus {
        case unknown
        case checking
        case found(profileID: String?, name: String)
        case notFound
        case error

        var displayText: String {
            switch self {
            case .unknown: return ""
            case .checking: return "Checking if borrower exists..."
            case .found(_, let name): return "✓ Found existing borrower: \(name)"
            case .notFound: return "⚠️ Borrower not registered"
            case .error: return "Unable to verify borrower"
            }
        }

        var color: Color {
            switch self {
            case .unknown: return .clear
            case .checking: return .gray
            case .found: return .green
            case .notFound: return .red
            case .error: return .orange
            }
        }

        var icon: String? {
            switch self {
            case .unknown, .checking: return nil
            case .found: return "checkmark.circle.fill"
            case .notFound: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Validation
    private var nameTrimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var phoneDigits: String { phone.filter(\.isNumber) }
    private var emailTrimmed: String { email.trimmingCharacters(in: .whitespaces) }

    private var formValid: Bool {
        nameTrimmed.count >= 2 &&
        phoneDigits.count == 10 &&
        (emailTrimmed.isEmpty || emailError == nil) &&
        (Double(amountText) ?? 0) > 0
    }

    private var buttonTitle: String {
        if isCheckingBorrower { return "Checking borrower..." }
        if formValid { return "Add Lead" }
        return "Add Lead"
    }

    private var emailError: String? {
        if emailTrimmed.isEmpty { return nil }
        let regex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return emailTrimmed.range(of: regex, options: .regularExpression) == nil
        ? "Invalid email"
        : nil
    }

    // MARK: - UI
    var body: some View {
        NavigationStack {
            VStack {
                ScrollView {
                    VStack(spacing: 16) {

                        TextField("Name", text: $name)
                        TextField("Phone", text: $phone)
                            .keyboardType(.numberPad)
                        TextField("Email", text: $email)

                        TextField("Amount", text: $amountText)
                            .keyboardType(.numberPad)

                        borrowerStatusView
                    }
                    .padding()
                }

                Button(action: submit) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(formValid && !isCheckingBorrower ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!formValid || isCheckingBorrower)
                .padding()
            }
            .navigationTitle("Add Lead")
            .sheet(isPresented: $showBorrowerSignupPrompt) {
                borrowerSignupPromptSheet
            }
            .alert("Unable to verify borrower", isPresented: $showBorrowerLookupErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(borrowerLookupErrorMessage)
            }
        }
    }

    private var borrowerStatusView: some View {
        HStack {
            if case .checking = borrowerStatus {
                ProgressView()
            } else if let icon = borrowerStatus.icon {
                Image(systemName: icon)
            }

            Text(borrowerStatus.displayText)
            Spacer()
        }
    }

    private var borrowerSignupPromptSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text("Borrower not registered")
                    .font(.headline)
                Text("No borrower account was found for this phone/email. Ask the user to download the Borrower app and complete signup first.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Registration Required")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        showBorrowerSignupPrompt = false
                    }
                }
            }
        }
        .presentationDetents([.height(280)])
    }

    // MARK: - Submit
    private func submit() {
        guard formValid else { return }

        Task {
            await verifyBorrowerAndSubmitLead()
        }
    }

    @MainActor
    private func verifyBorrowerAndSubmitLead() async {
        guard let amount = Double(amountText) else { return }
        borrowerStatus = .checking
        isCheckingBorrower = true
        defer { isCheckingBorrower = false }

        do {
            if let result = try await borrowerLookupService.resolveBorrower(email: emailTrimmed, phone: phoneDigits) {
                borrowerStatus = .found(profileID: result.borrowerProfileID, name: result.displayName)
                let lead = Lead(
                    id: UUID().uuidString,
                    name: nameTrimmed,
                    phone: phoneDigits,
                    email: emailTrimmed,
                    borrowerProfileID: result.borrowerProfileID,
                    borrowerUserID: result.userID,
                    loanType: selectedType,
                    loanAmount: amount,
                    status: .new,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                viewModel.addLead(lead)
                dismiss()
            } else {
                borrowerStatus = .notFound
                showBorrowerSignupPrompt = true
            }
        } catch let rpcError as RPCError where rpcError.code == .cancelled {
            borrowerStatus = .unknown
        } catch is CancellationError {
            borrowerStatus = .unknown
        } catch {
            borrowerStatus = .error
            if let lookupError = error as? BorrowerLookupError {
                borrowerLookupErrorMessage = lookupError.localizedDescription
            } else {
                borrowerLookupErrorMessage = error.localizedDescription
            }
            showBorrowerLookupErrorAlert = true
        }
    }
}
