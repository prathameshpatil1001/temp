import Foundation
import SwiftUI
import GRPCCore
import Combine

@MainActor
@available(iOS 18.0, *)
final class DocumentUploadViewModel: ObservableObject {
    @Published var uploadStates: [String: DocUploadState] = [:]
    @Published var overallError: String? = nil

    enum DocUploadState {
        case idle
        case uploading
        case uploaded(mediaFileId: String)
        case failed(String)
    }

    private let loanService: LoanServiceProtocol
    private let mediaClient: MediaGRPCClientProtocol
    private let tokenStore: TokenStore

    init(
        loanService: LoanServiceProtocol = ServiceContainer.loanService,
        mediaClient: MediaGRPCClientProtocol = MediaGRPCClient(),
        tokenStore: TokenStore = .shared
    ) {
        self.loanService = loanService
        self.mediaClient = mediaClient
        self.tokenStore = tokenStore
    }

    func uploadDocument(
        applicationId: String,
        borrowerProfileId: String,
        requiredDocId: String,
        fileData: Data,
        mimeType: String
    ) async -> Bool {
        uploadStates[requiredDocId] = .uploading
        overallError = nil

        do {
            let (options, metadata) = try authContext()
            var initiateReq = Media_V1_InitiateMediaUploadRequest()
            initiateReq.fileName = "doc-\(requiredDocId)"
            initiateReq.contentType = mimeType
            initiateReq.sizeBytes = Int64(fileData.count)
            let initiateResp = try await mediaClient.initiateMediaUpload(
                request: initiateReq,
                metadata: metadata,
                options: options
            )

            try await uploadFileData(
                fileData,
                uploadURLString: initiateResp.uploadURL,
                mimeType: mimeType,
                method: initiateResp.uploadMethod
            )

            var completeReq = Media_V1_CompleteMediaUploadRequest()
            completeReq.objectKey = initiateResp.objectKey
            completeReq.fileName = initiateReq.fileName
            completeReq.contentType = mimeType
            completeReq.sizeBytes = Int64(fileData.count)
            let completeResp = try await mediaClient.completeMediaUpload(
                request: completeReq,
                metadata: metadata,
                options: options
            )
            let mediaFileId = completeResp.mediaID

            _ = try await loanService.addApplicationDocument(
                applicationId: applicationId,
                borrowerProfileId: borrowerProfileId,
                requiredDocId: requiredDocId,
                mediaFileId: mediaFileId
            )

            uploadStates[requiredDocId] = .uploaded(mediaFileId: mediaFileId)
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Upload failed"
            uploadStates[requiredDocId] = .failed(message)
            overallError = message
            return false
        }
    }

    var allRequiredDocumentsUploaded: Bool {
        !uploadStates.isEmpty && uploadStates.values.allSatisfy {
            if case .uploaded = $0 { return true }
            return false
        }
    }

    private func authContext() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw MediaError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    private func uploadFileData(
        _ data: Data,
        uploadURLString: String,
        mimeType: String,
        method: String
    ) async throws {
        guard let url = URL(string: uploadURLString) else {
            throw UploadClientError.invalidUploadURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.isEmpty ? "PUT" : method
        request.httpBody = data
        request.setValue(mimeType, forHTTPHeaderField: "Content-Type")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UploadClientError.uploadFailed
        }
    }
}

@available(iOS 18.0, *)
private enum UploadClientError: LocalizedError {
    case invalidUploadURL
    case uploadFailed

    var errorDescription: String? {
        switch self {
        case .invalidUploadURL:
            return "Invalid upload URL from media service."
        case .uploadFailed:
            return "Media upload failed."
        }
    }
}
