//
//  ReportModels.swift
//  lms_project
//
//  Codable models matching the backend /api/reports/* API contract.
//

import Foundation

// MARK: - Common

struct ReportMeta: Codable {
    let reportName: String
    let generatedAt: String
    let dateRange: DateRangeFilter
    let filters: ReportFilters
    let currency: String
}

struct DateRangeFilter: Codable {
    let from: String
    let to: String
}

struct ReportFilters: Codable {
    let loanType: String
    let region: String
    let status: String
}

struct TrendPoint: Codable {
    let period: String
    let value: Double
}

struct DistributionItem: Codable {
    let name: String
    let value: Double
    let percentage: Double?
}

struct DistributionWithCount: Codable {
    let name: String
    let value: Double
    let count: Int?
    let percentage: Double?
}

struct AgingBucket: Codable {
    let bucket: String
    let amount: Double
    let count: Int
}

struct CountBucket: Codable {
    let bucket: String
    let count: Int
}

// MARK: - 1. Portfolio Performance Report

struct PortfolioPerformanceResponse: Codable {
    let reportMeta: ReportMeta
    let kpis: PortfolioKPIs
    let trends: PortfolioTrends
    let distributions: PortfolioDistributions
    let npaSummary: NPASummary
    let insights: [String]
}

struct PortfolioKPIs: Codable {
    let totalPortfolioValue: Double
    let totalActiveLoans: Int
    let totalDisbursedAmount: Double
    let avgLoanSize: Double
    let npaAmount: Double
    let npaPercentage: Double
    let approvalRate: Double
}

struct PortfolioTrends: Codable {
    let portfolioValueTrend: [TrendPoint]
    let disbursementTrend: [TrendPoint]
    let loanCountTrend: [TrendPoint]
}

struct PortfolioDistributions: Codable {
    let byLoanType: [DistributionItem]
    let byRegion: [DistributionItem]
}

struct NPASummary: Codable {
    let totalNpaAmount: Double
    let npaPercentage: Double
    let npaCount: Int
    let agingBuckets: [AgingBucket]
}

// MARK: - 2. Disbursement Report

struct DisbursementResponse: Codable {
    let reportMeta: ReportMeta
    let kpis: DisbursementKPIs
    let trends: DisbursementTrends
    let distributions: DisbursementDistributions
    let insights: [String]
}

struct DisbursementKPIs: Codable {
    let totalDisbursedAmount: Double
    let avgDisbursementSize: Double
    let disbursementGrowthPercentage: Double
    let totalDisbursementCount: Int
}

struct DisbursementTrends: Codable {
    let disbursementTrend: [TrendPoint]
}

struct DisbursementDistributions: Codable {
    let byLoanType: [DistributionItem]
    let byRegion: [DistributionWithCount]
}

// MARK: - 3. Collection Report

struct CollectionResponse: Codable {
    let reportMeta: ReportMeta
    let kpis: CollectionKPIs
    let trends: CollectionTrends
    let summaries: CollectionSummaries
    let insights: [String]
}

struct CollectionKPIs: Codable {
    let totalEmiCollected: Double
    let collectionEfficiencyPercentage: Double
    let pendingAmount: Double
    let overdueAmount: Double
}

struct CollectionTrends: Codable {
    let collectionTrend: [TrendPoint]
}

struct CollectionSummaries: Codable {
    let dpdBuckets: [AgingBucket]
    let paidVsPending: [DistributionItem]
}

// MARK: - 4. NPA Report

struct NPAResponse: Codable {
    let reportMeta: ReportMeta
    let kpis: NPAKPIs
    let summaries: NPASummaries
    let insights: [String]
}

struct NPAKPIs: Codable {
    let totalNpaAmount: Double
    let npaPercentage: Double
    let totalNpaCount: Int
}

struct NPASummaries: Codable {
    let agingBuckets: [AgingBucket]
    let npaVsHealthy: [DistributionItem]
    let topRegions: [DistributionWithCount]
}

// MARK: - 5. Risk & Credit Report

struct RiskCreditResponse: Codable {
    let reportMeta: ReportMeta
    let kpis: RiskCreditKPIs
    let distributions: RiskCreditDistributions
    let insights: [String]
}

struct RiskCreditKPIs: Codable {
    let avgCibilScore: Int
    let highRiskPercentage: Double
    let fraudFlagsCount: Int
    let avgFoir: Double
}

struct RiskCreditDistributions: Codable {
    let cibilScoreDistribution: [CountBucket]
    let riskCategories: [DistributionItem]
    let foirDistribution: [CountBucket]
}

// MARK: - Report Query Parameters

struct ReportQuery {
    let from: String
    let to: String
    var loanType: String = "ALL"
    var region: String = "ALL"
    var status: String = "ALL"
    var format: String = "json"

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
            URLQueryItem(name: "loanType", value: loanType),
            URLQueryItem(name: "region", value: region),
            URLQueryItem(name: "status", value: status),
            URLQueryItem(name: "format", value: format)
        ]
    }
}
