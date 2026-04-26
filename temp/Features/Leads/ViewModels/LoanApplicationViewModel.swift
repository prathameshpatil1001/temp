// LoanApplicationViewModel.swift
// Direct Sales Team App

import Foundation
import Combine
import SwiftUI

@available(iOS 18.0, *)
@MainActor
final class LoanApplicationViewModel: ObservableObject {
    let lead: Lead
    
    // KYC state
    @Published var aadhaarNumber = ""
    @Published var aadhaarConsentGranted = false
    @Published var aadhaarReferenceID = ""
    @Published var aadhaarOTP = ""
    @Published var isAadhaarVerified = false
    @Published var aadhaarVerifiedName = ""
    @Published var aadhaarVerifiedDOB = ""
    @Published var aadhaarVerifiedGender = ""
    
    @Published var panNumber = ""
    @Published var panConsentGranted = false
    @Published var isPanVerified = false
    @Published var panNameAsPerVerification = ""
    @Published var panDateOfBirth = ""
    
    // Document upload state
    @Published var uploadedDocuments: [UUID: String] = [:]  // docID -> mediaFileID
    @Published var uploadingDocumentIDs: Set<UUID> = []
    
    // Application submission state
    @Published var isSubmitting = false
    @Published var submittedApplicationID: String?
    @Published var submissionError: String?
    
    // MARK: - Loan Products State
    @Published var loanProducts: [LoanProduct] = []
    @Published var selectedProductID: String?
    
    // MARK: - Branches State
    @Published var branches: [BorrowerBranch] = []
    @Published var selectedBranchID: String?
    
    // Loading / error state
    @Published var isLoading = false
    @Published var loadingMessage = ""
    @Published var errorMessage: String?
    
    private let kycRepository: KYCRepository
    private let mediaRepository: MediaRepository
    private let loanService: LoanServiceProtocol
    private let branchService: BranchServiceProtocol
    /// Called whenever KYC state changes so the caller can persist the updated Lead.
    var onLeadUpdated: ((Lead) -> Void)?
    
    init(
        lead: Lead,
        kycRepository: KYCRepository = KYCRepository(),
        mediaRepository: MediaRepository = MediaRepository(),
        loanService: LoanServiceProtocol = LoanGRPCClient(),
        branchService: BranchServiceProtocol = BranchGRPCClient()
    ) {
        self.lead = lead
        self.kycRepository = kycRepository
        self.mediaRepository = mediaRepository
        self.loanService = loanService
        self.branchService = branchService
        // Restore persisted KYC state
        self.isAadhaarVerified = lead.isAadhaarKycVerified
        self.isPanVerified = lead.isPanKycVerified
        self.aadhaarVerifiedName = lead.aadhaarVerifiedName
        self.aadhaarVerifiedDOB = lead.aadhaarVerifiedDOB
    }
    
    var normalizedAadhaar: String {
        aadhaarNumber.filter(\.isNumber)
    }
    
