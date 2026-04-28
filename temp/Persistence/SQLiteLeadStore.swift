import Foundation

// MARK: - DEPRECATED: SQLiteLeadStore
//
// This store is no longer used. All leads are now persisted on the backend
// as `LoanApplication` records with `status = DRAFT`.
//
// The `BackendLeadService` creates a DRAFT application on `addLead(_:)` and
// fetches leads exclusively via `ListLoanApplications`. The local GRDB
// database (leads table) still exists for migration safety but is not written
// to or read from during normal operation.
//
// Safe to remove this file once the `leads` table migration is confirmed
// complete across all active devices.
//
// Deprecated: 2026-04-28
// Replacement: BackendLeadService (LeadService.swift) + LeadMetadataStore

@available(*, unavailable, renamed: "BackendLeadService", message: "Use the backend-driven lead flow via Draft LoanApplications.")
final class SQLiteLeadStore_Deprecated {}
