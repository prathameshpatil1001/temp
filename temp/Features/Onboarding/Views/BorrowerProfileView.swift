import SwiftUI
import Combine

@available(iOS 18.0, *)
struct BorrowerProfileView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: OnboardingViewModel
    @EnvironmentObject private var session: SessionStore

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 20)) ?? Date()
    @State private var gender: BorrowerGender = .male
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var stateField = ""
    @State private var pincode = ""
    @State private var employmentType: BorrowerEmploymentType = .salaried
    @State private var monthlyIncome = ""

    private var isFormValid: Bool {
        !firstName.trimmed.isEmpty &&
        !lastName.trimmed.isEmpty &&
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

            Section {
                TextField("First name", text: $firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)

                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)

                DatePicker(
                    "Date of birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )

                Picker("Gender", selection: $gender) {
                    ForEach(BorrowerGender.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
            } header: {
                Text("Personal details")
            }

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
                    .onChange(of: pincode) { _, value in
                        pincode = String(value.filter(\.isNumber).prefix(6))
                    }
            } header: {
                Text("Current address")
            }

            Section {
                Picker("Employment type", selection: $employmentType) {
                    ForEach(BorrowerEmploymentType.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }

                HStack {
                    Text("₹").foregroundStyle(.secondary)
                    TextField("Monthly income", text: $monthlyIncome)
                        .keyboardType(.decimalPad)
                        .onChange(of: monthlyIncome) { _, value in
                            monthlyIncome = sanitizedIncome(from: value)
                        }
                }
            } header: {
                Text("Employment & income")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Complete Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if firstName.isEmpty { firstName = viewModel.firstName }
            if lastName.isEmpty { lastName = viewModel.lastName }
            if addressLine1.isEmpty { addressLine1 = viewModel.addressLine1 }
            if city.isEmpty { city = viewModel.city }
            if stateField.isEmpty { stateField = viewModel.stateName }
            if pincode.isEmpty { pincode = viewModel.postalCode }
            if monthlyIncome.isEmpty { monthlyIncome = viewModel.monthlyIncome }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Profile setup")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "person.crop.circle")
            }
            .foregroundStyle(DS.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tell us about yourself")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Text("These details complete your borrower profile before KYC verification.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Save & Continue",
                isLoading: viewModel.isLoading,
                disabled: !isFormValid || viewModel.isLoading
            ) {
                viewModel.firstName = firstName.trimmed
                viewModel.lastName = lastName.trimmed
                viewModel.gender = gender.toProto
                viewModel.addressLine1 = addressLine1.trimmed
                viewModel.city = city.trimmed
                viewModel.stateName = stateField.trimmed
                viewModel.postalCode = pincode.trimmed
                viewModel.employmentType = employmentType.toProto
                viewModel.monthlyIncome = monthlyIncome.trimmed

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                viewModel.dateOfBirth = formatter.string(from: dateOfBirth)

                Task {
                    if await viewModel.submitBorrowerProfile() {
                        session.setOnboardingComplete(true)
                        path.append(OnboardingRoute.complete)
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

    private func sanitizedIncome(from value: String) -> String {
        var hasDecimal = false
        return value.filter { char in
            if char.isNumber { return true }
            if char == "." && !hasDecimal {
                hasDecimal = true
                return true
            }
            return false
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

private extension BorrowerGender {
    var toProto: Onboarding_V1_BorrowerGender {
        switch self {
        case .male: return .male
        case .female: return .female
        case .other: return .other
        }
    }
}

private extension BorrowerEmploymentType {
    var toProto: Onboarding_V1_BorrowerEmploymentType {
        switch self {
        case .salaried: return .salaried
        case .selfEmployed: return .selfEmployed
        case .businessOwner: return .business
        case .student: return .unspecified
        case .retired: return .unspecified
        }
    }
}
