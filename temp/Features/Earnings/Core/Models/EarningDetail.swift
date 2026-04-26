//
//  EarningDetail.swift
//  DirectSalesTeamApp
//
//  Created by Apple on 17/04/26.
//


import Foundation

struct EarningDetail {
    let id: String
    let borrowerName: String
    let loanType: String
    let loanAmount: Double
    let commission: Double
    let commissionRate: Double
    let status: EarningPaymentStatus
    let disbursementDate: Date
    
    let breakdown: [CommissionComponent]
    let borrower: Borrower
    let timeline: [TimelineStep]
}

struct CommissionComponent {
    let title: String
    let amount: Double
}

struct Borrower {
    let name: String
    let phone: String
    let city: String
}

struct TimelineStep {
    let title: String
    let isCompleted: Bool
}

enum EarningPaymentStatus {
    case paid, pending, processing
}
