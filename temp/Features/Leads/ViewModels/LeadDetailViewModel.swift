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
    /// KYC docs must be .verified; supporting docs must be at least .uploaded (not .notUploaded / .requested)
    var missingCount: Int {
        documents.filter { doc in
            switch doc.kind {
            case .aadhaar, .pan: return !doc.status.isVerified
            case .supporting:    return !doc.status.isUploaded
            }
        }.count
    }
    var canSubmit: Bool { missingCount == 0 }

    init(lead: Lead, onStatusUpdate: ((String, LeadStatus) -> Void)? = nil) {
        self.lead = lead
        self.onStatusUpdate = onStatusUpdate
        var docs = LeadDocument.defaultDocuments(for: lead.loanType)
        // Restore persisted KYC doc states
        if lead.isAadhaarKycVerified, let idx = docs.firstIndex(where: { $0.kind == .aadhaar }) {
            docs[idx].markVerified(
                identityData: IdentityVerificationData(
                    fullName: lead.aadhaarVerifiedName,
                    documentNumber: "",
                    dateOfBirth: lead.aadhaarVerifiedDOB
                ),
                note: "Backend KYC verified"
            )
        }
        if lead.isPanKycVerified, let idx = docs.firstIndex(where: { $0.kind == .pan }) {
            docs[idx].markVerified(
                identityData: IdentityVerificationData(
                    fullName: lead.aadhaarVerifiedName,
                    documentNumber: "",
                    dateOfBirth: lead.aadhaarVerifiedDOB
                ),
                note: "Backend KYC verified"
            )
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
        }
        if panVerified, let idx = documents.firstIndex(where: { $0.kind == .pan }), !documents[idx].status.isVerified {
            documents[idx].markVerified(
                identityData: IdentityVerificationData(fullName: name, documentNumber: "", dateOfBirth: dob),
                note: "Backend KYC verified"
            )
        }
    }

    func requestDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].requestUpload()

        appendTimelineEvent(
            title: "\(documents[idx].name) Requested",
            description: "A request was sent to \(lead.name) to complete this document.",
            isRejected: false
        )
    }

    func markDocumentUploaded(id: UUID, fileName: String) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].markUploaded(fileName: fileName)

        appendTimelineEvent(
            title: "\(documents[idx].name) Uploaded",
            description: "\(fileName) uploaded and awaiting quick verification.",
            isRejected: false
        )
    }

    func verifyUploadedDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents[idx].markVerified(note: "Quick due diligence completed.")

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
