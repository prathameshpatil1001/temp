import SwiftUI
import Combine

@available(iOS 18.0, *)
@MainActor
final class OnboardingViewModel: ObservableObject {
    enum State {
        case idle
        case loading(String)
        case error(String)
        case success
    }

    @Published var state: State = .idle
    @Published var errorMessage: String?

    var firstName = ""
    var lastName = ""
    var dateOfBirth = ""
    var gender: Onboarding_V1_BorrowerGender = .male
    var addressLine1 = ""
    var city = ""
    var stateName = ""
    var postalCode = ""
    var employmentType: Onboarding_V1_BorrowerEmploymentType = .salaried
    var monthlyIncome = ""

    private let client = OnboardingGRPCClient()

    func submitBorrowerProfile() async -> Bool {
        state = .loading("Saving profile...")
        errorMessage = nil

        do {
            var req = Onboarding_V1_CompleteBorrowerOnboardingRequest()
            req.firstName = firstName
            req.lastName = lastName
            req.dateOfBirth = dateOfBirth
            req.gender = gender
            req.addressLine1 = addressLine1
            req.city = city
            req.state = stateName
            req.pincode = postalCode
            req.employmentType = employmentType
            req.monthlyIncome = monthlyIncome
            req.profileCompletenessPercent = 100

            let token = try TokenStore.shared.accessToken() ?? ""
            let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)

            let response = try await client.completeBorrowerOnboarding(
                request: req,
                metadata: metadata,
                options: options
            )

            if response.success {
                state = .success
                return true
            }

            state = .error("Profile submission failed.")
            errorMessage = "Profile submission failed. Please try again."
            return false
        } catch {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            return false
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }
}
