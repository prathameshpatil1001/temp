import SwiftUI
import PhotosUI

@available(iOS 18.0, *)
struct DocumentSectionView: View {
    @ObservedObject var vm: LeadDetailViewModel
    @ObservedObject var loanAppVM: LoanApplicationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DOCUMENTS (\(vm.uploadedCount)/\(vm.totalCount))")
                    .font(AppFont.captionMed())
                    .foregroundColor(Color.textTertiary)
                    .tracking(0.6)
                Spacer()
                if vm.missingCount > 0 {
                    Text("\(vm.missingCount) Missing")
                        .font(AppFont.captionMed())
                        .foregroundColor(Color.statusRejected)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(vm.documents.enumerated()), id: \.element.id) { idx, doc in
                    DocumentRowView(
                        document: doc,
                        loanAppVM: loanAppVM,
                        onRequest: { vm.requestDocument(id: doc.id) },
                        onUpload: { fileName, data in 
                            Task {
                                let success = await loanAppVM.uploadDocument(id: doc.id, data: data, fileName: fileName, contentType: "image/jpeg")
                                if success {
                                    vm.markDocumentUploaded(id: doc.id, fileName: fileName)
                                    vm.verifyUploadedDocument(id: doc.id)
                                }
                            }
                        },
                        onVerifyIdentity: { data in vm.verifyIdentityDocument(id: doc.id, data: data) }
                    )

                    if idx < vm.documents.count - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
        }
    }
}

@available(iOS 18.0, *)
struct DocumentRowView: View {
    let document: LeadDocument
    @ObservedObject var loanAppVM: LoanApplicationViewModel
    let onRequest: () -> Void
    let onUpload: (String, Data) -> Void
    let onVerifyIdentity: (IdentityVerificationData) -> Void

    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showRequestAlert = false
    @State private var showIdentitySheet = false

    private var isVerified: Bool { document.status.isVerified }
    private var isAwaitingVerification: Bool { document.status.isAwaitingVerification }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(statusColor.opacity(0.10))
                    .frame(width: 40, height: 40)

                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.name)
                    .font(AppFont.bodyMedium())
                    .foregroundColor(Color.textPrimary)
                    .lineLimit(1)

                Text(statusText)
                    .font(AppFont.caption())
                    .foregroundColor(statusColor)

                if let identityData = document.verification?.identityData, isVerified {
                    Text("\(identityData.fullName) · \(identityData.documentNumber)")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            actionsView
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 13)
        .sheet(isPresented: $showIdentitySheet) {
            if document.kind == .aadhaar {
                AadhaarKYCFlowView(viewModel: loanAppVM, document: document, onVerify: onVerifyIdentity)
                    .presentationDetents([.medium, .large])
            } else if document.kind == .pan {
                PANVerifySheet(viewModel: loanAppVM, document: document, onVerify: onVerifyIdentity)
                    .presentationDetents([.medium, .large])
            }
        }
        .alert(
            document.kind.requiresIdentityDetails ? "KYC Request Sent" : "Request Sent",
            isPresented: $showRequestAlert
        ) {
            Button("OK", role: .cancel) {
                onRequest()
            }
        } message: {
            Text(
                document.kind.requiresIdentityDetails
                    ? "Borrower has been asked to enter identity details for quick due diligence."
                    : "Document request sent to borrower via SMS and WhatsApp."
            )
        }
    }

    @ViewBuilder
    private var actionsView: some View {
        if isVerified {
            Image(systemName: "doc.text")
                .font(.system(size: 18))
                .foregroundColor(Color.textTertiary)
        } else if document.kind.requiresIdentityDetails {
            HStack(spacing: 8) {
                Button {
                    showIdentitySheet = true
                } label: {
                    Text(document.status.requestedAt == nil ? "Enter Details" : "Complete")
                        .font(AppFont.captionMed())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color.brandBlue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                requestButton
            }
        } else if isAwaitingVerification {
            ProgressView()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        } else {
            HStack(spacing: 8) {
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: "camera")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Upload")
                            .font(AppFont.captionMed())
                    }
                    .foregroundColor(Color.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.surfaceTertiary)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.borderLight, lineWidth: 1))
                }
                .onChange(of: selectedItem) { newVal in
                    if let item = newVal {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                onUpload("\(document.name) Scan", data)
                            }
                            selectedItem = nil
                        }
                    }
                }

                requestButton
            }
        }
    }

    private var requestButton: some View {
        Button { showRequestAlert = true } label: {
            Image(systemName: "paperplane")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color.brandBlue)
                .frame(width: 32, height: 32)
                .background(Color.brandBlue.opacity(0.12))
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(Color.brandBlue.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var statusIcon: String {
        switch document.status {
        case .verified: return "checkmark.seal.fill"
        case .uploaded, .pending: return "clock.badge.checkmark"
        case .requested: return "paperplane.fill"
        case .notUploaded: return "exclamationmark.circle"
        }
    }

    private var statusColor: Color {
        switch document.status {
        case .verified: return .brandBlue
        case .uploaded, .pending: return .statusPending
        case .requested: return .statusSubmitted
        case .notUploaded: return .statusRejected
        }
    }

    private var statusText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"

        switch document.status {
        case .verified(let date):
            return "Verified · \(formatter.string(from: date))"
        case .requested(let date):
            return "Requested · \(formatter.string(from: date))"
        case .uploaded(let fileName, let date):
            return "\(fileName) · \(formatter.string(from: date))"
        case .pending:
            return "Uploaded · Awaiting quick due diligence"
        case .notUploaded:
            return document.kind.requiresIdentityDetails ? "Details not entered yet" : "Not Uploaded"
        }
    }
}

@available(iOS 18.0, *)
struct IdentityVerificationSheet: View {
    let document: LeadDocument
    let onVerify: (IdentityVerificationData) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var fullName: String = ""
    @State private var documentNumber: String = ""
    @State private var dateOfBirth: String = ""

    private var formTitle: String {
        document.kind == .aadhaar ? "Complete Aadhaar Verification" : "Complete PAN Verification"
    }

    private var documentPrompt: String {
        document.kind == .aadhaar ? "Aadhaar Number" : "PAN Number"
    }

    private var canVerify: Bool {
        IdentityVerificationData(
            fullName: fullName,
            documentNumber: documentNumber,
            dateOfBirth: dateOfBirth
        ).isComplete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Borrower Details") {
                    TextField("Full Name", text: $fullName)
                    TextField(documentPrompt, text: $documentNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Date of Birth (DD/MM/YYYY)", text: $dateOfBirth)
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick Due Diligence")
                            .font(AppFont.bodyMedium())
                        Text("The document becomes verified only after borrower details are entered and this quick review is completed.")
                            .font(AppFont.caption())
                            .foregroundColor(Color.textSecondary)
                    }
                }
            }
            .navigationTitle(formTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verify") {
                        onVerify(
                            IdentityVerificationData(
                                fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
                                documentNumber: documentNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                                dateOfBirth: dateOfBirth.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canVerify)
                }
            }
        }
    }
}
