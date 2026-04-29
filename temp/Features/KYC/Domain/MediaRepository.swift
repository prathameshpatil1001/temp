import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2

@available(iOS 18.0, *)
@MainActor
public final class MediaRepository: Sendable {
    public struct UploadedMedia: Sendable {
        public let mediaID: String
        public let fileURL: String
        public let fileName: String
        public let contentType: String
        public let sizeBytes: Int64
    }

    private let mediaClient: MediaGRPCClientProtocol
    private let tokenStore: TokenStore
    private let urlSession: URLSession

    public nonisolated init(
        mediaClient: MediaGRPCClientProtocol = MediaGRPCClient(),
        tokenStore: TokenStore = .shared,
        urlSession: URLSession = .shared
    ) {
        self.mediaClient = mediaClient
        self.tokenStore = tokenStore
        self.urlSession = urlSession
    }

    private func authMetadata() throws -> (options: CallOptions, metadata: Metadata) {
        guard let token = try tokenStore.accessToken() else {
            throw MediaError.unauthenticated
        }
        return AuthCallOptionsFactory.authenticated(accessToken: token)
    }

    public func uploadMedia(
        fileData: Data,
        fileName: String,
        contentType: String,
        note: String
    ) async throws -> UploadedMedia {
        let (options, metadata) = try authMetadata()
        var initiateReq = Media_V1_InitiateMediaUploadRequest()
        initiateReq.fileName = fileName
        initiateReq.contentType = contentType
        initiateReq.sizeBytes = Int64(fileData.count)
        initiateReq.note = note

        let initiateResp = try await mediaClient.initiateMediaUpload(request: initiateReq, metadata: metadata, options: options)
        guard initiateResp.success, !initiateResp.objectKey.isEmpty, !initiateResp.uploadURL.isEmpty else {
            throw MediaError.uploadFailed("Unable to initiate media upload.")
        }

        try await putFileBytes(
            data: fileData,
            uploadURLString: initiateResp.uploadURL,
            contentType: contentType
        )

        var completeReq = Media_V1_CompleteMediaUploadRequest()
        completeReq.objectKey = initiateResp.objectKey
        completeReq.note = note
        completeReq.fileName = fileName
        completeReq.contentType = contentType
        completeReq.sizeBytes = Int64(fileData.count)

        let completeResp = try await mediaClient.completeMediaUpload(request: completeReq, metadata: metadata, options: options)
        guard completeResp.success else {
            throw MediaError.uploadFailed("Upload did not complete on server.")
        }

        return UploadedMedia(
            mediaID: completeResp.mediaID,
            fileURL: completeResp.fileURL,
            fileName: fileName,
            contentType: contentType,
            sizeBytes: Int64(fileData.count)
        )
    }

    private func putFileBytes(data: Data, uploadURLString: String, contentType: String) async throws {
        guard let url = URL(string: uploadURLString) else {
            throw MediaError.invalidInput("Invalid upload URL returned by server.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw MediaError.uploadFailed("File bytes upload failed.")
        }
    }
}
