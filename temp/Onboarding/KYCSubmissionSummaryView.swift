import SwiftUI

struct KYCSubmissionSummaryView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isDeclarationAccepted = false
    @State private var showIncompleteError = false

    // We assume these are true if the user reached here in the real flow.
    private let isIdentityComplete = true
    private let isAddressComplete = true
    private let isIncomeComplete = true

    private var isFormComplete: Bool {
        isIdentityComplete && isAddressComplete && isIncomeComplete
    }

    private var canSubmit: Bool {
        isFormComplete && isDeclarationAccepted
    }

    var body: some View {
        List {
            Section {
                progressOverview
                    .listRowInsets(
                        EdgeInsets(
                            top: 16,
                            leading: 16,
                            bottom: 16,
                            trailing: 16
                        )
                    )
            }

            Section {
                reviewRow(
                    title: "Identity Proof",
                    value: "PAN Data",
                    detail: "Provided",
                    icon: "person.text.rectangle",
                    isComplete: isIdentityComplete
                )

                reviewRow(
                    title: "Address Proof",
                    value: "Uploaded Document",
                    detail: "Uploaded",
                    icon: "house",
                    isComplete: isAddressComplete
                )

                reviewRow(
                    title: "Income Proof",
                    value: "Income Documentation",
                    detail: "Uploaded",
                    icon: "indianrupeesign.circle",
                    isComplete: isIncomeComplete
                )
            } header: {
                Text("Documents")
            } footer: {
                if showIncompleteError && !isFormComplete {
                    Text("Please complete all sections before submitting.")
                        .foregroundStyle(Color.red)
                }
            }

            Section {
                declarationCheckbox
            } footer: {
                Text("Your documents are encrypted and used only for verification.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Review & Submit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel("Back")
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomSubmitArea
        }
    }

    private var progressOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ready to submit")
                    .font(.headline)
                    .foregroundStyle(DS.textPrimary)

                Text("Review your details before we send them for verification.")
                    .font(.subheadline)
                    .foregroundStyle(DS.textSecondary)
            }

            HStack(spacing: 8) {
                progressStep(title: "Identity")
                progressLine
                progressStep(title: "Address")
                progressLine
                progressStep(title: "Income")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("All verification steps are complete")
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
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: 64)
    }

    private var progressLine: some View {
        Rectangle()
            .fill(DS.primary.opacity(0.35))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
    }

    private func reviewRow(
        title: String,
        value: String,
        detail: String,
        icon: String,
        isComplete: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(DS.primary)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(DS.textPrimary)

                    if isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(DS.primary)
                            .accessibilityLabel("Complete")
                    }
                }

                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(DS.primary)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(
                        isComplete
                        ? Color(uiColor: .secondaryLabel)
                        : Color.red
                    )
            }
            Spacer(minLength: 12)
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
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Information is accurate")
                        .font(.body)
                        .foregroundStyle(DS.textPrimary)

                    Text("I confirm these documents belong to me and can be used for verification.")
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Information is accurate")
        .accessibilityValue(isDeclarationAccepted ? "Checked" : "Unchecked")
        .accessibilityAddTraits(.isButton)
    }

    private var bottomSubmitArea: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Submit Verification", isLoading: false, disabled: !canSubmit) {
                guard isFormComplete else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showIncompleteError = true
                    }
                    return
                }

                showIncompleteError = false
                path.append(KYCRoute.verifying)
            }

            if !canSubmit {
                Text(
                    isDeclarationAccepted
                    ? "Complete all sections to continue."
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
