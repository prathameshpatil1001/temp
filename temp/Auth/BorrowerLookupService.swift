import Foundation
import GRPCCore
import GRPCProtobuf
import GRPCNIOTransportHTTP2
import SwiftProtobuf

struct BorrowerLookupResult: Sendable {
    let userID: String
    let borrowerProfileID: String
    let displayName: String
}

struct BorrowerLookupService {
    private let tokenStore: TokenStore
    private let grpcClient: GRPCClient<HTTP2ClientTransport.Posix>

    init(
        tokenStore: TokenStore = .shared,
        grpcClient: GRPCClient<HTTP2ClientTransport.Posix> = GRPCChannelFactory.shared.client
    ) {
        self.tokenStore = tokenStore
        self.grpcClient = grpcClient
    }

    func resolveBorrower(email: String, phone: String) async throws -> BorrowerLookupResult? {
        let phoneDigits = phone.filter(\.isNumber)
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let queries = [normalizedEmail, phoneDigits].filter { !$0.isEmpty }
        guard !queries.isEmpty else { return nil }

        for query in queries {
            let items = try await searchBorrowerWithRetry(query: query)
            if let match = bestBorrowerMatch(
                from: items,
                normalizedEmail: normalizedEmail,
                phoneDigits: phoneDigits
            ) {
                let name = match.email.isEmpty ? match.phone : match.email
                return BorrowerLookupResult(userID: match.userID, borrowerProfileID: match.borrowerProfileID, displayName: name)
            }
        }

        return nil
    }

    private func bestBorrowerMatch(
        from items: [BorrowerSignupStatusSearchItem],
        normalizedEmail: String,
        phoneDigits: String
    ) -> BorrowerSignupStatusSearchItem? {
        let candidates = items.filter { !$0.borrowerProfileID.isEmpty }
        guard !candidates.isEmpty else { return nil }

        if !phoneDigits.isEmpty,
           let phoneExactMatch = candidates.first(where: { normalizedDigits($0.phone) == phoneDigits }) {
            return phoneExactMatch
        }

        if !normalizedEmail.isEmpty {
            let targetEmail = normalizedEmail.lowercased()
            if let emailExactMatch = candidates.first(where: { $0.email.lowercased() == targetEmail }) {
                return emailExactMatch
            }
        }

        return candidates.first
    }

    private func normalizedDigits(_ value: String) -> String {
        value.filter(\.isNumber)
    }

    private func searchBorrowerWithRetry(query: String) async throws -> [BorrowerSignupStatusSearchItem] {
        do {
            return try await searchBorrowerSignupStatus(query: query)
        } catch let rpcError as RPCError where rpcError.code == .cancelled {
            // Observed intermittent cancellations from transport; retry once.
            try await Task.sleep(for: .milliseconds(150))
            return try await searchBorrowerSignupStatus(query: query)
        }
    }

    private func searchBorrowerSignupStatus(query: String, limit: Int32 = 20, offset: Int32 = 0) async throws -> [BorrowerSignupStatusSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard let token = try tokenStore.accessToken(), !token.isEmpty else {
            throw AuthError.unauthenticated
        }

        var request = Auth_V1_SearchBorrowerSignupStatusRequest()
        request.query = trimmed
        request.limit = limit
        request.offset = offset

        let (options, metadata) = AuthCallOptionsFactory.authenticated(accessToken: token)
        let rpcRequest = ClientRequest<Auth_V1_SearchBorrowerSignupStatusRequest>(message: request, metadata: metadata)
        do {
            let response: ClientResponse<Auth_V1_SearchBorrowerSignupStatusResponse> = try await grpcClient.unary(
                request: rpcRequest,
                descriptor: MethodDescriptor(
                    service: ServiceDescriptor(fullyQualifiedService: "auth.v1.AuthService"),
                    method: "SearchBorrowerSignupStatus"
                ),
                serializer: ProtobufSerializer<Auth_V1_SearchBorrowerSignupStatusRequest>(),
                deserializer: ProtobufDeserializer<Auth_V1_SearchBorrowerSignupStatusResponse>(),
                options: options,
                onResponse: { $0 }
            )
            return try response.message.items.map(BorrowerSignupStatusSearchItem.init(proto:))
        } catch let rpcError as RPCError {
            let lowered = rpcError.message.lowercased()
            if rpcError.code == .failedPrecondition &&
                (lowered.contains("password change required") || lowered.contains("requiring_password_change")) {
                throw BorrowerLookupError.passwordChangeRequired
            }
            throw BorrowerLookupError.rpc(code: rpcError.code.rawValue, message: rpcError.message)
        }
    }
}

enum BorrowerLookupError: LocalizedError {
    case passwordChangeRequired
    case rpc(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .passwordChangeRequired:
            return "Password change is required for this DST account before borrower verification can continue. Please update your password and try again."
        case .rpc(let code, let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Borrower lookup failed (RPC code: \(code))."
                : "Borrower lookup failed (RPC code: \(code)): \(trimmed)"
        }
    }
}

private struct BorrowerSignupStatusSearchItem: Identifiable, Hashable, Sendable {
    let userID: String
    let email: String
    let phone: String
    let isActive: Bool
    let borrowerProfileID: String
    var id: String { userID }
    fileprivate init(proto: Auth_V1_BorrowerSignupStatusItem) {
        self.userID = proto.userID
        self.email = proto.email
        self.phone = proto.phone
        self.isActive = proto.isActive
        self.borrowerProfileID = proto.borrowerProfileID
    }
}

// All hand-rolled proto types below have been replaced by the generated Auth_V1_* types.
// The generated types live in Networking/Generated/auth/v1/auth.pb.swift and have
// correct field numbers from the _protobuf_nameMap bytecode.
