import SwiftUI
import Combine
import PhotosUI
import CoreLocation

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var displayName: String {
        let trimmedName = session.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "LoanOS Borrower" : trimmedName
    }

    private var contactSubtitle: String {
        if !session.userEmail.isEmpty && !session.userPhone.isEmpty {
            return "\(session.userEmail) • \(formattedPhone)"
        }
        if !session.userEmail.isEmpty {
            return session.userEmail
        }
        if !session.userPhone.isEmpty {
            return formattedPhone
        }
        return profileSubtitle
    }

    private var formattedPhone: String {
        let digits = session.userPhone.filter(\.isNumber)
        guard digits.count == 10 else { return session.userPhone }
        let start = digits.prefix(5)
        let end = digits.suffix(5)
        return "+91 \(start) \(end)"
    }

    private var profileSubtitle: String {
        switch session.kycStatus {
        case .approved:
            return "Aadhaar & PAN KYC verified"
        case .pending:
            return "Verification in progress"
        case .rejected:
            return "Verification needs attention"
        case .notStarted:
            return "Complete verification to unlock more features"
        }
    }

    private var kycStatusLabel: String {
        switch session.kycStatus {
        case .approved:
            return "Verified"
        case .pending:
            return "In Progress"
        case .rejected:
            return "Retry"
        case .notStarted:
            return "Start KYC"
        }
    }

    private var kycStatusColor: Color {
        switch session.kycStatus {
        case .approved:
            return Color(hex: "#00C48C")
        case .pending:
            return .secondaryBlue
        case .rejected:
            return .alertRed
        case .notStarted:
            return .mainBlue
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Profile Header
                VStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        profileAvatar

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Circle()
                                .fill(DS.primary)
                                .frame(width: 32, height: 32)
                                .overlay(Image(systemName: "camera.fill").font(.caption).foregroundColor(.white))
                                .offset(x: -4, y: -4)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(displayName).font(.title2).bold()
                        Text(contactSubtitle).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)
                
                // Menu Options
                VStack(spacing: 0) {
                    ProfileMenuRow(icon: "person.text.rectangle.fill", title: "Profile", route: .editProfile)
                    Divider().padding(.leading, 56)
                    ProfileMenuRow(icon: "checkmark.shield.fill", title: "KYC Status", value: kycStatusLabel, valueColor: kycStatusColor, route: .kycStatus)
                    Divider().padding(.leading, 56)
                    ProfileMenuRow(icon: "clock.arrow.circlepath", title: "Loan History", route: .loanHistory)
                    Divider().padding(.leading, 56)
                    ProfileMenuRow(icon: "gearshape.fill", title: "Settings", route: .settings)
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Logout
                Button {
                    session.logout()
                } label: {
                    Text("Log Out")
                        .font(.headline)
                        .foregroundColor(.alertRed)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
    }

    @ViewBuilder
    private var profileAvatar: some View {
        if let data = session.profileImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(DS.primary.opacity(0.12), lineWidth: 1)
                )
        } else {
            Circle()
                .fill(DS.primary.opacity(0.1))
                .frame(width: 100, height: 100)
                .overlay(
                    Text(String(displayName.prefix(1)))
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.mainBlue)
                )
        }
    }

    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else { return }
        do {
            if let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let jpegData = image.jpegData(compressionQuality: 0.82) {
                session.updateProfileImage(jpegData)
            }
        } catch {
            // Ignore picker failures to keep the screen usable.
        }
    }
}

