import SwiftUI

struct CompleteProfileView: View {
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 34) {
                heroSection
                detailsSection
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)

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
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(DS.primaryLight)
                    .frame(width: 70, height: 70)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(DS.primary)
            }

            VStack(spacing: 8) {
                Text("Complete your profile")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Add your basic details before we verify your documents.")
                    .font(.system(size: 17))
                    .foregroundStyle(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("We’ll ask for")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            VStack(spacing: 0) {
                detailsRow(
                    icon: "person.text.rectangle",
                    title: "Personal details",
                    subtitle: "Name, date of birth, and gender"
                )

                divider

                detailsRow(
                    icon: "house",
                    title: "Current address",
                    subtitle: "Address, city, state, and pincode"
                )

                divider

                detailsRow(
                    icon: "indianrupeesign.circle",
                    title: "Income details",
                    subtitle: "Employment type and monthly income"
                )
            }
            .background(DS.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
        }
    }

    private var divider: some View {
        Divider()
            .padding(.leading, 64)
    }

    private func detailsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DS.primaryLight)
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DS.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(DS.textPrimary)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(DS.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            PrimaryBtn(title: "Continue") {
                path.append(KYCRoute.personalDetails)
            }
            
            Button("Not now") {
                dismiss() // This will dismiss the KYCFlowController from HomeView
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
