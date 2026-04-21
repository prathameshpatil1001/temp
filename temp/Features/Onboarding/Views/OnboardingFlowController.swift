import SwiftUI

enum OnboardingRoute: Hashable {
    case borrowerProfile
    case complete
}

@available(iOS 18.0, *)
struct OnboardingFlowController: View {
    @State private var path = NavigationPath()
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        NavigationStack(path: $path) {
            BorrowerProfileView(path: $path)
                .environmentObject(viewModel)
                .navigationDestination(for: OnboardingRoute.self) { route in
                    switch route {
                    case .borrowerProfile:
                        BorrowerProfileView(path: $path)
                            .environmentObject(viewModel)
                    case .complete:
                        HomeView()
                    }
                }
        }
        .environmentObject(viewModel)
    }
}
