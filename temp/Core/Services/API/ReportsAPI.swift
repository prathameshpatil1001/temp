//
//  ReportsAPI.swift
//  lms_project
//
//  REST API client for /api/reports/* endpoints.
//  Uses URLSession since the reports API is HTTP REST (not gRPC).
//

import Foundation

// MARK: - Reports API

struct ReportsAPI {

    private static let baseURL = "https://\(APIConfig.host)/api/reports"

    private static func makeRequest(path: String, query: ReportQuery, acceptHeader: String = "application/json") async throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)\(path)")!
        // For JSON fetches, exclude the format param; for exports, include it
        if query.format == "json" {
            components.queryItems = query.queryItems.filter { $0.name != "format" }
        } else {
            components.queryItems = query.queryItems
        }

        guard let url = components.url else {
            throw ReportsAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(acceptHeader, forHTTPHeaderField: "Accept")

        let token = await MainActor.run { SessionStore.shared.accessToken }
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(UUID().uuidString, forHTTPHeaderField: "x-request-id")

        return request
    }

    private static func fetch<T: Decodable>(_ type: T.Type, path: String, query: ReportQuery) async throws -> T {
        // For JSON fetches, strip the format param entirely
        var jsonQuery = query
        jsonQuery.format = "json"
        let request = try await makeRequest(path: path, query: jsonQuery)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportsAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(type, from: data)
            } catch {
                throw ReportsAPIError.decodingFailed(error.localizedDescription)
            }
        case 401:
            throw ReportsAPIError.unauthorized
        case 403:
            throw ReportsAPIError.forbidden
        case 404:
            throw ReportsAPIError.notFound
        case 500...599:
            throw ReportsAPIError.serverError(httpResponse.statusCode)
        default:
            throw ReportsAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    // MARK: - Report Endpoints

    static func portfolioPerformance(query: ReportQuery) async throws -> PortfolioPerformanceResponse {
        try await fetch(PortfolioPerformanceResponse.self, path: "/portfolio-performance", query: query)
    }

    static func disbursement(query: ReportQuery) async throws -> DisbursementResponse {
        try await fetch(DisbursementResponse.self, path: "/disbursement", query: query)
    }

    static func collection(query: ReportQuery) async throws -> CollectionResponse {
        try await fetch(CollectionResponse.self, path: "/collection", query: query)
    }

    static func npa(query: ReportQuery) async throws -> NPAResponse {
        try await fetch(NPAResponse.self, path: "/npa", query: query)
    }

    static func riskCredit(query: ReportQuery) async throws -> RiskCreditResponse {
        try await fetch(RiskCreditResponse.self, path: "/risk-credit", query: query)
    }

    // MARK: - Export (PDF/CSV) — returns raw Data

    static func exportReport(path: String, query: ReportQuery) async throws -> Data {
        let format = query.format == "json" ? "pdf" : query.format
        var exportQuery = query
        exportQuery.format = format

        let acceptHeader: String
        switch format {
        case "pdf":   acceptHeader = "application/pdf"
        case "csv":   acceptHeader = "text/csv"
        case "xlsx":  acceptHeader = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        default:      acceptHeader = "application/pdf"
        }

        let request = try await makeRequest(path: path, query: exportQuery, acceptHeader: acceptHeader)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReportsAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 202:
            throw ReportsAPIError.asyncExportAccepted
        case 401:
            throw ReportsAPIError.unauthorized
        default:
            throw ReportsAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }
}

// MARK: - Reports API Error

enum ReportsAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case serverError(Int)
    case unexpectedStatus(Int)
    case decodingFailed(String)
    case asyncExportAccepted

    var errorDescription: String? {
        switch self {
        case .invalidURL:          return "Invalid report URL"
        case .invalidResponse:     return "Invalid server response"
        case .unauthorized:        return "Session expired. Please sign in again."
        case .forbidden:           return "You do not have permission to access this report."
        case .notFound:            return "Report endpoint not found."
        case .serverError(let c):  return "Server error (\(c)). Please try again later."
        case .unexpectedStatus(let c): return "Unexpected response (\(c))"
        case .decodingFailed(let m): return "Failed to parse report data: \(m)"
        case .asyncExportAccepted: return "Export is being generated. Please try again shortly."
        }
    }
}
