import SwiftUI

struct KYCSubmissionSummaryView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var isDeclarationAccepted = false

    private var canSubmit: Bool {
        viewModel.isBackendImplementedFlowComplete && isDeclarationAccepted
    }

    private let remainingItems = [
        "Address proof collection",
        "Income details",
        "E-signature",
        "Manual document review"
    ]

    var body: some View {
        List {
            Section {
                progressOverview
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                summaryRow(
                    title: "Borrower profile match",
                    value: viewModel.fullName,
                    detail: viewModel.dateOfBirth,
                    isComplete: !viewModel.fullName.isEmpty && !viewModel.dateOfBirth.isEmpty
                )
                summaryRow(
                    title: "Aadhaar KYC",
                    value: viewModel.isAadhaarVerified ? "OTP verified" : "Pending",
                    detail: viewModel.aadhaarReferenceID.isEmpty ? "Reference ID will appear after OTP start" : "Reference ID \(viewModel.aadhaarReferenceID)",
                    isComplete: viewModel.isAadhaarVerified
                )
                summaryRow(
                    title: "PAN KYC",
                    value: viewModel.isPanVerified ? viewModel.normalizedPAN : "Pending",
                    detail: "Consent + PAN verification",
                    isComplete: viewModel.isPanVerified
                )
                summaryRow(
                    title: "Borrower KYC status",
                    value: "Status + history ready",
                    detail: "Fetched after verification completes",
                    isComplete: viewModel.isBackendImplementedFlowComplete
                )
            } header: {
                Text("Completed checks")
            }

            Section {
                ForEach(remainingItems, id: \.self) { item in
                    HStack(spacing: 10) {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(DS.warning)

                        Text(item)
                            .foregroundStyle(DS.textPrimary)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Up next")
            } footer: {
                Text("You can continue with the rest of your profile after these identity checks.")
            }

            Section {
                declarationCheckbox
            } footer: {
                Text("Review your details before continuing.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("KYC Summary")
        .navigationBarTitleDisplayMode(.inline)
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
            bottomSubmitArea
        }
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Verification summary")
                    .font(.headline)
                    .foregroundStyle(DS.textPrimary)

                Text("Your Aadhaar and PAN checks are listed here, followed by the next profile steps.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
            }

            HStack(spacing: 8) {
                progressStep(title: "Profile")
                progressLine
                progressStep(title: "Aadhaar")
                progressLine
                progressStep(title: "PAN")
            }
        }
    }

    private func progressStep(title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DS.primary)

            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(DS.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressLine: some View {
        Rectangle()
            .fill(DS.primary.opacity(0.35))
            .frame(height: 1)
            .padding(.bottom, 20)
    }

    private func summaryRow(title: String, value: String, detail: String, isComplete: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isComplete ? DS.primary : Color(uiColor: .tertiaryLabel))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(DS.textPrimary)

                Text(value.isEmpty ? "Pending" : value)
                    .font(.subheadline)
                    .foregroundStyle(DS.primary)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    private var declarationCheckbox: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isDeclarationAccepted.toggle()
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isDeclarationAccepted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(isDeclarationAccepted ? DS.primary : Color(uiColor: .tertiaryLabel))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Details are ready")
                        .font(.body)
                        .foregroundStyle(DS.textPrimary)

                    Text("I confirm that these details are correct and I’m ready to continue.")
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var bottomSubmitArea: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Fetch borrower KYC status", isLoading: false, disabled: !canSubmit) {
                session.kycStatus = .pending
                path.append(KYCRoute.verifying)
            }

            if !canSubmit {
                Text(
                    isDeclarationAccepted
                    ? "Complete Aadhaar and PAN before fetching final status."
                    : "Confirm the declaration to continue."
                )
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
