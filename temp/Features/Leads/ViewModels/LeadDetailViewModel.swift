import Foundation
import Combine

@MainActor
final class LeadDetailViewModel: ObservableObject {

    let lead: Lead
    var onStatusUpdate: ((String, LeadStatus) -> Void)?

    @Published var documents: [LeadDocument]
    @Published var timeline: [TimelineEvent]
    @Published var messages: [LeadMessage]
    @Published var showEligibility = false
    @Published var showSubmitSuccess = false
    @Published var showRequestDocsConfirm = false

    var uploadedCount: Int { documents.filter { $0.status.isUploaded }.count }
    var totalCount: Int    { documents.count }
    /// All docs must be at least uploaded (photo captured) before the DST can submit.
    /// Backend-side KYC verification happens after submission — DST only provides the scan.
    var missingCount: Int {
        documents.filter { !$0.status.isUploaded }.count
    }
    var canSubmit: Bool { missingCount == 0 && totalCount > 0 }

    private let documentStore: SQLiteDocumentStore
    private let leadID: String

    init(lead: Lead, onStatusUpdate: ((String, LeadStatus) -> Void)? = nil,
         documentStore: SQLiteDocumentStore = SQLiteDocumentStore()) {
        self.lead = lead
        self.leadID = lead.id
        self.documentStore = documentStore
        self.onStatusUpdate = onStatusUpdate

        // Load persisted documents; seeds defaults with stable UUIDs on first open
        var docs = documentStore.documents(for: lead.id, loanType: lead.loanType)

        // Overlay KYC flags from the Lead model (in case they were verified before
        // the document store existed, or on a different device)
        if lead.isAadhaarKycVerified,
           let idx = docs.firstIndex(where: { $0.kind == .aadhaar }),
           !docs[idx].status.isVerified {
            docs[idx].markVerified(
                identityData: IdentityVerificationData(
                    fullName: lead.aadhaarVerifiedName,
                    documentNumber: "",
                    dateOfBirth: lead.aadhaarVerifiedDOB),
                note: "Backend KYC verified")
            documentStore.save(docs[idx], leadID: lead.id)
        }
        if lead.isPanKycVerified,
           let idx = docs.firstIndex(where: { $0.kind == .pan }),
           !docs[idx].status.isVerified {
            docs[idx].markVerified(
                identityData: IdentityVerificationData(
                    fullName: lead.aadhaarVerifiedName,
                    documentNumber: "",
                    dateOfBirth: lead.aadhaarVerifiedDOB),
                note: "Backend KYC verified")
            documentStore.save(docs[idx], leadID: lead.id)
        }

        self.documents = docs
        self.timeline  = LeadDetailViewModel.makeTimeline(for: lead)
        self.messages  = LeadDetailViewModel.makeMessages()
    }

    /// Called when loanAppVM persists updated KYC flags — syncs document statuses.
    func syncKYCDocuments(aadhaarVerified: Bool, panVerified: Bool, name: String, dob: String) {
        if aadhaarVerified, let idx = documents.firstIndex(where: { $0.kind == .aadhaar }), !documents[idx].status.isVerified {
            documents[idx].markVerified(
                identityData: IdentityVerificationData(fullName: name, documentNumber: "", dateOfBirth: dob),
                note: "Backend KYC verified"
            )
            documentStore.save(documents[idx], leadID: leadID)
        }
        if panVerified, let idx = documents.firstIndex(where: { $0.kind == .pan }), !documents[idx].status.isVerified {
            documents[idx].markVerified(
                identityData: IdentityVerificationData(fullName: name, documentNumber: "", dateOfBirth: dob),
                note: "Backend KYC verified"
            )
            documentStore.save(documents[idx], leadID: leadID)
        }
    }

    /// Merges backend product required-doc definitions into the local document list.
    /// Merges backend product required-doc definitions into the local document list.
    /// All docs are .supporting kind in the DST context (upload-only, no KYC flow).
    func syncRequiredDocuments(from requirements: [ProductRequiredDocument]) {
        guard !requirements.isEmpty else { return }

        // All backend required docs (identity + income + collateral) need upload slots
        let existingSupportingCount = documents.filter { $0.kind == .supporting }.count
        let neededExtra = max(0, requirements.count - existingSupportingCount)
        guard neededExtra > 0 else { return }

        let existingReqs = requirements.prefix(existingSupportingCount)
        let newReqs = requirements.dropFirst(existingSupportingCount)

        // Rename existing supporting docs to match product requirement types
        var supportingIdx = 0
        for req in existingReqs {
            while supportingIdx < documents.count && documents[supportingIdx].kind != .supporting {
                supportingIdx += 1
            }
            if supportingIdx < documents.count {
                let expectedName = req.requirementType.displayName
                if documents[supportingIdx].name != expectedName {
                    let updated = LeadDocument(
                        id: documents[supportingIdx].id,
                        name: expectedName,
                        kind: .supporting,
                        status: documents[supportingIdx].status,
                        verification: documents[supportingIdx].verification
                    )
                    documents[supportingIdx] = updated
                    documentStore.save(updated, leadID: leadID)
                }
                supportingIdx += 1
            }
        }

        // Append any genuinely new required docs
        for req in newReqs {
            let doc = LeadDocument(
                id: UUID(),
                name: req.requirementType.displayName,
                kind: .supporting,
                status: .notUploaded
            )
            documents.append(doc)
            documentStore.save(doc, leadID: leadID)
        }
    }


