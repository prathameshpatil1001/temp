//
//  User.swift
//  lms_project
//

import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var email: String
    var role: UserRole
    var branchID: String?
    var branch: String
    var phone: String
    var isActive: Bool
    var joinedAt: Date
    var employeeCode: String?
    
    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
