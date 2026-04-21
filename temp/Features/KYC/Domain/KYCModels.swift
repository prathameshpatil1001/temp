// Features/KYC/Domain/KYCModels.swift
// LoanOS Borrower App
// Shared KYC domain models used across session and KYC flows.

import Foundation

public enum KYCStatus: String, Codable {
    case notStarted = "not_started"
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
}

struct BorrowerProfile {
    var firstName: String
    var lastName: String
    var dateOfBirth: Date
    var gender: BorrowerGender
    var addressLine1: String
    var city: String
    var state: String
    var pincode: String
}

enum BorrowerGender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    var id: String { rawValue }
}

enum BorrowerEmploymentType: String, CaseIterable, Identifiable {
    case salaried = "Salaried"
    case selfEmployed = "Self-employed"
    case businessOwner = "Business owner"
    case student = "Student"
    case retired = "Retired"

    var id: String { rawValue }
}

