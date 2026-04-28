//
//  AdminReportsViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

// MARK: - Report Models

struct ReportType: Identifiable, Hashable {
    let id: String
    let name: String
    let icon: String
    let description: String
}

struct ScheduledReport: Identifiable, Hashable {
    let id: String
    let reportName: String
    let frequency: String      // "Daily", "Weekly", "Monthly"
    let nextRun: Date
    let recipients: String
    var isActive: Bool
}

struct ReportRow: Identifiable, Hashable {
    let id: String
    let label: String
    let value: String
    let change: String         // e.g. "+5%" or "-2%"
    let isPositive: Bool
}

// MARK: - Admin Reports View Model

class AdminReportsViewModel: ObservableObject {

    @Published var selectedReportType: ReportType? = nil
    @Published var selectedBranch = "All Branches"
    @Published var selectedLoanType = "All Types"
    @Published var dateRangeLabel = "Last 30 Days"
    @Published var scheduledReports: [ScheduledReport] = []
    @Published var reportRows: [ReportRow] = []
    @Published var showExportAlert = false
    @Published var exportFormat = "PDF"
    @Published var isLoading = false

    @Published private(set) var applications: [LoanApplication] = []

    private let loanAPI = LoanAPI()

    let reportTypes: [ReportType] = [
        ReportType(id: "RPT-01", name: "Portfolio Overview",    icon: "chart.pie.fill",          description: "Total portfolio, disbursements, NPA summary"),
        ReportType(id: "RPT-02", name: "Collection Report",     icon: "indianrupeesign.circle",   description: "EMI recovery, DPD buckets, outstanding"),
        ReportType(id: "RPT-03", name: "Disbursement Report",   icon: "arrow.up.right.circle",    description: "Loans disbursed by branch & type"),
        ReportType(id: "RPT-04", name: "Risk & CIBIL Report",   icon: "exclamationmark.shield",   description: "CIBIL distribution, FOIR, fraud flags"),
        ReportType(id: "RPT-05", name: "SLA Compliance",        icon: "clock.badge.checkmark",    description: "SLA adherence by officer & branch")
    ]

    let branches   = ["All Branches", "Mumbai Central", "Delhi North", "Bangalore South"]
    let loanTypes  = ["All Types", "Home Loan", "Personal Loan", "Business Loan", "Vehicle Loan", "Education Loan"]
    let dateRanges = ["Last 7 Days", "Last 30 Days", "Last 90 Days", "This Year"]

    // MARK: - Load

    func loadData() {
        isLoading = true
        Task {
            defer { Task { @MainActor in self.isLoading = false } }
            guard #available(iOS 18.0, *) else { return }
            do {
                let list = try await loanAPI.listLoanApplications(limit: 500, offset: 0, branchID: nil, authorized: true)
                let mapped = list.map { LoanApplication.from(proto: $0) }
                await MainActor.run {
                    self.applications = mapped
                    self.scheduledReports = Self.mockScheduledReports()
                    self.selectedReportType = self.reportTypes.first
                    self.refreshReportData()
                }
            } catch {
                await MainActor.run {
                    self.applications = []
                    self.scheduledReports = Self.mockScheduledReports()
                    self.selectedReportType = self.reportTypes.first
                    self.refreshReportData()
                }
            }
        }
    }

    func refreshReportData() {
        guard let type = selectedReportType else { return }
        reportRows = Self.liveReportRows(for: type.id, from: applications)
    }

    // MARK: - Actions

    func exportReport(format: String) {
        exportFormat = format
        showExportAlert = true
    }

    func toggleScheduled(_ report: ScheduledReport) {
        if let idx = scheduledReports.firstIndex(where: { $0.id == report.id }) {
            scheduledReports[idx].isActive.toggle()
        }
    }

    // MARK: - Live (Backend-backed) report rows

    func normalizedReportID(_ uiReportID: String) -> String {
        // Admin UI uses legacy IDs (e.g., RPT-PERF). Map them to the report type IDs.
        switch uiReportID {
        case "RPT-PERF": return "RPT-01" // Portfolio Overview
        case "RPT-COLL": return "RPT-02" // Collection Report
        case "RPT-DISB": return "RPT-03" // Disbursement (proxy via approvals)
        case "RPT-RISK": return "RPT-04" // Risk & CIBIL
        case "RPT-NPA":  return "RPT-02" // Closest available aggregation until NPA backend exists
        default:
            return uiReportID
        }
    }

