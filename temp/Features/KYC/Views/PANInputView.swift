import SwiftUI

struct PANInputView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    private var panRegexValid: Bool {
        let pan = viewModel.normalizedPAN
        let pattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        return pan.range(of: pattern, options: .regularExpression) != nil
    }

    private var canVerifyPAN: Bool {
        viewModel.panConsentGranted && panRegexValid && !viewModel.isLoading
    }

    var body: some View {
        List {
            Section {
                Text("Verify your PAN")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section("PAN verification") {
                Toggle("I consent to PAN verification.", isOn: $viewModel.panConsentGranted)

                infoRow(title: "Name as per PAN", value: viewModel.fullName.isEmpty ? "Not available" : viewModel.fullName)
                infoRow(title: "Date of birth", value: viewModel.dateOfBirth.isEmpty ? "Not available" : viewModel.dateOfBirth)

                TextField("PAN number", text: $viewModel.panNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: viewModel.panNumber) { _, value in
                        viewModel.panNumber = String(value.uppercased().prefix(10))
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("PAN KYC")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryBtn(
                    title: viewModel.isLoading ? viewModel.loadingActionText : "Verify PAN",
                    isLoading: viewModel.isLoading,
                    disabled: !canVerifyPAN
                ) {
                    Task {
                        let ok = await viewModel.verifyPan()
                        if ok {
                            path.append(KYCRoute.panResult)
                        }
                    }
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(DS.warning)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(DS.textSecondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(DS.textPrimary)
        }
    }
}
