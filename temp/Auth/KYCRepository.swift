// KYCRepository.swift
// lms_borrower/Auth
//
// Repository to handle KYC operations including submitting personal details,
// address proof, income details, and e-signatures.
// Since the gRPC API generated contracts do not yet contain KYC endpoints,
// these methods currently mock the network latency.

import Foundation

@available(iOS 18.0, *)
@MainActor
public final class KYCRepository: Sendable {
    
    public init() {}
    
    public func submitPersonalDetails(fullName: String, dob: String, panNumber: String) async throws {
        try await Task.sleep(nanoseconds: 1_200_000_000)
    }

    public func submitAddressDetails(
        addressLine1: String,
        city: String,
        state: String,
        postalCode: String
    ) async throws {
        try await Task.sleep(nanoseconds: 1_500_000_000)
    }
    
    public func submitIncomeDetails(employmentType: String, monthlyIncome: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
    
    public func submitESignature() async throws {
        try await Task.sleep(nanoseconds: 1_200_000_000)
    }
    
    public func pollKYCStatus() async throws -> KYCStatus {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        // Simulate an approval after the "pending/processing" delay
        return .approved
    }
}