struct ProfileMenuRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    var valueColor: Color = .secondary
    let route: AppRoute
    
    var body: some View {
        NavigationLink(value: route) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.mainBlue)
                    .frame(width: 24)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let val = value {
                    Text(val)
                        .font(.subheadline).bold()
                        .foregroundColor(valueColor)
                }
                
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Profile View
@available(iOS 18.0, *)
struct EditProfileView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel = BorrowerProfileEditorViewModel()
    @State private var showingAddressSearch = false
    
    var body: some View {
        List {
            Section {
                profileSummary
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                TextField("First name", text: $viewModel.firstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)

                TextField("Last name", text: $viewModel.lastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)

                DatePicker(
                    "Date of birth",
                    selection: $viewModel.dateOfBirth,
                    in: ...Date(),
                    displayedComponents: .date
                )

                Picker("Gender", selection: $viewModel.gender) {
                    ForEach(ProfileGender.allCases) { gender in
                        Text(gender.title).tag(gender)
                    }
                }
            } header: {
                Text("Personal details")
            }

            Section {
                Button(action: { showingAddressSearch = true }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Search for an address...")
                    }
                    .foregroundColor(DS.primary)
                }

                TextField("Address line 1", text: $viewModel.addressLine1, axis: .vertical)
                    .textContentType(.streetAddressLine1)
                    .textInputAutocapitalization(.words)
                    .lineLimit(1...3)

                TextField("City", text: $viewModel.city)
                    .disabled(true)
                    .foregroundStyle(.secondary)

                TextField("State", text: $viewModel.stateName)
                    .disabled(true)
                    .foregroundStyle(.secondary)

                TextField("Pincode/Zipcode", text: $viewModel.pincode)
                    .textContentType(.postalCode)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.pincode) { _, newValue in
                        let cleaned = newValue.filter(\.isNumber)
                        if cleaned.count == 6 {
                            let geocoder = CLGeocoder()
                            geocoder.geocodeAddressString(cleaned) { placemarks, _ in
                                if let place = placemarks?.first {
                                    if let fetchedCity = place.locality ?? place.subAdministrativeArea {
                                        viewModel.city = fetchedCity
                                    }
                                    if let fetchedState = place.administrativeArea {
                                        viewModel.stateName = fetchedState
                                    }
                                }
                            }
                        }
                    }
            } header: {
                Text("Current address")
            }

            Section {
                Picker("Employment type", selection: $viewModel.employmentType) {
                    ForEach(ProfileEmploymentType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }

                HStack {
                    Text("₹")
                        .foregroundStyle(.secondary)
                    TextField("Monthly income", text: $viewModel.monthlyIncome)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.monthlyIncome) { _, value in
                            viewModel.monthlyIncome = viewModel.sanitizeIncome(value)
                        }
                }
            } header: {
                Text("Employment & income")
            }

            Section {
                LabeledContent("Email", value: session.userEmail.isEmpty ? "Not available" : session.userEmail)
                LabeledContent("Phone", value: session.userPhone.isEmpty ? "Not available" : formattedPhone(session.userPhone))
            } header: {
                Text("Contact")
            } footer: {
                Text("Email and phone come from your login account. Contact support if they need to be changed.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile()
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $showingAddressSearch) {
            AddressSearchView { selectedCity, selectedState, selectedPincode in
                if !selectedCity.isEmpty { viewModel.city = selectedCity }
                if !selectedState.isEmpty { viewModel.stateName = selectedState }
                if !selectedPincode.isEmpty { viewModel.pincode = selectedPincode }
            }
        }
        .alert("Profile Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Borrower profile")
                .font(.headline)
                .foregroundStyle(DS.textPrimary)
            Text("Review and update the onboarding information saved for your account.")
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                Task {
                    let didSave = await viewModel.saveProfile()
                    if didSave {
                        let fullName = [viewModel.firstName.trimmed, viewModel.lastName.trimmed]
                            .filter { !$0.isEmpty }
                            .joined(separator: " ")
                        if !fullName.isEmpty {
                            session.updateName(fullName)
                        }
                        await session.completeSessionFromBackend()
                        router.pop()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isSaving ? "Saving..." : "Save Changes")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(viewModel.isFormValid ? DS.primary : DS.primary.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!viewModel.isFormValid || viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }

    private func formattedPhone(_ rawPhone: String) -> String {
        let digits = rawPhone.filter(\.isNumber)
        guard digits.count == 10 else { return rawPhone }
        return "+91 \(digits.prefix(5)) \(digits.suffix(5))"
    }
}

@MainActor
@available(iOS 18.0, *)
final class BorrowerProfileEditorViewModel: ObservableObject {
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var dateOfBirth = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 20)) ?? Date()
    @Published var gender: ProfileGender = .female
    @Published var addressLine1 = ""
    @Published var city = ""
    @Published var stateName = ""
    @Published var pincode = ""
    @Published var employmentType: ProfileEmploymentType = .salaried
    @Published var monthlyIncome = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let authRepository = AuthRepository()
    private let onboardingClient = OnboardingGRPCClient()
    private var hasLoaded = false

    var isFormValid: Bool {
        !firstName.trimmed.isEmpty &&
        !lastName.trimmed.isEmpty &&
        !addressLine1.trimmed.isEmpty &&
        !city.trimmed.isEmpty &&
        !stateName.trimmed.isEmpty &&
        !pincode.trimmed.isEmpty &&
        (Decimal(string: monthlyIncome.trimmed) ?? 0) > 0
    }

    func loadProfile() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await authRepository.getMyProfile()
            if let borrower = profile.borrowerProfile {
                firstName = borrower.firstName
                lastName = borrower.lastName
                dateOfBirth = parseDate(borrower.dateOfBirth) ?? dateOfBirth
                gender = ProfileGender(rawBackendValue: borrower.gender) ?? .female
                addressLine1 = borrower.addressLine1
                city = borrower.city
                stateName = borrower.state
                pincode = borrower.pincode
                employmentType = ProfileEmploymentType(rawBackendValue: borrower.employmentType) ?? .salaried
                monthlyIncome = sanitizeIncome(borrower.monthlyIncome)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProfile() async -> Bool {
        guard isFormValid else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            let token = try TokenStore.shared.accessToken() ?? ""
            let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
            var request = Onboarding_V1_UpdateBorrowerProfileRequest()
            request.firstName = firstName.trimmed
            request.lastName = lastName.trimmed
            request.dateOfBirth = formattedBackendDate(dateOfBirth)
            request.gender = gender.protoValue
            request.addressLine1 = addressLine1.trimmed
            request.city = city.trimmed
            request.state = stateName.trimmed
            request.pincode = pincode
            request.employmentType = employmentType.protoValue
            request.monthlyIncome = monthlyIncome.trimmed
            request.profileCompletenessPercent = 100

            let response = try await onboardingClient.updateBorrowerProfile(
                request: request,
                metadata: metadata,
                options: options
            )

            if !response.success {
                errorMessage = "Profile update failed. Please try again."
                return false
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }

    private func formattedBackendDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func sanitizeIncome(_ value: String) -> String {
        var hasDecimal = false
        return value.filter { character in
            if character.isNumber { return true }
            if character == "." && !hasDecimal {
                hasDecimal = true
                return true
            }
            return false
        }
    }
}

enum ProfileGender: String, CaseIterable, Identifiable {
    case male
    case female
    case other

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var protoValue: Onboarding_V1_BorrowerGender {
        switch self {
        case .male: return .male
        case .female: return .female
        case .other: return .other
        }
    }

    init?(rawBackendValue: String) {
        let normalized = rawBackendValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "male", "borrower_gender_male":
            self = .male
        case "female", "borrower_gender_female":
            self = .female
        case "other", "borrower_gender_other":
            self = .other
        default:
            return nil
        }
    }
}

enum ProfileEmploymentType: String, CaseIterable, Identifiable {
    case salaried
    case selfEmployed
    case businessOwner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .salaried: return "Salaried"
        case .selfEmployed: return "Self Employed"
        case .businessOwner: return "Business"
        }
    }

    var protoValue: Onboarding_V1_BorrowerEmploymentType {
        switch self {
        case .salaried: return .salaried
        case .selfEmployed: return .selfEmployed
        case .businessOwner: return .business
        }
    }

    init?(rawBackendValue: String) {
        let normalized = rawBackendValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "salaried", "borrower_employment_type_salaried":
            self = .salaried
        case "self employed", "self_employed", "borrower_employment_type_self_employed":
            self = .selfEmployed
        case "business", "business owner", "borrower_employment_type_business":
            self = .businessOwner
        default:
            return nil
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
