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

struct AdminPDFReportRow {
    let applicationId: String
    let borrowerName: String
    let borrowerPhone: String
    let borrowerEmail: String
    let branch: String
    let loanType: String
    let amount: Double
    let tenureMonths: Int
    let interestRate: Double
    let emi: Double
    let status: String
    let risk: String
    let slaStatus: String
    let createdAt: Date
}

struct AdminPDFReportSummary {
    let total: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let totalValue: Double
    let avgLoanSize: Double
    let highRisk: Int
}

struct AdminPDFReportPayload {
    let reportName: String
    let filters: String
    let rows: [AdminPDFReportRow]
    let summary: AdminPDFReportSummary
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
    @Published var reportError: String? = nil

    // MARK: - Backend Report Responses
    @Published var portfolioReport: PortfolioPerformanceResponse? = nil
    @Published var disbursementReport: DisbursementResponse? = nil
    @Published var collectionReport: CollectionResponse? = nil
    @Published var npaReport: NPAResponse? = nil
    @Published var riskCreditReport: RiskCreditResponse? = nil

    @Published private(set) var applications: [LoanApplication] = []

    private let loanAPI = LoanAPI()

    // Active filter state (set by View, consumed by loadReport)
    var activeDateRange: String = "Last 30 Days"
    var activeLoanType: String = "All Types"
    var activeRegion: String = "All Regions"
    var activeStatus: String = "All"

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

            // Load applications (fallback data source) in parallel with reports
            async let appsTask: Void = loadApplications()
            async let reportsTask: Void = loadAllReports()

            _ = try await appsTask
            _ = try await reportsTask

