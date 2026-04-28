import GRDB
import Foundation

struct LeadDocumentRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName = "lead_documents"
    var id: String
    var leadID: String
    var name: String
    var kind: String
    var statusType: String
    var uploadedFileName: String?
    var mediaFileID: String?
    var requestedAt: Double?
    var uploadedAt: Double?
    var verifiedAt: Double?
    var verifiedName: String?
    var verifiedDocNumber: String?
    var verifiedDOB: String?
    var verificationNote: String?
}

final class SQLiteDocumentStore {
    private let db: DatabasePool
    init(db: DatabasePool = DatabaseManager.shared.dbPool) { self.db = db }

    // Call once per lead-detail open. No-op if rows already exist.
    func seedIfNeeded(leadID: String, loanType: LoanType) {
        let count = (try? db.read { db in
            try LeadDocumentRecord.filter(Column("leadID") == leadID).fetchCount(db)
        }) ?? 0
        guard count == 0 else { return }
        let defaults = LeadDocument.defaultDocuments(for: loanType)
        try? db.write { db in
            for doc in defaults {
                let record = LeadDocumentRecord(
                    id: doc.id.uuidString, leadID: leadID,
                    name: doc.name, kind: kindStr(doc.kind),
                    statusType: "notUploaded",
                    uploadedFileName: nil, mediaFileID: nil,
                    requestedAt: nil, uploadedAt: nil, verifiedAt: nil,
                    verifiedName: nil, verifiedDocNumber: nil,
                    verifiedDOB: nil, verificationNote: nil
                )
                try record.insert(db)
            }
        }
    }

    func documents(for leadID: String, loanType: LoanType) -> [LeadDocument] {
        seedIfNeeded(leadID: leadID, loanType: loanType)
        let records = (try? db.read { db in
            try LeadDocumentRecord.filter(Column("leadID") == leadID).fetchAll(db)
        }) ?? []
        return records.compactMap(toDocument)
    }

    func save(_ doc: LeadDocument, leadID: String, mediaFileID: String? = nil) {
        var verifiedDate: Double? = nil
        if case .verified(let d) = doc.status { verifiedDate = d.timeIntervalSince1970 }
        let record = LeadDocumentRecord(
            id: doc.id.uuidString, leadID: leadID,
            name: doc.name, kind: kindStr(doc.kind),
            statusType: statusStr(doc.status),
            uploadedFileName: doc.status.uploadedFileName,
            mediaFileID: mediaFileID,
            requestedAt: doc.status.requestedAt?.timeIntervalSince1970,
            uploadedAt: doc.status.uploadedAt?.timeIntervalSince1970,
            verifiedAt: verifiedDate,
            verifiedName: doc.verification?.identityData?.fullName,
            verifiedDocNumber: doc.verification?.identityData?.documentNumber,
            verifiedDOB: doc.verification?.identityData?.dateOfBirth,
            verificationNote: doc.verification?.note
        )
        try? db.write { db in try record.save(db) }
    }

    private func kindStr(_ k: LeadDocumentKind) -> String {
        switch k { case .aadhaar: return "aadhaar"; case .pan: return "pan"; case .supporting: return "supporting" }
    }
    private func statusStr(_ s: DocumentStatus) -> String {
        switch s { case .notUploaded: return "notUploaded"; case .requested: return "requested";
                   case .uploaded: return "uploaded"; case .pending: return "pending"; case .verified: return "verified" }
    }
    private func toDocument(_ r: LeadDocumentRecord) -> LeadDocument? {
        guard let uuid = UUID(uuidString: r.id) else { return nil }
        let kind: LeadDocumentKind
        switch r.kind { case "aadhaar": kind = .aadhaar; case "pan": kind = .pan; default: kind = .supporting }
        let status: DocumentStatus
        switch r.statusType {
        case "requested": status = .requested(date: Date(timeIntervalSince1970: r.requestedAt ?? 0))
        case "uploaded":  status = .uploaded(fileName: r.uploadedFileName ?? "", date: Date(timeIntervalSince1970: r.uploadedAt ?? 0))
        case "pending":   status = .pending
        case "verified":  status = .verified(date: Date(timeIntervalSince1970: r.verifiedAt ?? 0))
        default:          status = .notUploaded
        }
        let idata = r.verifiedName.map { IdentityVerificationData(fullName: $0, documentNumber: r.verifiedDocNumber ?? "", dateOfBirth: r.verifiedDOB ?? "") }
        var doc = LeadDocument(id: uuid, name: r.name, kind: kind, status: status)
        if idata != nil || r.verificationNote != nil {
            doc.verification = DocumentVerification(identityData: idata, note: r.verificationNote)
        }
        return doc
    }
}
