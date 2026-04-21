// Features/KYC/Views/KYCFlowController.swift
// LoanOS Borrower App
// Manages the multi-step navigation sequence for KYC onboarding.

import SwiftUI

public enum KYCRoute: Hashable {
    case completeProfile
    case personalDetails
    case addressProof
    case incomeDetails
    case eSignature
    case review
    case submissionSummary
    case verifying
    case verifyIdentity
    case verificationSuccess
    case verificationFailed
}

@available(iOS 18.0, *)
public struct KYCFlowController: View {
    @State private var path = NavigationPath()
    @StateObject private var viewModel = KYCViewModel()
    
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack(path: $path) {
            CompleteProfileView(path: $path)
                .navigationDestination(for: KYCRoute.self) { route in
                    switch route {
                    case .completeProfile:
                        CompleteProfileView(path: $path)
                    case .personalDetails:
                        PersonalDetailsView(path: $path)
                            .environmentObject(viewModel)
                    case .addressProof:
                        AddressProofView(path: $path)
                            .environmentObject(viewModel)
                    case .incomeDetails:
                        IncomeDetailsView(path: $path)
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
                    case .verifyIdentity:
                        VerifyIdentityView(path: $path)
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
            if let pending = session.pendingKYCRoute {
                path.append(pending)
                session.pendingKYCRoute = nil
            }
        }
        .onChange(of: session.pendingKYCRoute) { _, newRoute in
            if let route = newRoute {
                path.append(route)
                session.pendingKYCRoute = nil
            }
        }
    }
}