            await MainActor.run {
                self.scheduledReports = Self.mockScheduledReports()
                self.selectedReportType = self.reportTypes.first
                self.refreshReportData()
            }
        }
    }

    func refreshReportData(for reportId: String? = nil) {
        let id = reportId ?? selectedReportType?.id ?? "RPT-01"
        reportRows = reportRowsFromBackend(for: id)
    }

    // MARK: - Backend Report Loading

    func loadAllReports() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPortfolioReport() }
            group.addTask { await self.loadDisbursementReport() }
            group.addTask { await self.loadCollectionReport() }
            group.addTask { await self.loadNPAReport() }
            group.addTask { await self.loadRiskCreditReport() }
        }
    }

    func loadPortfolioReport() async {
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.portfolioPerformance(query: query)
            await MainActor.run {
                self.portfolioReport = response
                self.reportError = nil
                self.refreshReportData()
            }
        } catch {
            await MainActor.run {
                self.reportError = error.localizedDescription
            }
        }
    }

    func loadDisbursementReport() async {
        do {
            let query = buildReportQuery(status: "DISBURSED")
            let response = try await ReportsAPI.disbursement(query: query)
            await MainActor.run {
                self.disbursementReport = response
                self.reportError = nil
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadCollectionReport() async {
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.collection(query: query)
            await MainActor.run {
                self.collectionReport = response
                self.reportError = nil
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadNPAReport() async {
        do {
            let query = buildReportQuery(status: "NPA")
            let response = try await ReportsAPI.npa(query: query)
            await MainActor.run {
                self.npaReport = response
                self.reportError = nil
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    func loadRiskCreditReport() async {
        do {
            let query = buildReportQuery()
            let response = try await ReportsAPI.riskCredit(query: query)
            await MainActor.run {
                self.riskCreditReport = response
                self.reportError = nil
            }
        } catch {
            await MainActor.run { self.reportError = error.localizedDescription }
        }
    }

    /// Reload a single report by its UI report ID (e.g. "RPT-PERF")
    func reloadReport(reportId: String) {
        Task {
            switch reportId {
            case "RPT-PERF", "RPT-01": await loadPortfolioReport()
            case "RPT-DISB", "RPT-03": await loadDisbursementReport()
            case "RPT-COLL", "RPT-02": await loadCollectionReport()
            case "RPT-NPA":            await loadNPAReport()
            case "RPT-RISK", "RPT-04": await loadRiskCreditReport()
            default: break
            }
        }
    }

    // MARK: - Query Builder

    func buildReportQuery(status overrideStatus: String? = nil, format: String = "json") -> ReportQuery {
        let (from, to) = dateRangeToISO(activeDateRange)
        return ReportQuery(
            from: from,
            to: to,
            loanType: mapLoanType(activeLoanType),
            region: mapRegion(activeRegion),
            status: overrideStatus ?? mapStatus(activeStatus),
            format: format
        )
    }

    func dateRangeToISO(_ label: String) -> (String, String) {
        let calendar = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let to = fmt.string(from: now)

        let from: String
        switch label {
        case "Last 7 Days":
            let start = calendar.date(byAdding: .day, value: -7, to: now)!
            from = fmt.string(from: start)
        case "Last 30 Days":
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            from = fmt.string(from: start)
        case "Last 90 Days":
            let start = calendar.date(byAdding: .day, value: -90, to: now)!
            from = fmt.string(from: start)
        case "This FY":
            let year = calendar.component(.month, from: now) >= 4
                ? calendar.component(.year, from: now)
                : calendar.component(.year, from: now) - 1
            let start = calendar.date(from: DateComponents(year: year, month: 4, day: 1))!
            from = fmt.string(from: start)
        case "This Year":
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            from = fmt.string(from: start)
        default:
            let start = calendar.date(byAdding: .day, value: -30, to: now)!
            from = fmt.string(from: start)
        }
        return (from, to)
    }

    private func mapLoanType(_ label: String) -> String {
        switch label {
        case "All Types":      return "ALL"
        case "Home Loan":      return "HOME"
        case "Personal Loan":  return "PERSONAL"
        case "Business Loan":  return "BUSINESS"
        case "Vehicle Loan":   return "VEHICLE"
        default:               return "ALL"
        }
    }

    private func mapRegion(_ label: String) -> String {
        switch label {
        case "All Regions": return "ALL"
        default:            return label.uppercased()
        }
    }

    private func mapStatus(_ label: String) -> String {
        switch label {
        case "All":     return "ALL"
        case "Active":  return "ACTIVE"
        case "Closed":  return "CLOSED"
        case "NPA":     return "NPA"
        default:        return "ALL"
        }
    }

    // MARK: - Applications (fallback data source)

    private func loadApplications() async throws {
        guard #available(iOS 18.0, *) else { return }
        do {
            let list = try await loanAPI.listLoanApplications(limit: 500, offset: 0, branchID: nil, authorized: true)
            let mapped = list.map { LoanApplication.from(proto: $0) }
            await MainActor.run { self.applications = mapped }
        } catch {
            await MainActor.run { self.applications = [] }
        }
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

    // MARK: - Report Rows from Backend

    func normalizedReportID(_ uiReportID: String) -> String {
        switch uiReportID {
        case "RPT-PERF": return "RPT-01"
        case "RPT-COLL": return "RPT-02"
        case "RPT-DISB": return "RPT-03"
        case "RPT-RISK": return "RPT-04"
        case "RPT-NPA":  return "RPT-NPA"
        default:         return uiReportID
        }
    }

    /// Derive ReportRow from backend response when available, else fall back to application data
    func reportRowsFromBackend(for reportId: String) -> [ReportRow] {
        let id = normalizedReportID(reportId)
        switch id {
        case "RPT-01":
            if let r = portfolioReport {
                return [
                    ReportRow(id: "r1", label: "Portfolio Value",     value: r.kpis.totalPortfolioValue.currencyFormatted, change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Active Loans",        value: "\(r.kpis.totalActiveLoans)",                 change: "—", isPositive: true),
                    ReportRow(id: "r3", label: "Disbursed Amount",    value: r.kpis.totalDisbursedAmount.currencyFormatted, change: "—", isPositive: true),
                    ReportRow(id: "r4", label: "NPA %",               value: String(format: "%.2f%%", r.kpis.npaPercentage), change: "—", isPositive: r.kpis.npaPercentage < 3),
                    ReportRow(id: "r5", label: "Approval Rate",       value: String(format: "%.1f%%", r.kpis.approvalRate), change: "—", isPositive: r.kpis.approvalRate >= 70),
                    ReportRow(id: "r6", label: "Avg Loan Size",       value: r.kpis.avgLoanSize.currencyFormatted,         change: "—", isPositive: true)
                ]
            }
        case "RPT-02":
            if let r = collectionReport {
                return [
                    ReportRow(id: "r1", label: "EMI Collected",       value: r.kpis.totalEmiCollected.currencyFormatted,           change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Collection Efficiency", value: String(format: "%.1f%%", r.kpis.collectionEfficiencyPercentage), change: "—", isPositive: r.kpis.collectionEfficiencyPercentage >= 90),
                    ReportRow(id: "r3", label: "Pending Amount",      value: r.kpis.pendingAmount.currencyFormatted,               change: "—", isPositive: r.kpis.pendingAmount == 0),
                    ReportRow(id: "r4", label: "Overdue Amount",       value: r.kpis.overdueAmount.currencyFormatted,               change: "—", isPositive: r.kpis.overdueAmount == 0)
                ]
            }
        case "RPT-03":
            if let r = disbursementReport {
                return [
                    ReportRow(id: "r1", label: "Total Disbursed",     value: r.kpis.totalDisbursedAmount.currencyFormatted,       change: "—", isPositive: true),
                    ReportRow(id: "r2", label: "Avg Disbursement",    value: r.kpis.avgDisbursementSize.currencyFormatted,         change: "—", isPositive: true),
                    ReportRow(id: "r3", label: "Growth %",            value: String(format: "%.1f%%", r.kpis.disbursementGrowthPercentage), change: "—", isPositive: r.kpis.disbursementGrowthPercentage > 0),
                    ReportRow(id: "r4", label: "Count",               value: "\(r.kpis.totalDisbursementCount)",                   change: "—", isPositive: true)
                ]
            }
        case "RPT-04":
            if let r = riskCreditReport {
                return [
                    ReportRow(id: "r1", label: "Avg CIBIL Score",     value: "\(r.kpis.avgCibilScore)",                            change: "—", isPositive: r.kpis.avgCibilScore >= 700),
                    ReportRow(id: "r2", label: "High Risk %",         value: String(format: "%.1f%%", r.kpis.highRiskPercentage),  change: "—", isPositive: r.kpis.highRiskPercentage < 15),
                    ReportRow(id: "r3", label: "Fraud Flags",         value: "\(r.kpis.fraudFlagsCount)",                          change: "—", isPositive: r.kpis.fraudFlagsCount == 0),
                    ReportRow(id: "r4", label: "Avg FOIR",            value: String(format: "%.0f%%", r.kpis.avgFoir),             change: "—", isPositive: r.kpis.avgFoir <= 50)
                ]
            }
        case "RPT-NPA":
            if let r = npaReport {
                return [
                    ReportRow(id: "r1", label: "Total NPA",           value: r.kpis.totalNpaAmount.currencyFormatted,              change: "—", isPositive: false),
                    ReportRow(id: "r2", label: "NPA %",               value: String(format: "%.2f%%", r.kpis.npaPercentage),       change: "—", isPositive: r.kpis.npaPercentage < 3),
                    ReportRow(id: "r3", label: "NPA Count",           value: "\(r.kpis.totalNpaCount)",                            change: "—", isPositive: r.kpis.totalNpaCount == 0)
                ]
            }
        default:
            break
        }
        // Fallback: derive from local applications
        return Self.liveReportRows(for: id, from: applications)
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
        let id = normalizedReportID(reportId)

        // Try backend data first
        switch id {
        case "RPT-01":
            if let r = portfolioReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Portfolio Value", r.kpis.totalPortfolioValue.currencyFormatted],
                    ["Active Loans", "\(r.kpis.totalActiveLoans)"],
                    ["Disbursed Amount", r.kpis.totalDisbursedAmount.currencyFormatted],
                    ["Avg Loan Size", r.kpis.avgLoanSize.currencyFormatted],
                    ["NPA Amount", r.kpis.npaAmount.currencyFormatted],
                    ["NPA %", String(format: "%.2f%%", r.kpis.npaPercentage)],
                    ["Approval Rate", String(format: "%.1f%%", r.kpis.approvalRate)]
                ]
                return (columns, rows)
            }
        case "RPT-02":
            if let r = collectionReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["EMI Collected", r.kpis.totalEmiCollected.currencyFormatted],
                    ["Collection Efficiency", String(format: "%.1f%%", r.kpis.collectionEfficiencyPercentage)],
                    ["Pending", r.kpis.pendingAmount.currencyFormatted],
                    ["Overdue", r.kpis.overdueAmount.currencyFormatted]
                ]
                return (columns, rows)
            }
        case "RPT-03":
            if let r = disbursementReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Total Disbursed", r.kpis.totalDisbursedAmount.currencyFormatted],
                    ["Avg Size", r.kpis.avgDisbursementSize.currencyFormatted],
                    ["Growth", String(format: "%.1f%%", r.kpis.disbursementGrowthPercentage)],
                    ["Count", "\(r.kpis.totalDisbursementCount)"]
                ]
                return (columns, rows)
            }
        case "RPT-04":
            if let r = riskCreditReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Avg CIBIL", "\(r.kpis.avgCibilScore)"],
                    ["High Risk %", String(format: "%.1f%%", r.kpis.highRiskPercentage)],
                    ["Fraud Flags", "\(r.kpis.fraudFlagsCount)"],
                    ["Avg FOIR", String(format: "%.0f%%", r.kpis.avgFoir)]
                ]
                return (columns, rows)
            }
        case "RPT-NPA":
            if let r = npaReport {
                let columns = ["Metric", "Value"]
                let rows: [[String]] = [
                    ["Total NPA", r.kpis.totalNpaAmount.currencyFormatted],
                    ["NPA %", String(format: "%.2f%%", r.kpis.npaPercentage)],
                    ["NPA Count", "\(r.kpis.totalNpaCount)"]
                ]
                return (columns, rows)
            }
        default:
            break
        }

        // Fallback: derive from local applications
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

    // MARK: - Generate Report Data (used by ReportExportService)

    func generateReportData() -> (rows: [AppReportRow], summary: AppReportSummary) {
        let rows: [AppReportRow] = applications.map { app in
            let risk: String = {
                let cibil = app.financials.cibilScore
                let dti   = app.financials.dtiRatio
                if (cibil > 0 && cibil < 650) || dti > 0.45 { return "High" }
                if (cibil > 0 && cibil < 700) || dti > 0.35 { return "Medium" }
                return "Low"
            }()
            return AppReportRow(
                applicationId: app.id,
                borrowerName: app.borrower.name,
                loanType: app.loan.type.displayName,
                amount: app.loan.amount,
                status: app.status.displayName,
                risk: risk,
                date: app.createdAt
            )
        }

        let total    = applications.count
        let approved = applications.filter { $0.status == .approved || $0.status == .managerApproved }.count
        let pending  = applications.filter { $0.status == .pending  || $0.status == .underReview }.count
        let rejected = applications.filter {
            $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected
        }.count
        let totalValue = applications.reduce(0) { $0 + $1.loan.amount }
        let avgLoanSize = total > 0 ? totalValue / Double(total) : 0
        let npaRate = total > 0 ? (Double(rejected) / Double(total)) * 100.0 : 0

        let summary = AppReportSummary(
            total: total,
            approved: approved,
            pending: pending,
            rejected: rejected,
            totalValue: totalValue,
            avgLoanSize: avgLoanSize,
            npaRate: npaRate
        )
        return (rows, summary)
    }

    func activeFilterDescription(reportTitle: String) -> String {
        [selectedBranch, selectedLoanType, dateRangeLabel]
            .filter { $0 != "All Branches" && $0 != "All Types" }
            .joined(separator: ", ")
    }

    func generatePDFReportData(
        reportTitle: String,
        dateRange: String,
        loanType: String,
        region: String,
        status: String
    ) -> AdminPDFReportPayload {
        let filteredApplications = applications.filter { app in
            matches(dateRange: dateRange, createdAt: app.createdAt)
                && matches(loanType: loanType, app: app)
                && matches(region: region, app: app)
                && matches(status: status, app: app)
        }

        let rows = filteredApplications.map { app in
            AdminPDFReportRow(
                applicationId: app.id,
                borrowerName: app.borrower.name,
                borrowerPhone: app.borrower.phone,
                borrowerEmail: app.borrower.email,
                branch: app.branch,
                loanType: app.loan.type.displayName,
                amount: app.loan.amount,
                tenureMonths: app.loan.tenure,
                interestRate: app.loan.interestRate,
                emi: app.loan.emi,
                status: app.status.displayName,
                risk: riskLabel(for: app),
                slaStatus: app.slaStatus.displayName,
                createdAt: app.createdAt
            )
        }

        // Use backend summary data when available
        let total: Int
        let approved: Int
        let pending: Int
        let rejected: Int
        let totalValue: Double
        let avgLoanSize: Double
        let highRisk: Int

        let reportId = normalizedReportID(
            reportTitle == "Portfolio Performance" ? "RPT-PERF" :
            reportTitle == "Disbursement Report"   ? "RPT-DISB" :
            reportTitle == "Collection Report"     ? "RPT-COLL" :
            reportTitle == "NPA Report"            ? "RPT-NPA"  :
            reportTitle == "Risk & Credit Report"  ? "RPT-RISK" : ""
        )

        switch reportId {
        case "RPT-01":
            let k = portfolioReport?.kpis
            total = k?.totalActiveLoans ?? filteredApplications.count
            approved = Int(Double(total) * (k?.approvalRate ?? 0) / 100.0)
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = total - approved - pending
            totalValue = k?.totalPortfolioValue ?? filteredApplications.reduce(0) { $0 + $1.loan.amount }
            avgLoanSize = k?.avgLoanSize ?? (total > 0 ? totalValue / Double(total) : 0)
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        case "RPT-03":
            let k = disbursementReport?.kpis
            total = k?.totalDisbursementCount ?? filteredApplications.count
            approved = filteredApplications.filter { $0.status == .approved || $0.status == .managerApproved }.count
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = filteredApplications.filter { $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected }.count
            totalValue = k?.totalDisbursedAmount ?? filteredApplications.reduce(0) { $0 + $1.loan.amount }
            avgLoanSize = k?.avgDisbursementSize ?? (total > 0 ? totalValue / Double(total) : 0)
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        default:
            total = filteredApplications.count
            approved = filteredApplications.filter { $0.status == .approved || $0.status == .managerApproved }.count
            pending = filteredApplications.filter { $0.status == .pending || $0.status == .underReview }.count
            rejected = filteredApplications.filter {
                $0.status == .rejected || $0.status == .managerRejected || $0.status == .officerRejected
            }.count
            totalValue = filteredApplications.reduce(0) { $0 + $1.loan.amount }
            avgLoanSize = total > 0 ? totalValue / Double(total) : 0
            highRisk = filteredApplications.filter { riskLabel(for: $0) == "High" }.count
        }

        let filterText = [
            "Date Range: \(dateRange)",
            "Loan Type: \(loanType)",
            "Region: \(region)",
            "Status: \(status)"
        ].joined(separator: " | ")

        return AdminPDFReportPayload(
            reportName: reportTitle,
            filters: filterText,
            rows: rows,
            summary: AdminPDFReportSummary(
                total: total,
                approved: approved,
                pending: pending,
                rejected: rejected,
                totalValue: totalValue,
                avgLoanSize: avgLoanSize,
                highRisk: highRisk
            )
        )
    }

    private func riskLabel(for app: LoanApplication) -> String {
        let cibil = app.financials.cibilScore
        let dti = app.financials.dtiRatio
        if (cibil > 0 && cibil < 650) || dti > 0.45 { return "High" }
        if (cibil > 0 && cibil < 700) || dti > 0.35 { return "Medium" }
        return "Low"
    }

    private func matches(dateRange: String, createdAt: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch dateRange {
        case "Last 7 Days":
            guard let start = calendar.date(byAdding: .day, value: -7, to: now) else { return true }
            return createdAt >= start
        case "Last 30 Days":
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return true }
            return createdAt >= start
        case "Last 90 Days":
            guard let start = calendar.date(byAdding: .day, value: -90, to: now) else { return true }
            return createdAt >= start
        case "This FY":
            let year = calendar.component(.month, from: now) >= 4
                ? calendar.component(.year, from: now)
                : calendar.component(.year, from: now) - 1
            let start = calendar.date(from: DateComponents(year: year, month: 4, day: 1))
            return start.map { createdAt >= $0 } ?? true
        default:
            return true
        }
    }

    private func matches(loanType: String, app: LoanApplication) -> Bool {
        loanType == "All Types" || app.loan.type.displayName == loanType
    }

    private func matches(region: String, app: LoanApplication) -> Bool {
        region == "All Regions" || app.branch.localizedCaseInsensitiveContains(region)
    }

    private func matches(status: String, app: LoanApplication) -> Bool {
        switch status {
        case "All":
            return true
        case "Active":
            return app.status == .pending || app.status == .underReview || app.status == .managerApproved
        case "Closed":
            return app.status == .approved
        case "NPA":
            return app.slaStatus == .overdue || riskLabel(for: app) == "High"
        default:
            return app.status.displayName == status
        }
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
