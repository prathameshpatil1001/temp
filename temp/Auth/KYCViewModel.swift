// KYCViewModel.swift
// lms_borrower/Auth
//
// Manages state for the multi-step form, document uploads, and submission process.

import SwiftUI
import Combine

@available(iOS 18.0, *)

@MainActor
public final class KYCViewModel: ObservableObject {

    public enum State {
        case idle
        case loading(String)
        case error(String)
        case success
    }

    @Published public var state: State = .idle
    @Published public var errorMessage: String?
    
    // Personal Details Forms
    @Published public var fullName = ""
    @Published public var dateOfBirth = ""
    @Published public var panNumber = ""
    
    // Address Details Forms
    @Published public var currentAddress = ""
    @Published public var city = ""
    @Published public var stateName = ""
    @Published public var postalCode = ""
    
    // Income Details Forms
    @Published public var selectedEmploymentStatus = "Salaried"
    @Published public var employerName = ""
    @Published public var netMonthlyIncome = ""

    private let kycRepository: KYCRepository

    public init(kycRepository: KYCRepository? = nil) {
        self.kycRepository = kycRepository ?? KYCRepository()
    }

    public func submitPersonalDetails() async -> Bool {
        state = .loading("Submitting details...")
        do {
            try await kycRepository.submitPersonalDetails(
                fullName: fullName,
                dob: dateOfBirth,
                panNumber: panNumber
            )
            state = .idle
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func submitAddressProof() async -> Bool {
        state = .loading("Submitting address document...")
        do {
            try await kycRepository.submitAddressDetails(
                addressLine1: currentAddress,
                city: city,
                state: stateName,
                postalCode: postalCode
            )
            state = .idle
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func submitIncomeDetails() async -> Bool {
        state = .loading("Submitting income verification...")
        do {
            try await kycRepository.submitIncomeDetails(
                employmentType: selectedEmploymentStatus,
                monthlyIncome: netMonthlyIncome
            )
            state = .idle
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func submitESignature() async -> Bool {
        state = .loading("Broadcasting E-Signature...")
        do {
            try await kycRepository.submitESignature()
            state = .idle
            return true
        } catch {
            self.state = .error(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func pollKYCStatus() async -> KYCStatus {
        do {
            return try await kycRepository.pollKYCStatus()
        } catch {
            return .rejected
        }
    }
    
    public var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    public var loadingActionText: String {
        if case .loading(let text) = state { return text }
        return "Loading..."
    }
}
