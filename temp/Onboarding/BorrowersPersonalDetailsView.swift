import SwiftUI

struct BorrowerProfile {
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: BorrowerGender
    var addressLine1: String
    var city: String
    var state: String
    var pincode: String
}

enum BorrowerGender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    var id: String { rawValue }
}

enum BorrowerEmploymentType: String, CaseIterable, Identifiable {
    case salaried = "Salaried"
    case selfEmployed = "Self-employed"
    case businessOwner = "Business owner"
    case student = "Student"
    case retired = "Retired"

    var id: String { rawValue }
}

struct BorrowersPersonalDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Calendar.current.date(
        from: DateComponents(year: 1995, month: 8, day: 20)
    ) ?? Date()
    @State private var gender: BorrowerGender = .male
    @State private var addressLine1 = ""
    @State private var city = ""
    @State private var state = ""
    @State private var pincode = ""
    @State private var goToEmployment = false

    private var isFormValid: Bool {
        !firstName.trimmed.isEmpty &&
        !lastName.trimmed.isEmpty &&
        !addressLine1.trimmed.isEmpty &&
        !city.trimmed.isEmpty &&
        !state.trimmed.isEmpty &&
        pincode.trimmed.count == 6
    }

    private var profile: BorrowerProfile {
        BorrowerProfile(
            firstName: firstName.trimmed,
            lastName: lastName.trimmed,
            dateOfBirth: dateOfBirth,
            gender: gender,
            addressLine1: addressLine1.trimmed,
            city: city.trimmed,
            state: state.trimmed,
            pincode: pincode.trimmed
        )
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
                    .submitLabel(.next)

                TextField("Last name", text: $lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)

                DatePicker(
                    "Date of birth",
                    selection: $dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )

                Picker("Gender", selection: $gender) {
                    ForEach(BorrowerGender.allCases) { gender in
                        Text(gender.rawValue).tag(gender)
                    }
                }
            } header: {
                Text("Personal")
            }

            Section {
                TextField("Address line 1", text: $addressLine1, axis: .vertical)
                    .textContentType(.streetAddressLine1)
                    .textInputAutocapitalization(.words)
                    .lineLimit(1...3)

                TextField("City", text: $city)
                    .textContentType(.addressCity)
                    .textInputAutocapitalization(.words)

                TextField("State", text: $state)
                    .textContentType(.addressState)
                    .textInputAutocapitalization(.words)

                TextField("Pincode", text: $pincode)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .onChange(of: pincode) { _, newValue in
                        pincode = String(newValue.filter(\.isNumber).prefix(6))
                    }
            } header: {
                Text("Current address")
            } footer: {
                Text("Use the same address that appears on your proof of address document.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Your Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $goToEmployment) {
            BorrowersEmploymentDetailsView(path: $path, profile: profile)
                .environmentObject(viewModel)
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
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Step 1 of 2")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "person.crop.circle")
            }
            .foregroundStyle(Color.mainBlue)

            VStack(alignment: .leading, spacing: 6) {
                Text("Tell us about yourself")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("We’ll use this information to prefill your loan profile and match it with your documents.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Continue",
                disabled: !isFormValid || viewModel.isLoading
            ) {
                let fullName = "\(firstName.trimmed) \(lastName.trimmed)".trimmingCharacters(in: .whitespacesAndNewlines)

                viewModel.fullName = fullName
                viewModel.panNumber = "PENDING"
                viewModel.currentAddress = addressLine1.trimmed
                viewModel.city = city.trimmed
                viewModel.stateName = state.trimmed
                viewModel.postalCode = pincode.trimmed

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                viewModel.dateOfBirth = formatter.string(from: dateOfBirth)

                Task {
                    let personalSaved = await viewModel.submitPersonalDetails()
                    let addressSaved = personalSaved ? await viewModel.submitAddressProof() : false
                    if personalSaved && addressSaved {
                        goToEmployment = true
                    }
                }
            }

            if !isFormValid {
                Text("Complete all details to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}

struct BorrowersEmploymentDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    let profile: BorrowerProfile

    @State private var employmentType: BorrowerEmploymentType = .salaried
    @State private var monthlyIncome = ""

    private var isFormValid: Bool {
        guard let income = Decimal(string: monthlyIncome.trimmed) else { return false }
        return income > 0
    }

    var body: some View {
        List {
            Section {
                headerContent
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                Picker("Employment type", selection: $employmentType) {
                    ForEach(BorrowerEmploymentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }

                HStack {
                    Text("₹")
                        .foregroundStyle(.secondary)

                    TextField("Monthly income", text: $monthlyIncome)
                        .keyboardType(.decimalPad)
                        .onChange(of: monthlyIncome) { _, newValue in
                            monthlyIncome = sanitizedIncome(from: newValue)
                        }
                }
            } header: {
                Text("Income")
            } footer: {
                Text("Enter your approximate monthly income before deductions.")
            }

            Section {
                summaryRow(title: "Name", value: "\(profile.firstName) \(profile.lastName)")
                summaryRow(title: "City", value: profile.city)
                summaryRow(title: "Pincode", value: profile.pincode)
            } header: {
                Text("Profile summary")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Income Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var headerContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Step 2 of 2")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "indianrupeesign.circle")
            }
            .foregroundStyle(Color.mainBlue)

            VStack(alignment: .leading, spacing: 6) {
                Text("Add employment details")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("This helps us understand eligibility before we ask for verification documents.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summaryRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Continue",
                disabled: !isFormValid || viewModel.isLoading
            ) {
                viewModel.selectedEmploymentStatus = employmentType.rawValue
                viewModel.netMonthlyIncome = monthlyIncome.trimmed

                Task {
                    if await viewModel.submitIncomeDetails() {
                        path.append(SignupRoute.faceIDPrompt)
                    }
                }
            }

            if !isFormValid {
                Text("Enter monthly income to continue.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    private func sanitizedIncome(from value: String) -> String {
        var hasDecimalPoint = false

        return value.filter { character in
            if character.isNumber {
                return true
            }

            if character == "." && !hasDecimalPoint {
                hasDecimalPoint = true
                return true
            }

            return false
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BorrowersPersonalDetailsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            BorrowersPersonalDetailsView(path: .constant(NavigationPath()))
                .environmentObject(KYCViewModel())
        }
    }
}
