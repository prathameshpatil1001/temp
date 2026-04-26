import SwiftUI

struct LoginPasswordChangeView: View {
    @Binding var path: NavigationPath

    @EnvironmentObject private var viewModel: LoginViewModel
    @EnvironmentObject private var session: SessionStore

    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private var canSubmit: Bool {
        newPassword.count >= 8 && confirmPassword == newPassword
    }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Update your password")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Your account requires a password change before continuing.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                SecureField("New password (min 8 characters)", text: $newPassword)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
                SecureField("Confirm new password", text: $confirmPassword)
                    .textContentType(.newPassword)
                    .textInputAutocapitalization(.never)
            }
            .padding()
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            PrimaryBtn(
                title: viewModel.isLoading ? viewModel.loadingActionText : "Update Password",
                disabled: !canSubmit || viewModel.isLoading
            ) {
                Task {
                    let success = await viewModel.updatePasswordAndContinue(newPassword: newPassword)
                    if success {
                        AnalyticsManager.shared.logEvent(.loginCompleted)
                        session.completeSession(contactIdentifier: viewModel.currentLoginIdentifier)
                        path = NavigationPath()
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
    }
}