    func requestDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].requestUpload()
        documentStore.save(documents[idx], leadID: leadID)

        appendTimelineEvent(
            title: "\(documents[idx].name) Requested",
            description: "A request was sent to \(lead.name) to complete this document.",
            isRejected: false
        )
    }

    func markDocumentUploaded(id: UUID, fileName: String, mediaFileID: String? = nil) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].markUploaded(fileName: fileName)
        documentStore.save(documents[idx], leadID: leadID, mediaFileID: mediaFileID)

        appendTimelineEvent(
            title: "\(documents[idx].name) Uploaded",
            description: "\(fileName) uploaded and awaiting quick verification.",
            isRejected: false
        )
    }

    func verifyUploadedDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].markVerified(note: "Quick due diligence completed.")
        documentStore.save(documents[idx], leadID: leadID)

        appendTimelineEvent(
            title: "\(documents[idx].name) Verified",
            description: "Uploaded document cleared through quick due diligence.",
            isRejected: false
        )
    }

    func verifyIdentityDocument(id: UUID, data: IdentityVerificationData) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].markVerified(
            identityData: data,
            note: "Identity details verified via quick due diligence."
        )
        documentStore.save(documents[idx], leadID: leadID)

        appendTimelineEvent(
            title: "\(documents[idx].name) Verified",
            description: "\(data.fullName)'s KYC details were entered and verified.",
            isRejected: false
        )
    }

    func submitApplication() {
        onStatusUpdate?(lead.id, .submitted)
        showSubmitSuccess = true
    }

    func calculateEligibility(
        monthlyIncome: Double,
        existingEMIs: Double,
        loanAmount: Double,
        propertyValue: Double,
        cibilScore: Int
    ) -> EligibilityResult {
        let rate   = lead.loanType.defaultRate / 12.0 / 100.0
        let n      = Double(lead.loanType.defaultTenureMonths)
        let power  = pow(1 + rate, n)
        let emi    = loanAmount * rate * power / (power - 1)

        let totalEMI = existingEMIs + emi
        let foir     = totalEMI / monthlyIncome
        let ltv      = propertyValue > 0 ? loanAmount / propertyValue : 0

        let foirLimit = lead.loanType.foirLimit
        var factors: [String] = []
        var eligible = true

        if foir > foirLimit {
            factors.append("FOIR \(String(format: "%.1f", foir * 100))% exceeds \(Int(foirLimit * 100))% limit")
            eligible = false
        }
        if ltv > 0.90 {
            factors.append("LTV \(String(format: "%.1f", ltv * 100))% exceeds 90% limit")
            eligible = false
        }
        if cibilScore < 650 {
            factors.append("CIBIL score \(cibilScore) below minimum 650")
            eligible = false
        }
        if eligible {
            factors.append("All parameters within acceptable range")
        }

        return EligibilityResult(
            isEligible: eligible,
            foir: foir,
            ltv: ltv,
            proposedEMI: emi,
            totalEMI: totalEMI,
            keyFactors: factors,
            foirLimit: foirLimit
        )
    }

    private static func makeTimeline(for lead: Lead) -> [TimelineEvent] {
        [
            TimelineEvent(
                id: UUID(),
                title: "Lead Created",
                description: "Lead \(lead.name) created.",
                time: "10:00",
                isRejected: false
            ),
            TimelineEvent(
                id: UUID(),
                title: "KYC Pending",
                description: "Aadhaar and PAN details still need due diligence verification.",
                time: "10:10",
                isRejected: true
            ),
            TimelineEvent(
                id: UUID(),
                title: "Bank Statement Requested",
                description: "Loan officer requested the latest 6-month statement.",
                time: "10:25",
                isRejected: false
            ),
        ]
    }

    private static func makeMessages() -> [LeadMessage] {
        [
            LeadMessage(id: UUID(), sender: "Loan Officer", text: "Can you share the latest bank statement?", time: "10:24", isMe: false),
            LeadMessage(id: UUID(), sender: "You", text: "Will upload by evening.", time: "10:26", isMe: true),
        ]
    }

    private func appendTimelineEvent(title: String, description: String, isRejected: Bool) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        timeline.append(
            TimelineEvent(
                id: UUID(),
                title: title,
                description: description,
                time: formatter.string(from: Date()),
                isRejected: isRejected
            )
        )
    }
}
