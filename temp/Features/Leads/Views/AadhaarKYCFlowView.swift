// AadhaarKYCFlowView.swift
// Direct Sales Team App

import SwiftUI
import Combine

@available(iOS 18.0, *)
struct AadhaarKYCFlowView: View {
    @ObservedObject var viewModel: LoanApplicationViewModel
    let document: LeadDocument
    let onVerify: (IdentityVerificationData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var navPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navPath) {
            AadhaarEntryScreen(viewModel: viewModel, onNext: {
                navPath.append("OTP")
            }, onCancel: {
                dismiss()
            })
            .navigationDestination(for: String.self) { route in
                if route == "OTP" {
                    AadhaarOTPScreen(viewModel: viewModel, onVerify: {
                        onVerify(IdentityVerificationData(
                            fullName: viewModel.aadhaarVerifiedName,
                            documentNumber: viewModel.normalizedAadhaar,
                            dateOfBirth: viewModel.aadhaarVerifiedDOB
                        ))
                        dismiss()
                    })
                }
            }
        }
    }
}

@available(iOS 18.0, *)
struct AadhaarEntryScreen: View {
    @ObservedObject var viewModel: LoanApplicationViewModel
    let onNext: () -> Void
    let onCancel: () -> Void
    
    var canSendOTP: Bool {
        viewModel.aadhaarConsentGranted && viewModel.normalizedAadhaar.count == 12 && !viewModel.isLoading
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Aadhaar Verification")
                        .font(AppFont.bodyMedium())
                    Text("Enter the borrower's 12-digit Aadhaar number. An OTP will be sent to their linked mobile number.")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textSecondary)
                }
            }
            
            Section {
                Toggle("I consent to Aadhaar-based e-KYC verification under UIDAI guidelines.", isOn: $viewModel.aadhaarConsentGranted)
                
                TextField("12-digit Aadhaar number", text: $viewModel.aadhaarNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.aadhaarNumber) { _, value in
                        viewModel.aadhaarNumber = String(value.filter(\.isNumber).prefix(12))
                    }
                
                if let error = viewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(AppFont.caption())
                        .foregroundColor(Color.statusRejected)
                }
            }
        }
        .navigationTitle("Complete Aadhaar Verification")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Send OTP") {
                    Task {
                        let success = await viewModel.sendAadhaarOTP()
                        if success {
                            onNext()
                        }
                    }
                }
                .disabled(!canSendOTP)
            }
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView(viewModel.loadingMessage)
                    .padding()
                    .background(Color.surfacePrimary)
                    .cornerRadius(10)
            }
        }
    }
}

@available(iOS 18.0, *)
struct AadhaarOTPScreen: View {
    @ObservedObject var viewModel: LoanApplicationViewModel
    let onVerify: () -> Void
    
    @State private var timeRemaining = 30
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var canVerify: Bool {
        viewModel.aadhaarOTP.count == 6 && !viewModel.isLoading
    }
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Enter OTP")
                        .font(AppFont.bodyMedium())
                    Text("Please ask the borrower for the 6-digit OTP sent to their Aadhaar-linked mobile number.")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textSecondary)
                    if !viewModel.aadhaarReferenceID.isEmpty {
                        Text("Ref ID: \(viewModel.aadhaarReferenceID)")
                            .font(AppFont.caption())
                            .foregroundColor(Color.textTertiary)
                    }
                }
            }
            
            Section {
                TextField("6-digit OTP", text: $viewModel.aadhaarOTP)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.aadhaarOTP) { _, value in
                        viewModel.aadhaarOTP = String(value.filter(\.isNumber).prefix(6))
                    }
                
                Button(action: {
                    guard timeRemaining == 0, !viewModel.isLoading else { return }
                    timeRemaining = 30
                    Task {
                        _ = await viewModel.sendAadhaarOTP()
                    }
                }) {
                    Text(timeRemaining > 0 ? "Resend OTP in \(timeRemaining)s" : "Resend OTP")
                        .foregroundColor(timeRemaining > 0 ? Color.textSecondary : Color.brandBlue)
                }
                .disabled(timeRemaining > 0 || viewModel.isLoading)
                .onReceive(timer) { _ in
                    if timeRemaining > 0 {
                        timeRemaining -= 1
                    }
                }
                
                if let error = viewModel.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(AppFont.caption())
                        .foregroundColor(Color.statusRejected)
                }
            }
        }
        .navigationTitle("Aadhaar OTP")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Verify") {
                    Task {
                        let success = await viewModel.verifyAadhaarOTP()
                        if success {
                            onVerify()
                        }
                    }
                }
                .disabled(!canVerify)
            }
        }
        .overlay {
            if viewModel.isLoading {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView(viewModel.loadingMessage)
                    .padding()
                    .background(Color.surfacePrimary)
                    .cornerRadius(10)
            }
        }
    }
}
