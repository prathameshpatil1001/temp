import SwiftUI

struct CompleteProfileView: View {
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    private let identitySteps = [
        "Aadhaar consent and OTP verification",
        "PAN consent and verification",
        "Final KYC status confirmation"
    ]

    private let profileSteps = [
        "Address details",
        "Income and employment details",
        "E-signature",
        "Additional profile information"
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    heroSection
                    segmentCard(
                        title: "Identity verification",
                        subtitle: "We’ll start by verifying your Aadhaar and PAN details.",
                        items: identitySteps,
                        tint: DS.primary
                    )
                    segmentCard(
                        title: "More details",
                        subtitle: "You can continue with the rest of your profile after identity verification.",
                        items: profileSteps,
                        tint: DS.warning
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }

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
        .navigationBarHidden(true)
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DS.primaryLight)
                    .frame(width: 78, height: 78)

                Image(systemName: "checkmark.shield")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(DS.primary)
            }

            VStack(spacing: 8) {
                Text("Complete your KYC")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)

                Text("Complete your identity checks first, then continue with the rest of your profile when you’re ready.")
                    .font(.system(size: 16))
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func segmentCard(title: String, subtitle: String, items: [String], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.top, 2)

                        Text(item)
                            .font(.system(size: 15))
                            .foregroundStyle(DS.textPrimary)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryBtn(title: "Continue with Aadhaar & PAN KYC") {
                path.append(KYCRoute.personalDetails)
            }

            Button("Not now") {
                dismiss()
            }
            .font(.system(size: 17))
            .foregroundStyle(DS.textSecondary)
            .frame(height: 44)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }
}
