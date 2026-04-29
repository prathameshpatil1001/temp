import SwiftUI
import UniformTypeIdentifiers
import VisionKit

@available(iOS 18.0, *)
struct DocumentUploadView: View {
    let application: BorrowerLoanApplication

    @StateObject private var viewModel = DocumentUploadViewModel()
    @EnvironmentObject private var router: AppRouter

    @State private var currentApplication: BorrowerLoanApplication
    @State private var product: LoanProduct?
    @State private var selectedRequirement: ProductRequiredDocument?
    @State private var activeRequirementForReview: ProductRequiredDocument?
    @State private var isImporterPresented = false
    @State private var isSourceDialogPresented = false
    @State private var isScannerPresented = false
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var previewDocument: LocalDocumentCandidate?
    @State private var validationSummary: LocalDocumentValidationSummary?
    @State private var reviewPhase: ReviewPhase = .idle

    private let loanService: LoanServiceProtocol
    private let validator = LocalDocumentValidationService()

    init(
        application: BorrowerLoanApplication,
        loanService: LoanServiceProtocol = ServiceContainer.loanService
    ) {
        self.application = application
        self.loanService = loanService
        _currentApplication = State(initialValue: application)
    }

    private var requiredDocuments: [ProductRequiredDocument] {
        product?.requiredDocuments ?? []
    }

    private var allMandatoryDocumentsUploaded: Bool {
        if requiredDocuments.isEmpty {
            return true
        }

        return requiredDocuments
            .filter(\.isMandatory)
            .allSatisfy { attachedDocument(for: $0) != nil }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    } else if let error = loadError {
                        errorSection(error)
                    } else {
                        documentListSection
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            footerSection
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadData()
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.image, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
        .confirmationDialog(
            "Add Document",
            isPresented: $isSourceDialogPresented,
            titleVisibility: .visible
        ) {
            if VNDocumentCameraViewController.isSupported {
                Button("Scan Document") {
                    isScannerPresented = true
                }
            }
            Button("Choose File") {
                isImporterPresented = true
            }
            Button("Cancel", role: .cancel) {
                selectedRequirement = nil
            }
        } message: {
            Text("Capture a clean document or choose an image/PDF to validate before upload.")
        }
        .sheet(isPresented: $isScannerPresented, onDismiss: {
            if previewDocument == nil {
                selectedRequirement = nil
            }
        }) {
            DocumentScannerSheet { pages in
                handleScannedPages(pages)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { previewDocument != nil },
                set: { presented in
                    if !presented {
                        resetPreviewState()
                    }
                }
            )
        ) {
            documentReviewSheet
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Upload Documents")
                .font(.largeTitle).bold()
            Text("Required documents are loaded from the selected product configuration.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Application ID: \(currentApplication.referenceNumber)")
                .font(.caption.monospaced())
                .foregroundColor(.secondaryBlue)
        }
    }

    private var documentListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if requiredDocuments.isEmpty {
                Text("No required documents are configured for this product.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ForEach(requiredDocuments, id: \.id) { requirement in
                    documentCard(requirement)
                }
            }

