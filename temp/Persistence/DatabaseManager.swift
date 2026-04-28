import GRDB
import Foundation

final class DatabaseManager {
    static let shared = try! DatabaseManager()
    let dbPool: DatabasePool

    private init() throws {
        let folder = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let dbURL = folder.appendingPathComponent("dst_local.db")
        dbPool = try DatabasePool(path: dbURL.path)
        try migrate()
    }

    private func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "leads") { t in
                t.primaryKey("id", .text)
                t.column("applicationID", .text)
                t.column("name", .text).notNull()
                t.column("phone", .text).notNull()
                t.column("email", .text).notNull().defaults(to: "")
                t.column("borrowerProfileID", .text)
                t.column("borrowerUserID", .text)
                t.column("loanType", .text).notNull()
                t.column("loanAmount", .double).notNull()
                t.column("status", .text).notNull().defaults(to: "New")
                t.column("createdAt", .double).notNull()
                t.column("updatedAt", .double).notNull()
                t.column("isAadhaarKycVerified", .boolean).notNull().defaults(to: false)
                t.column("isPanKycVerified", .boolean).notNull().defaults(to: false)
                t.column("aadhaarVerifiedName", .text).notNull().defaults(to: "")
                t.column("aadhaarVerifiedDOB", .text).notNull().defaults(to: "")
                t.column("isDeleted", .boolean).notNull().defaults(to: false)
            }
            try db.create(table: "lead_documents") { t in
                t.primaryKey("id", .text)
                t.column("leadID", .text).notNull().references("leads", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("kind", .text).notNull()
                t.column("statusType", .text).notNull().defaults(to: "notUploaded")
                t.column("uploadedFileName", .text)
                t.column("mediaFileID", .text)
                t.column("requestedAt", .double)
                t.column("uploadedAt", .double)
                t.column("verifiedAt", .double)
                t.column("verifiedName", .text)
                t.column("verifiedDocNumber", .text)
                t.column("verifiedDOB", .text)
                t.column("verificationNote", .text)
            }
            try db.create(table: "lead_metadata") { t in
                t.primaryKey("applicationID", .text)
                t.column("name", .text).notNull()
                t.column("phone", .text).notNull()
                t.column("email", .text).notNull().defaults(to: "")
            }
        }
        migrator.registerMigration("v2_userdefaults_migration") { _ in
            // No-op: the UserDefaults→SQLite lead migration is obsolete.
            // All leads are now persisted on the backend as DRAFT LoanApplications.
            // The migration identifier is kept so it is not re-applied on existing devices.
        }
        migrator.registerMigration("v3_drop_lead_documents_fk") { db in
            // The lead_documents table has a FK to leads (onDelete: .cascade).
            // Since leads are now backend-only, any leadID (applicationUUID) that is
            // not in the local leads table fails the FK check and inserts are silently dropped.
            // Recreate the table without the FK so documents can use any string as leadID.
            try db.execute(sql: """
                CREATE TABLE lead_documents_new (
                    id              TEXT PRIMARY KEY NOT NULL,
                    leadID          TEXT NOT NULL,
                    name            TEXT NOT NULL,
                    kind            TEXT NOT NULL,
                    statusType      TEXT NOT NULL DEFAULT 'notUploaded',
                    uploadedFileName TEXT,
                    mediaFileID     TEXT,
                    requestedAt     REAL,
                    uploadedAt      REAL,
                    verifiedAt      REAL,
                    verifiedName    TEXT,
                    verifiedDocNumber TEXT,
                    verifiedDOB     TEXT,
                    verificationNote TEXT
                )
            """)
            try db.execute(sql: "INSERT INTO lead_documents_new SELECT * FROM lead_documents")
            try db.execute(sql: "DROP TABLE lead_documents")
            try db.execute(sql: "ALTER TABLE lead_documents_new RENAME TO lead_documents")
        }
        migrator.registerMigration("v4_add_lead_product_id") { db in
            // Add loanProductID column to leads table for forward compatibility.
            try db.alter(table: "leads") { t in
                t.add(column: "loanProductID", .text)
            }
        }
        try migrator.migrate(dbPool)
    }
}