    static func liveReportRows(for reportId: String, from apps: [LoanApplication]) -> [ReportRow] {
        let total = apps.count
        let approved = apps.filter { $0.status == .approved || $0.status == .managerApproved }.count
        let pending = apps.filter { $0.status == .pending || $0.status == .underReview }.count
        let rejected = apps.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count

        let avgCibil: Int = {
            let scores = apps.map { $0.financials.cibilScore }.filter { $0 > 0 }
            guard !scores.isEmpty else { return 0 }
            return scores.reduce(0, +) / scores.count
        }()
        let avgFoirPct: Int = {
            let values: [Double] = apps.map { app in
                let raw = app.financials.foir
                if raw > 0 { return raw }
                return app.financials.dtiRatio * 100.0
            }
            guard !values.isEmpty else { return 0 }
            let sum = values.reduce(0, +)
            return Int((sum / Double(values.count)).rounded())
        }()
        let highRisk = apps.filter { ($0.financials.cibilScore > 0 && $0.financials.cibilScore < 650) || $0.financials.dtiRatio > 0.45 }.count
        let slaOverdue = apps.filter { $0.slaStatus == .overdue }.count
        let slaOnTimePct = total == 0 ? 0 : Int(((Double(total - slaOverdue) / Double(total)) * 100.0).rounded())

        switch reportId {
        case "RPT-01":
            return [
                ReportRow(id: "r1", label: "Total Applications", value: "\(total)", change: "—", isPositive: true),
                ReportRow(id: "r2", label: "Approved", value: "\(approved)", change: "—", isPositive: true),
                ReportRow(id: "r3", label: "Pending Review", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r4", label: "Rejected", value: "\(rejected)", change: "—", isPositive: rejected == 0)
            ]
        case "RPT-02":
            let overdue = apps.filter { $0.slaStatus == .overdue }.count
            return [
                ReportRow(id: "r1", label: "Overdue (SLA)", value: "\(overdue)", change: "—", isPositive: overdue == 0),
                ReportRow(id: "r2", label: "On-time SLA", value: "\(slaOnTimePct)%", change: "—", isPositive: slaOnTimePct >= 95),
                ReportRow(id: "r3", label: "Under Review", value: "\(apps.filter { $0.status == .underReview }.count)", change: "—", isPositive: true),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        case "RPT-03":
            // Disbursement not exposed on applications yet; proxy via approvals.
            return [
                ReportRow(id: "r1", label: "Approved (Proxy)", value: "\(approved)", change: "—", isPositive: true),
                ReportRow(id: "r2", label: "Pending", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r3", label: "Rejected", value: "\(rejected)", change: "—", isPositive: rejected == 0),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        case "RPT-04":
            return [
                ReportRow(id: "r1", label: "Avg CIBIL Score", value: "\(avgCibil)", change: "—", isPositive: avgCibil >= 700),
                ReportRow(id: "r2", label: "High Risk Apps", value: "\(highRisk)", change: "—", isPositive: highRisk == 0),
                ReportRow(id: "r3", label: "CIBIL < 650", value: "\(apps.filter { $0.financials.cibilScore > 0 && $0.financials.cibilScore < 650 }.count)", change: "—", isPositive: true),
                ReportRow(id: "r4", label: "Avg FOIR", value: "\(avgFoirPct)%", change: "—", isPositive: avgFoirPct <= 50)
            ]
        case "RPT-05":
            return [
                ReportRow(id: "r1", label: "On-Time SLA", value: "\(slaOnTimePct)%", change: "—", isPositive: slaOnTimePct >= 95),
                ReportRow(id: "r2", label: "SLA Breaches", value: "\(slaOverdue)", change: "—", isPositive: slaOverdue == 0),
                ReportRow(id: "r3", label: "Pending", value: "\(pending)", change: "—", isPositive: pending == 0),
                ReportRow(id: "r4", label: "Total", value: "\(total)", change: "—", isPositive: true)
            ]
        default:
            return []
        }
    }

    // MARK: - Preview + Export payloads

    func previewTable(for reportId: String) -> (columns: [String], rows: [[String]]) {
        _ = normalizedReportID(reportId)
        let columns = ["Application ID", "Borrower", "Amount", "Status", "Risk"]
        let rows: [[String]] = applications.prefix(25).map { app in
            let amount = app.loan.amount > 0 ? app.loan.amount.currencyFormatted : "—"
            let status = app.status.displayName
            let risk: String = {
                let cibil = app.financials.cibilScore
                let dti = app.financials.dtiRatio
                if (cibil > 0 && cibil < 650) || dti > 0.45 { return "High" }
                if (cibil > 0 && cibil < 700) || dti > 0.35 { return "Medium" }
                return "Low"
            }()
            return [app.id, app.borrower.name, amount, status, risk]
        }
        return (columns, rows)
    }

    func exportContent(for reportId: String, format: String) -> String {
        let rows = Self.liveReportRows(for: normalizedReportID(reportId), from: applications)
        let header = ["Label", "Value", "Change", "Positive"].joined(separator: ",")
        let body = rows.map { "\($0.label),\($0.value),\($0.change),\($0.isPositive)" }.joined(separator: "\n")
        return "\(header)\n\(body)\n"
    }

    // MARK: - Mock Data

    static func mockScheduledReports() -> [ScheduledReport] {
        [
            ScheduledReport(id: "SR-001", reportName: "Portfolio Overview",
                            frequency: "Weekly", nextRun: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                            recipients: "admin@gmail.com", isActive: true),
            ScheduledReport(id: "SR-002", reportName: "SLA Compliance",
                            frequency: "Daily",  nextRun: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                            recipients: "admin@gmail.com, manager@gmail.com", isActive: true)
        ]
    }

    static func mockReportRows(for reportId: String) -> [ReportRow] {
        switch reportId {
        case "RPT-01":
            return [
                ReportRow(id: "r1", label: "Total Portfolio",     value: "₹3.95 Cr", change: "+12%",  isPositive: true),
                ReportRow(id: "r2", label: "Disbursed (MTD)",     value: "₹72 L",    change: "+8%",   isPositive: true),
                ReportRow(id: "r3", label: "NPA Ratio",           value: "2.4%",     change: "-0.3%", isPositive: true),
                ReportRow(id: "r4", label: "Pending Approval",    value: "5",        change: "+2",    isPositive: false)
            ]
        case "RPT-02":
            return [
                ReportRow(id: "r1", label: "EMI Collected (MTD)", value: "₹14.2 L",  change: "+5%",   isPositive: true),
                ReportRow(id: "r2", label: "Overdue Loans",       value: "4",        change: "+1",    isPositive: false),
                ReportRow(id: "r3", label: "Total Outstanding",   value: "₹1.71 Cr", change: "-3%",   isPositive: true),
                ReportRow(id: "r4", label: "Recovery Rate",       value: "78%",      change: "+2%",   isPositive: true)
            ]
        case "RPT-03":
            return [
                ReportRow(id: "r1", label: "Home Loans",          value: "₹2.1 Cr",  change: "+15%",  isPositive: true),
                ReportRow(id: "r2", label: "Personal Loans",      value: "₹32 L",    change: "+3%",   isPositive: true),
                ReportRow(id: "r3", label: "Business Loans",      value: "₹50 L",    change: "-8%",   isPositive: false),
                ReportRow(id: "r4", label: "Vehicle Loans",       value: "₹15 L",    change: "+2%",   isPositive: true)
            ]
        case "RPT-04":
            return [
                ReportRow(id: "r1", label: "Avg CIBIL Score",     value: "728",      change: "+12",   isPositive: true),
                ReportRow(id: "r2", label: "High Risk Apps",      value: "3",        change: "+1",    isPositive: false),
                ReportRow(id: "r3", label: "Fraud Flags",         value: "2",        change: "0",     isPositive: true),
                ReportRow(id: "r4", label: "Avg FOIR",            value: "28%",      change: "-2%",   isPositive: true)
            ]
        case "RPT-05":
            return [
                ReportRow(id: "r1", label: "On-Time SLA",         value: "83%",      change: "+5%",   isPositive: true),
                ReportRow(id: "r2", label: "Overdue SLA",         value: "2",        change: "-1",    isPositive: true),
                ReportRow(id: "r3", label: "Avg TAT (days)",      value: "4.2",      change: "-0.8",  isPositive: true),
                ReportRow(id: "r4", label: "Escalations",         value: "1",        change: "0",     isPositive: true)
            ]
        default:
            return []
        }
    }
}
