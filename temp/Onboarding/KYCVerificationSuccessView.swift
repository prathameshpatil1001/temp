import SwiftUI

struct KYCVerificationSuccessView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                successIcon

                VStack(spacing: 10) {
                    Text("Verification Complete")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Your identity has been successfully verified.")
                        .font(.system(size: 17))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            bottomBar
        }
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

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(DS.primaryLight)
                .frame(width: 92, height: 92)

            Circle()
                .fill(DS.primary)
                .frame(width: 58, height: 58)

            Image(systemName: "checkmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .accessibilityLabel("Verification complete")
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Explore Loans") {
                // By updating session here, KYCFlowController will automatically dismiss everything.
                AnalyticsManager.shared.logEvent(.kycCompleted)
                session.kycStatus = .approved
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}
