import SwiftUI
import Combine

struct AadhaarOTPVerifyView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    @State private var otp = ""
    @State private var timeRemaining = 30
    @FocusState private var focused: Bool

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var canVerify: Bool {
        otp.count == 6 && !viewModel.isLoading
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter Aadhaar OTP")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(DS.textPrimary)

                        if !viewModel.aadhaarReferenceID.isEmpty {
                            Text("Reference ID: \(viewModel.aadhaarReferenceID)")
                                .font(.footnote)
                                .foregroundStyle(DS.textSecondary)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }

                Section("OTP") {
                    OTPBoxRow(otp: $otp, focused: $focused)

                    Button {
                        guard timeRemaining == 0, !viewModel.isLoading else { return }
                        timeRemaining = 30
                        Task {
                            _ = await viewModel.sendAadhaarOTP()
                        }
                    } label: {
                        Text(timeRemaining > 0 ? "Resend OTP in \(timeRemaining)s" : "Resend OTP")
                            .foregroundStyle(timeRemaining > 0 ? DS.textSecondary : DS.primary)
                    }
                    .disabled(timeRemaining > 0 || viewModel.isLoading)
                    .onReceive(timer) { _ in
                        if timeRemaining > 0 {
                            timeRemaining -= 1
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))

            VStack(spacing: 8) {
                PrimaryBtn(
                    title: viewModel.isLoading ? viewModel.loadingActionText : "Verify",
                    isLoading: viewModel.isLoading,
                    disabled: !canVerify
                ) {
                    viewModel.aadhaarOTP = otp
                    Task {
                        let ok = await viewModel.verifyAadhaarOTP()
                        if ok {
                            path.append(KYCRoute.panInput)
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
        .navigationTitle("Aadhaar OTP")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            focused = true
            otp = viewModel.aadhaarOTP
        }
    }
}
