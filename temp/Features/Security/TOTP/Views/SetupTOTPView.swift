// Views/Home/SetupTOTPView.swift
// LoanOS — Borrower App
// Authenticator setup screen (Post-Login).

import SwiftUI

struct SetupTOTPView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var session: SessionStore

    var onCompleted: (() -> Void)? = nil

    @State private var appeared = false
    @State private var copied = false

    @StateObject private var viewModel = SetupTOTPViewModel()
    @State private var code = ""
    @FocusState private var focused: Bool

    private var canVerify: Bool {
        code.count == 6
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    headerSection
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(.easeOut(duration: 0.35), value: appeared)

                    if viewModel.isLoading && viewModel.currentProvisioningURI == nil {
                        ProgressView("Generating secure code...")
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let uri = viewModel.currentProvisioningURI,
                              case .secretReceived(let secret, _) = viewModel.state {
                        
                        qrCard(uri: uri)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 16)
                            .animation(.easeOut(duration: 0.42).delay(0.04), value: appeared)

                        manualKeySection(secret: secret)
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                            .animation(.easeOut(duration: 0.48).delay(0.08), value: appeared)

                        Divider().padding(.vertical, 8)

                        verifySection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 22)
                            .animation(.easeOut(duration: 0.50).delay(0.10), value: appeared)

                        actionSection
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(.easeOut(duration: 0.54).delay(0.12), value: appeared)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
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
        .alert("Error", isPresented: .init(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK", role: .cancel) { }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
        .task {
            appeared = true
            await viewModel.fetchSecret()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.82))
                        .background(.ultraThinMaterial, in: Circle())

                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                }
                .frame(width: 42, height: 42)
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Set up authenticator")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            Text("Scan this code in your authenticator app to finish securing your account.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)
                .lineSpacing(3)
        }
    }

    private func qrCard(uri: String) -> some View {
        VStack(spacing: 18) {
            if let qr = TOTPProvider.generateQRCode(from: uri) {
                qr
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 196, height: 196)
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                Text("Failed to generate QR Code")
                    .frame(width: 196, height: 196)
            }

            Text("Open Google Authenticator, 1Password, or another compatible app and scan the code.")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.white.opacity(0.82))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 14, x: 0, y: 6)
    }

    private func manualKeySection(secret: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manual key")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.textSecondary)

            Button {
                UIPasteboard.general.string = secret
                copied = true

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    copied = false
                }
            } label: {
                HStack(spacing: 12) {
                    Text(formatManualKey(secret))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer()

                    Text(copied ? "Copied" : "Copy")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DS.primary)
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(.white.opacity(0.82))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.9), lineWidth: 1)
                )
            }
            .buttonStyle(TapScale())
        }
    }

    private var verifySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verify Setup")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DS.textSecondary)
            
            Text("Enter the 6-digit code generated by your app")
                .font(.system(size: 14))
                .foregroundColor(DS.textSecondary)
            
            OTPBoxRow(otp: $code, focused: $focused)
                .disabled(viewModel.isLoading)
        }
    }

    private var actionSection: some View {
        PrimaryBtn(
            title: viewModel.isLoading ? viewModel.loadingActionText : "Finish Setup",
            disabled: !canVerify || viewModel.isLoading
        ) {
            focused = false
            Task {
                if await viewModel.verify(code: code) {
                    onCompleted?()
                    dismiss()
                }
            }
        }
    }

    private func formatManualKey(_ manualKey: String) -> String {
        stride(from: 0, to: manualKey.count, by: 4).map { index in
            let start = manualKey.index(manualKey.startIndex, offsetBy: index)
            let end = manualKey.index(start, offsetBy: min(4, manualKey.count - index))
            return String(manualKey[start..<end])
        }
        .joined(separator: " ")
    }
}
