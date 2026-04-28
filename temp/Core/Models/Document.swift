//
//  Document.swift
//  lms_project
//

import Foundation

// MARK: - XML Parse Result

struct XMLParseResult: Codable {
    var accountHolder: String
    var bankName: String
    var accountNumber: String
    var monthlyIncome: Double
    var averageBalance: Double
    var transactions: [Transaction]
    var totalCredits: Double
    var totalDebits: Double
}

// MARK: - Transaction

struct Transaction: Identifiable, Codable, Hashable {
    let id: String
    var date: Date
    var description: String
    var amount: Double
    var type: TransactionType
    
    enum TransactionType: String, Codable, Hashable {
        case credit
        case debit
    }
}
