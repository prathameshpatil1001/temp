import SwiftUI

struct VerifyIdentityView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    private var canContinue: Bool {
        viewModel.isBackendImplementedFlowComplete
    }

    var body: some View {
        List {
            Section {
                headerSection
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section("Identity verification") {
                aadhaarCard
                panCard
                statusCard
            }

            Section("Up next") {
                remainingRow("Address details")
                remainingRow("Income details")
                remainingRow("E-signature")
                remainingRow("Additional profile details")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Aadhaar & PAN")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text("Step 2 of 3")
                    .font(.subheadline.weight(.semibold))
            } icon: {
                Image(systemName: "checkmark.shield")
            }
            .foregroundStyle(DS.primary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Verify your identity")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)

                Text("Complete your Aadhaar and PAN checks to continue.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var aadhaarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Aadhaar verification")
                    .font(.headline)

                Spacer()

                statusBadge(isComplete: viewModel.isAadhaarVerified)
            }

            Toggle("I consent to Aadhaar KYC verification", isOn: $viewModel.aadhaarConsentGranted)

            TextField("12-digit Aadhaar number", text: $viewModel.aadhaarNumber)
                .keyboardType(.numberPad)

            Button {
                Task {
                    _ = await viewModel.sendAadhaarOTP()
                }
            } label: {
                actionLabel("Send OTP", isCompact: true)
            }
            .buttonStyle(.plain)

            if viewModel.hasStartedAadhaarStep {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Reference ID: \(viewModel.aadhaarReferenceID)")
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)

                    TextField("Enter Aadhaar OTP", text: $viewModel.aadhaarOTP)
                        .keyboardType(.numberPad)

                    Button {
                        Task {
                            _ = await viewModel.verifyAadhaarOTP()
                        }
                    } label: {
                        actionLabel("Verify Aadhaar OTP", isCompact: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var panCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PAN verification")
                    .font(.headline)

                Spacer()

                statusBadge(isComplete: viewModel.isPanVerified)
            }

            Toggle("I consent to PAN KYC verification", isOn: $viewModel.panConsentGranted)

            infoRow(title: "Name as per PAN", value: viewModel.fullName.isEmpty ? "Pending profile details" : viewModel.fullName)
            infoRow(title: "PAN", value: viewModel.normalizedPAN.isEmpty ? "Pending PAN number" : viewModel.normalizedPAN)
            infoRow(title: "Date of birth", value: viewModel.dateOfBirth.isEmpty ? "Pending date of birth" : viewModel.dateOfBirth)

            Button {
                Task {
                    _ = await viewModel.verifyPan()
                }
            } label: {
                actionLabel("Verify PAN", isCompact: true)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verification status")
                .font(.headline)

            Text("Once both checks are complete, your profile will show your updated verification status.")
                .font(.subheadline)
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }

    private func remainingRow(_ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(DS.warning)

            Text(title)
                .foregroundStyle(DS.textPrimary)
        }
        .padding(.vertical, 4)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(DS.textSecondary)

            Spacer(minLength: 16)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(DS.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func statusBadge(isComplete: Bool) -> some View {
        Text(isComplete ? "Done" : "Pending")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isComplete ? Color.white : DS.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isComplete ? DS.primary : DS.primaryLight)
            .clipShape(Capsule())
    }

    private func actionLabel(_ title: String, isCompact: Bool) -> some View {
        Text(viewModel.isLoading ? viewModel.loadingActionText : title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(DS.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Continue to summary", isLoading: false, disabled: !canContinue) {
                path.append(KYCRoute.submissionSummary)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DS.warning)
                    .multilineTextAlignment(.center)
            } else if !canContinue {
                Text("Complete Aadhaar and PAN verification to continue.")
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.regularMaterial)
    }
}