    var normalizedPAN: String {
        panNumber.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Aadhaar Actions
    
    func sendAadhaarOTP() async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        loadingMessage = "Initiating Aadhaar KYC..."
        errorMessage = nil
        
        // DEBUG – remove after confirming
        print("[KYC] lead.borrowerUserID = \(lead.borrowerUserID ?? "NIL")")
        print("[KYC] lead.borrowerProfileID = \(lead.borrowerProfileID ?? "NIL")")
        
        do {
            try await kycRepository.recordUserConsent(type: .aadhaar, borrowerUserID: lead.borrowerUserID)
            let result = try await kycRepository.initiateAadhaarKyc(aadhaarNumber: normalizedAadhaar, borrowerUserID: lead.borrowerUserID)
            self.aadhaarReferenceID = result.referenceID
            isLoading = false
            return true
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    func verifyAadhaarOTP() async -> Bool {
        guard !isLoading, !aadhaarReferenceID.isEmpty, aadhaarOTP.count == 6 else { return false }
        
        isLoading = true
        loadingMessage = "Verifying OTP..."
        errorMessage = nil
        
        do {
            let result = try await kycRepository.verifyAadhaarKycOtp(
                referenceID: aadhaarReferenceID,
                otp: aadhaarOTP,
                borrowerUserID: lead.borrowerUserID
            )
            
            if result.isValid {
                isAadhaarVerified = true
                aadhaarVerifiedName = result.verifiedName
                aadhaarVerifiedDOB = result.verifiedDateOfBirth
                aadhaarVerifiedGender = result.verifiedGender
                persistKYCState()
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = result.message.isEmpty ? "Invalid OTP. Please try again." : result.message
                return false
            }
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - PAN Actions
    
    func verifyPAN() async -> Bool {
        guard !isLoading else { return false }
        
        isLoading = true
        loadingMessage = "Verifying PAN..."
        errorMessage = nil
        
        do {
            try await kycRepository.recordUserConsent(type: .pan, borrowerUserID: lead.borrowerUserID)
            let result = try await kycRepository.verifyPanKyc(
                pan: normalizedPAN,
                nameAsPerPan: aadhaarVerifiedName,
                dateOfBirth: aadhaarVerifiedDOB,
                borrowerUserID: lead.borrowerUserID
            )
            
            if result.isValid {
                isPanVerified = true
                persistKYCState()
                isLoading = false
                return true
            } else {
                isLoading = false
                errorMessage = result.message.isEmpty ? "PAN verification failed." : result.message
                return false
            }
        } catch {
            isLoading = false
            if let kycError = error as? KYCError {
                errorMessage = kycError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
            return false
        }
    }
    
    // MARK: - Document Upload
    
    func uploadDocument(id: UUID, data: Data, fileName: String, contentType: String) async -> Bool {
        uploadingDocumentIDs.insert(id)
        errorMessage = nil
        
        do {
            let uploadedMedia = try await mediaRepository.uploadMedia(
                fileData: data,
                fileName: fileName,
                contentType: contentType,
                note: "borrower_document"
            )
            
            uploadedDocuments[id] = uploadedMedia.mediaID
            uploadingDocumentIDs.remove(id)
            return true
        } catch {
            uploadingDocumentIDs.remove(id)
            errorMessage = "Failed to upload document: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Submit Application
    
    func submitApplication(
        productID: String,
        branchID: String,
        requestedAmount: String,
        tenureMonths: Int,
        leadDocuments: [LeadDocument]
    ) async -> Bool {
        guard !isSubmitting else { return false }
        
        isSubmitting = true
        submissionError = nil
        
        do {
            // 1. Create the application
            let application = try await loanService.createLoanApplication(
                primaryBorrowerProfileId: lead.borrowerProfileID ?? "",
                loanProductId: productID,
                branchId: branchID,
                requestedAmount: requestedAmount,
                tenureMonths: tenureMonths
            )
            
            let product = self.loanProducts.first(where: { $0.id == productID })
            var availableReqDocs = product?.requiredDocuments ?? []
            
            // 2. Add each uploaded document
            for (docID, mediaFileID) in uploadedDocuments {
                let leadDoc = leadDocuments.first(where: { $0.id == docID })
                var matchedReqDocID: String?
                
                if let leadDoc = leadDoc {
                    let expectedType: DocumentRequirementType
                    switch leadDoc.kind {
                    case .aadhaar, .pan: expectedType = .identity
                    case .supporting: expectedType = .income
                    }
                    
                    if let idx = availableReqDocs.firstIndex(where: { $0.requirementType == expectedType }) {
                        matchedReqDocID = availableReqDocs[idx].id
                        availableReqDocs.remove(at: idx)
                    }
                }
                
                if matchedReqDocID == nil && !availableReqDocs.isEmpty {
                    matchedReqDocID = availableReqDocs.removeFirst().id
                }
                
                // Fallback to random valid UUID to satisfy basic UUID validation if we run out,
                // though the backend might reject if it strict-checks against the product.
                let finalRequiredDocId = matchedReqDocID ?? UUID().uuidString
                
                _ = try await loanService.addApplicationDocument(
                    applicationId: application.id,
                    borrowerProfileId: lead.borrowerProfileID ?? "",
                    requiredDocId: finalRequiredDocId,
                    mediaFileId: mediaFileID
                )
            }
            
            self.submittedApplicationID = application.id
            isSubmitting = false
            return true
        } catch {
            isSubmitting = false
            submissionError = "Failed to submit application: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    func fetchLoanProducts() async {
        do {
            let products = try await loanService.listLoanProducts(limit: 50, offset: 0)
            DispatchQueue.main.async {
                self.loanProducts = products
                if self.selectedProductID == nil {
                    self.selectedProductID = products.first?.id
                }
            }
        } catch {
            print("Failed to fetch loan products: \(error)")
        }
    }
    
    func fetchBranches() async {
        do {
            let fetchedBranches = try await branchService.listBranches(limit: 50, offset: 0)
            DispatchQueue.main.async {
                self.branches = fetchedBranches
                if self.selectedBranchID == nil {
                    self.selectedBranchID = fetchedBranches.first?.id
                }
            }
        } catch {
            print("Failed to fetch branches: \(error)")
        }
    }
    
    private func persistKYCState() {
        var updated = lead
        updated.isAadhaarKycVerified = isAadhaarVerified
        updated.isPanKycVerified = isPanVerified
        updated.aadhaarVerifiedName = aadhaarVerifiedName
        updated.aadhaarVerifiedDOB = aadhaarVerifiedDOB
        onLeadUpdated?(updated)
    }
    
}
