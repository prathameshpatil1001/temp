import SwiftUI

struct AadhaarInputView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    private var sanitizedAadhaar: String {
        viewModel.aadhaarNumber.filter(\.isNumber)
    }

    private var canSendOTP: Bool {
        viewModel.aadhaarConsentGranted && sanitizedAadhaar.count == 12 && !viewModel.isLoading
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Verify your Aadhaar", systemImage: "checkmark.shield.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DS.textPrimary)
                    Text("We will send a one-time password to your Aadhaar-linked mobile number.")
                        .font(.subheadline)
                        .foregroundStyle(DS.textSecondary)
                }
                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section("Aadhaar verification") {
                Toggle("I consent to Aadhaar-based e-KYC verification under UIDAI guidelines.", isOn: $viewModel.aadhaarConsentGranted)

                TextField("12-digit Aadhaar number", text: $viewModel.aadhaarNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.aadhaarNumber) { _, value in
                        viewModel.aadhaarNumber = String(value.filter(\.isNumber).prefix(12))
                    }

                if !sanitizedAadhaar.isEmpty {
                    Text(maskedAadhaar(sanitizedAadhaar))
                        .font(.footnote)
                        .foregroundStyle(DS.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Aadhaar KYC")
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
            VStack(spacing: 8) {
                PrimaryBtn(
                    title: viewModel.isLoading ? viewModel.loadingActionText : "Send OTP",
                    isLoading: viewModel.isLoading,
                    disabled: !canSendOTP
                ) {
                    Task {
                        let ok = await viewModel.sendAadhaarOTP()
                        if ok {
                            path.append(KYCRoute.aadhaarOTPVerify)
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

    private func maskedAadhaar(_ raw: String) -> String {
        guard raw.count == 12 else { return raw }
        let first = raw.prefix(4)
        let middle = "XXXX"
        let last = raw.suffix(4)
        return "\(first) \(middle) \(last)"
    }
}
