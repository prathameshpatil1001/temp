// Features/KYC/Views/KYCFlowController.swift
// LoanOS Borrower App
// Manages the multi-step navigation sequence for KYC onboarding.

import SwiftUI

public enum KYCRoute: Hashable {
    case aadhaarInput
    case aadhaarOTPVerify
    case panInput
    case panResult
    case incomeDocuments
    case livePhoto
    case eSignature
    case review
    case submissionSummary
    case verifying
    case verificationSuccess
    case verificationFailed
}

@available(iOS 18.0, *)
public struct KYCFlowController: View {
    @State private var path = NavigationPath()
    @StateObject private var viewModel: KYCViewModel
    @State private var didRestoreProgress = false
    
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    public init(fullName: String = "", dateOfBirth: String = "") {
        _viewModel = StateObject(wrappedValue: KYCViewModel(fullName: fullName, dateOfBirth: dateOfBirth))
    }

    public var body: some View {
        NavigationStack(path: $path) {
            AadhaarInputView(path: $path)
                .environmentObject(viewModel)
                .navigationDestination(for: KYCRoute.self) { route in
                    switch route {
                    case .aadhaarInput:
                        AadhaarInputView(path: $path)
                            .environmentObject(viewModel)
                    case .aadhaarOTPVerify:
                        AadhaarOTPVerifyView(path: $path)
                            .environmentObject(viewModel)
                    case .panInput:
                        PANInputView(path: $path)
                            .environmentObject(viewModel)
                    case .panResult:
                        PANResultView(path: $path)
                            .environmentObject(viewModel)
                    case .incomeDocuments:
                        IncomeDetailsView(path: $path)
                            .environmentObject(viewModel)
                    case .livePhoto:
                        LivePhotoCaptureView(path: $path)
                            .environmentObject(viewModel)
                    case .eSignature:
                        ESignatureView(path: $path)
                            .environmentObject(viewModel)
                    case .review:
                        ReviewDocumentView(path: $path)
                            .environmentObject(viewModel)
                    case .submissionSummary:
                        KYCSubmissionSummaryView(path: $path)
                            .environmentObject(viewModel)
                    case .verifying:
                        KYCVerifyingView(path: $path)
                            .environmentObject(viewModel)
                    case .verificationSuccess:
                        KYCVerificationSuccessView(path: $path)
                            .environmentObject(viewModel)
                    case .verificationFailed:
                        KYCVerificationFailedView(path: $path)
                            .environmentObject(viewModel)
                    }
                }
        }
        // When KYC is finished, we close the sheet/fullScreenCover.
        // It updates the session.kycStatus to approved inside the verifying view.
        .onChange(of: session.kycStatus) { _, newStatus in
            if newStatus == .approved {
                dismiss() // Close KYC flow and return to Home
            }
        }
        .onAppear {
            AnalyticsManager.shared.logEvent(.kycStarted)
            guard !didRestoreProgress else { return }
            didRestoreProgress = true
            Task {
                await restoreInitialRoute()
            }
        }
        .onChange(of: session.pendingKYCRoute) { _, newRoute in
            if let route = newRoute {
                path.append(route)
                session.pendingKYCRoute = nil
            }
        }
    }

    @MainActor
    private func restoreInitialRoute() async {
        if let pending = session.pendingKYCRoute {
            path.append(pending)
            session.pendingKYCRoute = nil
            return
        }

        guard let backendStatus = await viewModel.restoreKYCProgressFromBackend() else { return }
        session.kycStatus = backendStatus

        if viewModel.isAadhaarVerified && !viewModel.isPanVerified {
            path.append(KYCRoute.panInput)
            return
        }

        if backendStatus == .approved {
            dismiss()
        }
    }
}
