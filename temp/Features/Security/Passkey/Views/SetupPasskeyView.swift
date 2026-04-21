import SwiftUI

struct SetupPasskeyView: View {
    @Environment(\.dismiss) private var dismiss

    @StateObject private var viewModel = PasskeySetupViewModel()
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.bottom, 22)

            VStack(spacing: 28) {
                Spacer(minLength: 8)

                heroSection
                    .slide(appeared)

                contentCard
                    .slide(appeared, delay: 0.04)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .alert("Passkey Setup", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = viewModel.errorMessage {
                Text(message)
            }
        }
        .onAppear {
            appeared = true
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var heroSection: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#EEF7FF"))
                    .frame(width: 110, height: 110)

                Circle()
                    .fill(Color(hex: "#DDEEFF"))
                    .frame(width: 82, height: 82)

                Image(systemName: "faceid")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundColor(DS.primary)
            }

            VStack(spacing: 8) {
                Text("Set up a real passkey")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(DS.textPrimary)

                Text("This uses Apple’s native passkey sheet and keeps the private key on the device. Face ID or Touch ID unlocks it when the server-side WebAuthn flow is ready.")
                    .font(.system(size: 16))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 10)
            }
        }
    }

    private var contentCard: some View {
        VStack(spacing: 18) {
            statusSection

            PrimaryBtn(
                title: buttonTitle,
                isLoading: viewModel.isLoading
            ) {
                Task {
                    let success = await viewModel.registerPasskey()
                    if success {
                        dismiss()
                    }
                }
            }
        }
        .padding(22)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var statusSection: some View {
        VStack(spacing: 10) {
            switch viewModel.state {
            case .success:
                Text("Passkey configured on this device.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.textPrimary)

                Text("Once the backend registration endpoint is completed, this device will be ready for native passkey prompts.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            case .loading(let text):
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.textPrimary)

                Text("You should only see Apple’s native system prompt during passkey creation.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            default:
                Text(viewModel.isConfiguredLocally ? "A passkey was already added on this device." : "Add a passkey to this device.")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DS.textPrimary)

                Text("LoanOS never handles the passkey’s private key directly.")
                    .font(.system(size: 14))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var buttonTitle: String {
        if case .success = viewModel.state {
            return "Done"
        }
        return viewModel.isConfiguredLocally ? "Set Up Again" : "Set Up Passkey"
    }
}
