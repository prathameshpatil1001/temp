import SwiftUI

struct KYCVerificationFailedView: View {
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(DS.warning.opacity(0.12))
                        .frame(width: 96, height: 96)

                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(DS.warning)
                }

                VStack(spacing: 12) {
                    Text("Verification Failed")
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(DS.warning)
                        .multilineTextAlignment(.center)

                    Text("Document was unclear or incomplete")
                        .font(.system(size: 16))
                        .foregroundStyle(DS.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 16) {
                    PrimaryBtn(title: "Try Again") {
                        // Reset to the beginning of the KYC Flow
                        path = NavigationPath()
                    }

                    Button("Contact Support") {
                        // Dummy action
                    }
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DS.textSecondary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            AnalyticsManager.shared.logEvent(.kycFailed)
        }
    }
}
