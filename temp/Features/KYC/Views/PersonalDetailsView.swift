import SwiftUI

/// KYC Step 1 of 3 — Collects all fields required by CompleteBorrowerOnboarding
/// and fires it before navigating to VerifyIdentityView.
/// The backend requires a borrower_profiles row to exist before any KYC RPC works.
@available(iOS 18.0, *)
struct PersonalDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    // Personal
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 20)) ?? Date()
    @State private var gender: BorrowerGender = .male

    // PAN
    @State private var panNumber = ""

    // Address
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var stateField = ""
    @State private var pincode = ""

    // Employment
    @State private var employmentType: BorrowerEmploymentType = .salaried
    @State private var monthlyIncome = ""

    private var isFormValid: Bool {
        !firstName.trimmed.isEmpty &&
        !lastName.trimmed.isEmpty &&
        panNumber.trimmed.uppercased().count == 10 &&
        !addressLine1.trimmed.isEmpty &&
        !city.trimmed.isEmpty &&
        !stateField.trimmed.isEmpty &&
        pincode.trimmed.count == 6 &&
        (Decimal(string: monthlyIncome.trimmed) ?? 0) > 0
    }

    var body: some View {
        List {
            Section {
                headerContent
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            // MARK: Personal
            Section {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)

                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)

                TextField("PAN number", text: $panNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: panNumber) { _, v in
                        panNumber = String(v.uppercased().prefix(10))
                    }

                DatePicker(
                    "Date of birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )

                Picker("Gender", selection: $gender) {
                    ForEach(BorrowerGender.allCases) { g in
                        Text(g.rawValue).tag(g)
                    }
                }
            } header: {
                Text("Personal details")
            } footer: {
                Text("Your name and DOB must match your Aadhaar and PAN exactly.")
            }

            // MARK: Address
            Section {
                TextField("Address line 1", text: $addressLine1, axis: .vertical)
                    .textContentType(.streetAddressLine1)
                    .textInputAutocapitalization(.words)
                    .lineLimit(1...3)

                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)

                TextField("State", text: $stateField)
                    .textContentType(.addressState)
                    .textInputAutocapitalization(.words)

                TextField("Pincode", text: $pincode)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .onChange(of: pincode) { _, v in
                        pincode = String(v.filter(\.isNumber).prefix(6))
                    }
            } header: {
                Text("Current address")
            }

            // MARK: Employment
            Section {
                Picker("Employment type", selection: $employmentType) {
                    ForEach(BorrowerEmploymentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                HStack {
                    Text("₹").foregroundStyle(.secondary)
                    TextField("Monthly income", text: $monthlyIncome)
                        .keyboardType(.decimalPad)
                        .onChange(of: monthlyIncome) { _, v in
                            monthlyIncome = sanitizedIncome(from: v)
                        }
                }
            } header: {
                Text("Employment & income")
            } footer: {
                Text("Enter your approximate monthly income before deductions.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Pre-fill if coming back from a later step
            if !viewModel.firstName.isEmpty { firstName = viewModel.firstName }
            if !viewModel.lastName.isEmpty  { lastName  = viewModel.lastName }
            if !viewModel.panNumber.isEmpty && viewModel.panNumber != "PENDING" {
                panNumber = viewModel.panNumber
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Back")
            }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // MARK: - Header

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Step 1 of 3")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "person.crop.circle")
            }
            .foregroundStyle(DS.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Set up your borrower profile")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Text("These details are used to verify your identity via Aadhaar and PAN. They must match exactly.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Save & Continue",
                isLoading: viewModel.isLoading,
                disabled: !isFormValid || viewModel.isLoading
            ) {
                // Push all collected fields into the ViewModel
                viewModel.firstName   = firstName.trimmed
                viewModel.lastName    = lastName.trimmed
                viewModel.gender      = gender.toProto
                viewModel.panNumber   = panNumber.trimmed.uppercased()
                viewModel.currentAddress = addressLine1.trimmed
                viewModel.city        = city.trimmed
                viewModel.stateName   = stateField.trimmed
                viewModel.postalCode  = pincode.trimmed
                viewModel.selectedEmploymentStatus = employmentType.rawValue
                viewModel.netMonthlyIncome = monthlyIncome.trimmed

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                viewModel.dateOfBirth = formatter.string(from: dateOfBirth)

                Task {
                    // submitPersonalDetails stores locally,
                    // submitAddressProof stores locally,
                    // submitIncomeDetails fires CompleteBorrowerOnboarding → creates the DB row.
                    let step1 = await viewModel.submitPersonalDetails()
                    guard step1 else { return }
                    let step2 = await viewModel.submitAddressProof()
                    guard step2 else { return }
                    if await viewModel.submitIncomeDetails() {
                        path.append(KYCRoute.verifyIdentity)
                    }
                }
            }

            if let error = viewModel.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(DS.warning)
                    .multilineTextAlignment(.center)
            } else if !isFormValid {
                Text("Complete all fields to continue.")
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private func sanitizedIncome(from value: String) -> String {
        var hasDecimal = false
        return value.filter { c in
            if c.isNumber { return true }
            if c == "." && !hasDecimal { hasDecimal = true; return true }
            return false
        }
    }
}

// MARK: - String trimmed

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - BorrowerGender.toProto

@available(iOS 18.0, *)
private extension BorrowerGender {
    var toProto: Onboarding_V1_BorrowerGender {
        switch self {
        case .male:   return .male
        case .female: return .female
        case .other:  return .other
        }
    }
}
