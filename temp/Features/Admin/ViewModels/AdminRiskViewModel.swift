//
//  AdminRiskViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Risk Analytics Models

struct FraudFlag: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let borrowerName: String
    let reason: String
    let severity: RiskLevel
    let flaggedAt: Date
}

struct DecisionRecord: Identifiable, Hashable {
    let id: String
    let applicationId: String
    let borrowerName: String
    let decision: String    // "Approved" / "Rejected" / "Escalated"
    let reason: String
    let score: Int          // 0–100
    let decidedAt: Date
}

struct RiskBucket: Identifiable {
    let id = UUID()
    let label: String       // "CIBIL < 650", "650-749", "750+"
    let count: Int
    let color: Color
}

// MARK: - Admin Risk View Model

class AdminRiskViewModel: ObservableObject {

    @Published var applications: [LoanApplication] = []
    @Published var fraudFlags: [FraudFlag] = []
    @Published var decisions: [DecisionRecord] = []
    @Published var stressTestEnabled = false
    @Published var isLoading = false
    private let loanAPI = LoanAPI()

    // MARK: - KPIs

    var avgCIBIL: Int {
        guard !applications.isEmpty else { return 0 }
        return applications.map { $0.financials.cibilScore }.reduce(0, +) / applications.count
    }

    var avgFOIR: Double {
        guard !applications.isEmpty else { return 0 }
        return applications.map { $0.financials.dtiRatio }.reduce(0, +) / Double(applications.count)
    }

    var approvalRate: Double {
        guard !applications.isEmpty else { return 0 }
        let approved = applications.filter { $0.status == .approved }.count
        return Double(approved) / Double(applications.count)
    }

    var fraudFlagCount: Int { fraudFlags.count }

    // MARK: - CIBIL Buckets

    var cibilBuckets: [RiskBucket] {
        let low   = applications.filter { $0.financials.cibilScore >= 750 }.count
        let mid   = applications.filter { $0.financials.cibilScore >= 650 && $0.financials.cibilScore < 750 }.count
        let poor  = applications.filter { $0.financials.cibilScore < 650 }.count
        return [
            RiskBucket(label: "750+",     count: low,  color: Theme.Colors.success),
            RiskBucket(label: "650–749",  count: mid,  color: Theme.Colors.warning),
            RiskBucket(label: "< 650",    count: poor, color: Theme.Colors.critical)
        ]
    }

    // MARK: - Income Discrepancy

    var incomeDiscrepancies: [LoanApplication] {
        applications.filter { $0.financials.dtiRatio > 0.40 }
    }

    // MARK: - Load

    func loadData() {
        isLoading = true
        Task {
            defer { Task { @MainActor in self.isLoading = false } }
            guard #available(iOS 18.0, *) else { return }
            do {
                let list = try await loanAPI.listLoanApplications(limit: 200, offset: 0, branchID: nil, authorized: true)
                let mapped = list.map { LoanApplication.from(proto: $0) }
                await MainActor.run {
                    self.applications = mapped
                    self.fraudFlags = Self.deriveFraudFlags(from: mapped)
                    self.decisions = Self.deriveDecisions(from: mapped)
                }
            } catch {
                // Keep view usable even when backend is unavailable.
                await MainActor.run {
                    self.applications = []
                    self.fraudFlags = []
                    self.decisions = []
                }
            }
        }
    }

    // MARK: - Derived Risk Signals (Backend-backed)

    static func deriveFraudFlags(from apps: [LoanApplication]) -> [FraudFlag] {
        // Backend does not expose fraud flags yet; derive lightweight signals from app fields.
        // Keep conservative: only flag clear policy risk patterns.
        let now = Date()
        return apps.compactMap { app in
            let cibil = app.financials.cibilScore
            let dti = app.financials.dtiRatio
            let foir = app.financials.foir > 0 ? (app.financials.foir / 100.0) : dti
            let reasons: [String] = [
                cibil > 0 && cibil < 650 ? "Low CIBIL (\(cibil))" : nil,
                dti > 0.40 ? "DTI high (\(Int((dti * 100).rounded()))%)" : nil,
                foir > 0.50 ? "FOIR above policy (\(Int((foir * 100).rounded()))%)" : nil
            ].compactMap { $0 }

            guard !reasons.isEmpty else { return nil }
            let severity: RiskLevel = (cibil > 0 && cibil < 600) || dti > 0.55 ? .high : .medium
            return FraudFlag(
                id: "FF-\(app.id.prefix(8))",
                applicationId: app.id,
                borrowerName: app.borrower.name,
                reason: reasons.joined(separator: " · "),
                severity: severity,
                flaggedAt: now
            )
        }
    }

    static func deriveDecisions(from apps: [LoanApplication]) -> [DecisionRecord] {
        // Derived from status transitions only (until backend exposes a decision/audit feed).
        let decidedApps = apps.filter { $0.status == .approved || $0.status == .managerApproved || $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }
        return decidedApps.map { app in
            let decision: String = {
                switch app.status {
                case .approved, .managerApproved: return "Approved"
                case .rejected, .managerRejected, .officerRejected: return "Rejected"
                default: return "Escalated"
                }
            }()
            let cibil = app.financials.cibilScore
            let dti = app.financials.dtiRatio
            let cibilPart = (Double(max(0, cibil - 300)) / 600.0) * 70.0
            let dtiPart = max(0.0, 0.50 - dti) * 60.0
            let score = max(0, min(100, Int((cibilPart + dtiPart).rounded())))
            let reason = "CIBIL \(cibil) · DTI \(Int((dti * 100).rounded()))%"
            return DecisionRecord(
                id: "DEC-\(app.id.prefix(8))",
                applicationId: app.id,
                borrowerName: app.borrower.name,
                decision: decision,
                reason: reason,
                score: score,
                decidedAt: app.createdAt
            )
        }
    }
}
