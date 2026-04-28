//
//  DashboardViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

class DashboardViewModel: ObservableObject {
    @Published var applications: [LoanApplication] = []
    @Published var selectedApplication: LoanApplication? = nil
    @Published var isLoading = false
    
    // Portfolio Filters
    @Published var portfolioLoanType: LoanType? = nil
    @Published var portfolioRisk: RiskLevel? = nil
    @Published var portfolioStatus: ApplicationStatus? = nil
    
    private let dataService = MockDataService.shared
    
    // MARK: - KPIs
    
    var assignedCount: Int {
        applications.filter { $0.status != .approved && $0.status != .rejected }.count
    }
    
    var pendingReviewCount: Int {
        applications.filter { $0.status == .underReview || $0.status == .pending }.count
    }
    
    var highRiskCount: Int {
        applications.filter { $0.riskLevel == .high && $0.status != .rejected }.count
    }
    
    // Manager KPIs
    var pendingApprovals: Int {
        applications.filter { $0.status == .underReview }.count
    }
    
    var approvedThisMonth: Int {
        applications.filter { $0.status == .approved }.count
    }
    
    var totalPortfolioValue: Double {
        applications.filter { $0.status == .approved }.reduce(0) { $0 + $1.loan.amount }
    }
    
    // Admin KPIs
    var activeUsersCount: Int { 6 }
    var processedTodayCount: Int { 18 }
    
    // MARK: - Active applications (non-terminal)
    
    var activeApplications: [LoanApplication] {
        applications.filter { $0.status == .pending || $0.status == .underReview }
    }
    
    // MARK: - Portfolio Filtered Applications
    
    var filteredPortfolioApplications: [LoanApplication] {
        var result = applications
        
        if let type = portfolioLoanType {
            result = result.filter { $0.loan.type == type }
        }
        
        if let risk = portfolioRisk {
            result = result.filter { $0.riskLevel == risk }
        }
        
        if let status = portfolioStatus {
            result = result.filter { $0.status == status }
        }
        
        return result
    }
    
    // MARK: - Load Data
    
    func loadData() {
        isLoading = true
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.applications = self.dataService.fetchApplications()
            if self.selectedApplication == nil {
                self.selectedApplication = self.activeApplications.first
            }
            self.isLoading = false
        }
    }
    
    func selectApplication(_ app: LoanApplication) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedApplication = app
        }
    }
}
