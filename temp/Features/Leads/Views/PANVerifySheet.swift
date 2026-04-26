// PANVerifySheet.swift
// Direct Sales Team App

import SwiftUI

@available(iOS 18.0, *)
struct PANVerifySheet: View {
    @ObservedObject var viewModel: LoanApplicationViewModel
    let document: LeadDocument
    let onVerify: (IdentityVerificationData) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var panRegexValid: Bool {
        let pattern = "^[A-Z]{5}[0-9]{4}[A-Z]$"
        return viewModel.normalizedPAN.range(of: pattern, options: .regularExpression) != nil
    }
    
    var canVerify: Bool {
        viewModel.panConsentGranted && panRegexValid && !viewModel.isLoading
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PAN Verification")
                            .font(AppFont.bodyMedium())
                        Text("The borrower's details from Aadhaar will be matched against their PAN records.")
                            .font(AppFont.caption())
                            .foregroundColor(Color.textSecondary)
                    }
                }
                
                Section {
                    Toggle("I consent to PAN verification.", isOn: $viewModel.panConsentGranted)
                    
                    HStack {
                        Text("Name as per Aadhaar")
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(viewModel.aadhaarVerifiedName.isEmpty ? "Not available" : viewModel.aadhaarVerifiedName)
                            .foregroundColor(Color.textPrimary)
                    }
                    
                    HStack {
                        Text("Date of Birth")
                            .foregroundColor(Color.textSecondary)
                        Spacer()
                        Text(viewModel.aadhaarVerifiedDOB.isEmpty ? "Not available" : viewModel.aadhaarVerifiedDOB)
                            .foregroundColor(Color.textPrimary)
                    }
                    
                    TextField("PAN number", text: $viewModel.panNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: viewModel.panNumber) { _, value in
                            viewModel.panNumber = String(value.uppercased().prefix(10))
                        }
                    
                    if let error = viewModel.errorMessage, !error.isEmpty {
                        Text(error)
                            .font(AppFont.caption())
                            .foregroundColor(Color.statusRejected)
                    }
                }
            }
            .navigationTitle("Complete PAN Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verify") {
                        Task {
                            let success = await viewModel.verifyPAN()
                            if success {
                                onVerify(IdentityVerificationData(
                                    fullName: viewModel.aadhaarVerifiedName,
                                    documentNumber: viewModel.normalizedPAN,
                                    dateOfBirth: viewModel.aadhaarVerifiedDOB
                                ))
                                dismiss()
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
}
