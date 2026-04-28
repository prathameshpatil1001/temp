//
//  UserStore.swift
//  lms_project
//
//  Singleton in-memory store for user credentials.
//

import Foundation
import Combine

// MARK: - Stored Credential

struct StoredCredential: Identifiable {
    let id: String
    let email: String
    let password: String
    let phone: String
    let role: UserRole
}

// MARK: - User Store

final class UserStore: ObservableObject {

    static let shared = UserStore()

    @Published private(set) var credentials: [StoredCredential] = []

    private init() {
        // Admin
        credentials.append(StoredCredential(
            id: "ADM-001",
            email: "admin@gmail.com",
            password: "admin",
            phone: "+91-9876543212",
            role: .admin
        ))
        // Loan Officer
        credentials.append(StoredCredential(
            id: "LO-001",
            email: "loan@gmail.com",
            password: "loan",
            phone: "+91-9876543210",
            role: .loanOfficer
        ))
        credentials.append(StoredCredential(
            id: "LO-002",
            email: "neha.kapoor@bank.com",
            password: "loan",
            phone: "+91-9876543213",
            role: .loanOfficer
        ))
        // Manager
        credentials.append(StoredCredential(
            id: "MGR-001",
            email: "manager@gmail.com",
            password: "manager",
            phone: "+91-9876543211",
            role: .manager
        ))
    }

    // MARK: - Authenticate

    func authenticate(email: String, password: String) -> StoredCredential? {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        return credentials.first {
            $0.email.lowercased() == e && $0.password == p
        }
    }

    // MARK: - Add / Remove

    func addCredential(_ credential: StoredCredential) {
        if !credentials.contains(where: { $0.email.lowercased() == credential.email.lowercased() }) {
            credentials.append(credential)
        }
    }

    func removeCredential(id: String) {
        credentials.removeAll { $0.id == id }
    }
}