            if let error = viewModel.overallError {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func documentCard(_ requirement: ProductRequiredDocument) -> some View {
        let attached = attachedDocument(for: requirement)
        let uploadState = viewModel.uploadStates[requirement.id]

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(statusTint(for: attached, uploadState: uploadState).opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon(for: requirement))
                        .font(.title3)
                        .foregroundColor(statusTint(for: attached, uploadState: uploadState))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(requirement.requirementType.displayName)
                            .font(.headline)
                        if requirement.isMandatory {
                            Text("Mandatory")
                                .font(.caption2).bold()
                                .foregroundColor(.alertRed)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }

                    Text(statusText(for: attached, uploadState: uploadState))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                trailingControl(for: requirement, attached: attached, uploadState: uploadState)
            }

            if let attached {
                HStack {
                    statusPill(title: attached.verificationStatus.displayName, color: attached.verificationStatus.color)
                    Text("Uploaded \(formattedDate(attached.createdAt))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private func trailingControl(
        for requirement: ProductRequiredDocument,
        attached: BorrowerApplicationDocument?,
        uploadState: DocumentUploadViewModel.DocUploadState?
    ) -> some View {
        switch uploadState {
        case .uploading:
            ProgressView()
                .frame(width: 32, height: 32)
        default:
            Button {
                selectedRequirement = requirement
                isSourceDialogPresented = true
            } label: {
                if attached != nil {
                    Text("Replace")
                        .font(.subheadline).bold()
                        .foregroundColor(.mainBlue)
                } else {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.secondaryBlue)
                        .padding(10)
                        .background(DS.primaryLight)
                        .clipShape(Circle())
                }
            }
        }
    }

    private var footerSection: some View {
        VStack {
            Divider()
            Button {
                router.push(.reviewApplication(currentApplication))
            } label: {
                Text("Review Application")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(allMandatoryDocumentsUploaded ? DS.primary : Color.secondary.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!allMandatoryDocumentsUploaded)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private func reloadData() async {
        isLoading = true
        loadError = nil
        do {
            async let fetchedApplication = loanService.getLoanApplication(applicationId: currentApplication.id)
            async let fetchedProduct = loanService.getLoanProduct(productId: currentApplication.loanProductId)
            currentApplication = try await fetchedApplication
            product = try await fetchedProduct
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? "Failed to load document requirements"
        }
        isLoading = false
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard let requirement = selectedRequirement else { return }

        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    try await prepareAndValidateDocument(
                        requirement: requirement,
                        candidate: validator.makeCandidate(fromFileAt: url)
                    )
                } catch {
                    viewModel.overallError = error.localizedDescription
                    resetPreviewState()
                }
            }
        case .failure(let error):
            viewModel.overallError = error.localizedDescription
            resetPreviewState()
        }
    }

    private func handleScannedPages(_ pages: [UIImage]) {
        guard let requirement = selectedRequirement else { return }

        Task {
            do {
                try await prepareAndValidateDocument(
                    requirement: requirement,
                    candidate: validator.makeCandidate(fromScannedPages: pages)
                )
            } catch {
                viewModel.overallError = error.localizedDescription
                resetPreviewState()
            }
        }
    }

    private func prepareAndValidateDocument(
        requirement: ProductRequiredDocument,
        candidate: LocalDocumentCandidate
    ) async throws {
        await MainActor.run {
            activeRequirementForReview = requirement
            previewDocument = candidate
            validationSummary = nil
            reviewPhase = .validating
            viewModel.overallError = nil
            selectedRequirement = nil
        }

        let summary = await validator.validate(candidate)

        await MainActor.run {
            validationSummary = summary
        }

        guard summary.isAccepted else {
            await MainActor.run {
                reviewPhase = .failed(summary.failureMessage)
                viewModel.overallError = summary.failureMessage
            }
            return
        }

        await MainActor.run {
            reviewPhase = .uploading
        }

        let didUpload = await viewModel.uploadDocument(
            applicationId: currentApplication.id,
            borrowerProfileId: currentApplication.primaryBorrowerProfileId,
            requiredDocId: requirement.id,
            fileData: candidate.data,
            mimeType: candidate.mimeType
        )

        if didUpload {
            do {
                currentApplication = try await loanService.getLoanApplication(applicationId: currentApplication.id)
                await MainActor.run {
                    reviewPhase = .uploaded
                }
            } catch {
                await MainActor.run {
                    reviewPhase = .uploadFailed("Upload succeeded, but refresh failed.")
                    viewModel.overallError = (error as? LocalizedError)?.errorDescription ?? "Upload succeeded, but refresh failed."
                }
            }
        } else {
            await MainActor.run {
                reviewPhase = .uploadFailed(viewModel.overallError ?? "Upload failed")
            }
        }
    }

    private func attachedDocument(for requirement: ProductRequiredDocument) -> BorrowerApplicationDocument? {
        currentApplication.documents.first(where: { $0.requiredDocId == requirement.id })
    }

    private func statusText(
        for attached: BorrowerApplicationDocument?,
        uploadState: DocumentUploadViewModel.DocUploadState?
    ) -> String {
        if let attached {
            return "Backend status: \(attached.verificationStatus.displayName)"
        }
        if case .failed(let message) = uploadState {
            return message
        }
        if case .uploading = uploadState {
            return "Uploading to media service..."
        }
        return "Tap to attach a real file"
    }

    private func statusTint(
        for attached: BorrowerApplicationDocument?,
        uploadState: DocumentUploadViewModel.DocUploadState?
    ) -> Color {
        if let attached {
            return attached.verificationStatus.color
        }
        if case .failed = uploadState {
            return .red
        }
        if case .uploading = uploadState {
            return .orange
        }
        return .mainBlue
    }

    private func icon(for requirement: ProductRequiredDocument) -> String {
        switch requirement.requirementType {
        case .identity:
            return "person.text.rectangle"
        case .address:
            return "building.columns.fill"
        case .income:
            return "doc.text.fill"
        case .collateral:
            return "doc.badge.ellipsis"
        default:
            return "doc"
        }
    }

    private func formattedDate(_ raw: String) -> String {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return raw
    }

    private func mimeType(for url: URL) -> String {
        if let type = UTType(filenameExtension: url.pathExtension) {
            return type.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }

    private func statusPill(title: String, color: Color) -> some View {
        Text(title)
            .font(.caption2).bold()
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await reloadData() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var documentReviewSheet: some View {
        if let previewDocument, let requirement = activeRequirementForReview {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        previewCard(for: previewDocument)
                        validationCard(for: requirement, summary: validationSummary)
                    }
                    .padding(20)
                }
                .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
                .navigationTitle("Document Check")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            resetPreviewState()
                        }
                        .disabled(reviewPhase == .uploading)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func previewCard(for candidate: LocalDocumentCandidate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)

            Group {
                if candidate.isPDF {
                    VStack(spacing: 12) {
                        Image(uiImage: candidate.previewImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16))

                        Label("\(candidate.pageCount) page PDF", systemImage: "doc.richtext")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(uiImage: candidate.previewImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func validationCard(
        for requirement: ProductRequiredDocument,
        summary: LocalDocumentValidationSummary?
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(requirement.requirementType.displayName)
                .font(.headline)

            Text(reviewStatusText)
                .font(.subheadline)
                .foregroundColor(reviewStatusColor)

            if let summary {
                validationRow("Blur check", passed: summary.blurPassed)

                if summary.runsEdgeDetection {
                    validationRow("Edge detection", passed: summary.edgePassed)
                }

                validationRow("Readable text", passed: summary.hasText)
                validationRow(
                    "OCR confidence",
                    passed: summary.textConfidencePassed,
                    detail: summary.hasText ? "\(Int(summary.averageTextConfidence * 100))%" : nil
                )
            } else if reviewPhase == .validating || reviewPhase == .uploading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            reviewActionArea
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func validationRow(_ title: String, passed: Bool, detail: String? = nil) -> some View {
        HStack {
            Image(systemName: passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(passed ? .green : .red)
            Text(title)
                .font(.subheadline)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var reviewActionArea: some View {
        switch reviewPhase {
        case .failed:
            Button("Retake") {
                resetPreviewState()
            }
            .buttonStyle(.borderedProminent)
        case .uploadFailed:
            Button("Try Again") {
                resetPreviewState()
            }
            .buttonStyle(.borderedProminent)
        case .uploaded:
            Button("Done") {
                resetPreviewState()
            }
            .buttonStyle(.borderedProminent)
        default:
            EmptyView()
        }
    }

    private var reviewStatusText: String {
        switch reviewPhase {
        case .idle:
            return ""
        case .validating:
            return "Checking document quality and text readability."
        case .failed(let message):
            return message
        case .uploading:
            return "Document looks good. Uploading now."
        case .uploaded:
            return "Document uploaded successfully."
        case .uploadFailed(let message):
            return message
        }
    }

    private var reviewStatusColor: Color {
        switch reviewPhase {
        case .failed, .uploadFailed:
            return .red
        case .uploaded:
            return .green
        default:
            return .secondary
        }
    }

    private func resetPreviewState() {
        previewDocument = nil
        validationSummary = nil
        activeRequirementForReview = nil
        reviewPhase = .idle
        selectedRequirement = nil
    }
}

@available(iOS 18.0, *)
private enum ReviewPhase: Equatable {
    case idle
    case validating
    case failed(String)
    case uploading
    case uploaded
    case uploadFailed(String)
}

@available(iOS 18.0, *)
private struct DocumentScannerSheet: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerSheet

        init(parent: DocumentScannerSheet) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let pages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parent.onComplete(pages)
            controller.dismiss(animated: true)
        }
    }
}

@available(iOS 18.0, *)
#Preview {
    NavigationStack {
        DocumentUploadView(
            application: BorrowerLoanApplication(
                id: UUID().uuidString,
                referenceNumber: "APP-001",
                primaryBorrowerProfileId: UUID().uuidString,
                loanProductId: UUID().uuidString,
                loanProductName: "Personal Loan",
                branchId: UUID().uuidString,
                branchName: "Main Branch",
                requestedAmount: "250000",
                tenureMonths: 24,
                status: .submitted,
                escalationReason: "",
                offeredInterestRate: "10.5",
                disbursementAccountNumber: "123456789012",
                disbursementIfscCode: "HDFC0001234",
                disbursementBankName: "HDFC Bank",
                disbursementAccountHolderName: "Ravi Kumar",
                createdAt: "",
                updatedAt: "",
                documents: []
            )
        )
        .environmentObject(AppRouter())
    }
}
