import SwiftUI

struct KYCVerifyingView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @EnvironmentObject private var session: SessionStore

    @Environment(\.dismiss) private var dismiss

    @State private var contentVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(DS.primary)
                    .scaleEffect(1.25)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("Verification in progress")

                VStack(spacing: 10) {
                    Text("Verifying your documents")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("This usually takes a few seconds. Please don’t close the app.")
                        .font(.system(size: 17))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Your documents are securely encrypted")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.primary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 10)

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                contentVisible = true
            }

            Task {
                await pollStatusLoop()
            }
        }
    }

    private func pollStatusLoop() async {
        // Mock polling logic for up to 3 tries
        for _ in 1...3 {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // wait 2s
            let status = await viewModel.pollKYCStatus()
            
            if status == .approved {
                await MainActor.run {
                    // Do not update session yet so they can see the success screen
                    path.append(KYCRoute.verificationSuccess)
                }
                return
            } else if status == .rejected {
                await MainActor.run {
                    session.kycStatus = .rejected
                    path.append(KYCRoute.verificationFailed)
                }
                return
            }
        }
        
        // Timeout / Fallback logic if it didn't complete
        await MainActor.run {
            session.kycStatus = .rejected
            path.append(KYCRoute.verificationFailed)
        }
    }
}
