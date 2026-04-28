import Foundation
import GRPCCore
import SwiftProtobuf
import GRPCProtobuf
import SwiftProtobuf

@available(iOS 18.0, *)
struct AuthAPI {
    func loginPrimary(emailOrPhone: String, password: String) async throws -> Auth_V1_LoginPrimaryResponse {
        let request: Auth_V1_LoginRequest = {
            var req = Auth_V1_LoginRequest()
            req.emailOrPhone = emailOrPhone
            req.password = password
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.loginPrimary(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func selectLoginMFAFactor(mfaSessionID: String, factor: String) async throws -> Auth_V1_SelectLoginMFAFactorResponse {
        let request: Auth_V1_SelectLoginMFAFactorRequest = {
            var req = Auth_V1_SelectLoginMFAFactorRequest()
            req.mfaSessionID = mfaSessionID
            req.factor = factor
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.selectLoginMFAFactor(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func verifyLoginMFA(
        mfaSessionID: String,
        method: MFAMethod,
        otpCode: String,
        deviceID: String
    ) async throws -> Auth_V1_AuthTokens {
        let request: Auth_V1_VerifyLoginMFARequest = {
            var req = Auth_V1_VerifyLoginMFARequest()
            req.mfaSessionID = mfaSessionID
            req.deviceID = deviceID
            switch method {
            case .email:
                req.factor = .emailOtpCode(otpCode)
            case .sms:
                req.factor = .phoneOtpCode(otpCode)
            }
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.verifyLoginMFA(request, metadata: CoreAPIClient.anonymousMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func getMyProfile() async throws -> Auth_V1_GetMyProfileResponse {
        let request = Auth_V1_GetMyProfileRequest()
        do {
            return try await CoreAPIClient.withAuthorizedClient { client, metadata in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.getMyProfile(request, metadata: metadata)
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func searchBorrowerSignupStatus(query: String, limit: Int32 = 20, offset: Int32 = 0) async throws -> [BorrowerSignupStatusSearchItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let request: Auth_SearchBorrowerSignupStatusRequest = {
            var req = Auth_SearchBorrowerSignupStatusRequest()
            req.query = trimmed
            req.limit = limit
            req.offset = offset
            return req
        }()

        do {
            return try await CoreAPIClient.withAuthorizedClient { client, metadata in
                let rpcRequest = ClientRequest<Auth_SearchBorrowerSignupStatusRequest>(
                    message: request,
                    metadata: metadata
                )
                let response: ClientResponse<Auth_SearchBorrowerSignupStatusResponse> = try await client.unary(
                    request: rpcRequest,
                    descriptor: MethodDescriptor(
                        service: ServiceDescriptor(fullyQualifiedService: "auth.v1.AuthService"),
                        method: "SearchBorrowerSignupStatus"
                    ),
                    serializer: GRPCProtobuf.ProtobufSerializer<Auth_SearchBorrowerSignupStatusRequest>(),
                    deserializer: GRPCProtobuf.ProtobufDeserializer<Auth_SearchBorrowerSignupStatusResponse>(),
                    options: .defaults,
                    onResponse: { response in response }
                )
                let message = try response.message
                return message.items.map(BorrowerSignupStatusSearchItem.init(proto:))
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async throws -> Auth_V1_ChangePasswordResponse {
        let request: Auth_V1_ChangePasswordRequest = {
            var req = Auth_V1_ChangePasswordRequest()
            req.currentPassword = currentPassword
            req.newPassword = newPassword
            return req
        }()

        do {
            return try await CoreAPIClient.withAuthorizedClient { client, metadata in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.changePassword(request, metadata: metadata)
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func logout(accessToken: String, refreshToken: String) async throws -> Auth_V1_LogoutResponse {
        let request: Auth_V1_LogoutRequest = {
            var req = Auth_V1_LogoutRequest()
            req.accessToken = accessToken
            req.refreshToken = refreshToken
            return req
        }()

        do {
            return try await CoreAPIClient.withAuthorizedClient { client, metadata in
                let auth = Auth_V1_AuthService.Client(wrapping: client)
                return try await auth.logout(request, metadata: metadata)
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func searchBorrowerSignupStatus(query: String, limit: Int32, offset: Int32) async throws -> Auth_V1_SearchBorrowerSignupStatusResponse {
        var req = Auth_V1_SearchBorrowerSignupStatusRequest()
        req.query = query
        req.limit = limit
        req.offset = offset
        
        let descriptor = GRPCCore.MethodDescriptor(
            service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "auth.v1.AuthService"),
            method: "SearchBorrowerSignupStatus"
        )

        let metadata = await CoreAPIClient.authorizedMetadata()
        return try await CoreAPIClient.withClient { client in
            try await client.unary(
                request: .init(message: req, metadata: metadata),
                descriptor: descriptor,
                serializer: GRPCProtobuf.ProtobufSerializer<Auth_V1_SearchBorrowerSignupStatusRequest>(),
                deserializer: GRPCProtobuf.ProtobufDeserializer<Auth_V1_SearchBorrowerSignupStatusResponse>(),
                options: .defaults
            ) { response in
                try response.message
            }
        }
    }
}

// MARK: - Manual Proto Definitions for SearchBorrowerSignupStatus

struct Auth_V1_SearchBorrowerSignupStatusRequest: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusRequest"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{5}query\0\u{5}limit\0\u{6}offset\0")

    var query: String = ""
    var limit: Int32 = 0
    var offset: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &query)
            case 2: try decoder.decodeSingularInt32Field(value: &limit)
            case 3: try decoder.decodeSingularInt32Field(value: &offset)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !query.isEmpty { try visitor.visitSingularStringField(value: query, fieldNumber: 1) }
        if limit != 0 { try visitor.visitSingularInt32Field(value: limit, fieldNumber: 2) }
        if offset != 0 { try visitor.visitSingularInt32Field(value: offset, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.query == rhs.query && lhs.limit == rhs.limit && lhs.offset == rhs.offset
    }
}

struct Auth_V1_BorrowerSignupStatusItem: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.BorrowerSignupStatusItem"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{7}user_id\0\u{5}email\0\u{5}phone\0\u{11}is_email_verified\0\u{11}is_phone_verified\0\u{9}is_active\0\u{14}onboarding_completed\0\u{D}kyc_completed\0\u{13}borrower_profile_id\0\u{C}signup_stage\0")

    var userId: String = ""
    var email: String = ""
    var phone: String = ""
    var isEmailVerified: Bool = false
    var isPhoneVerified: Bool = false
    var isActive: Bool = false
    var onboardingCompleted: Bool = false
    var kycCompleted: Bool = false
    var borrowerProfileId: String = ""
    var signupStage: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeSingularStringField(value: &userId)
            case 2: try decoder.decodeSingularStringField(value: &email)
            case 3: try decoder.decodeSingularStringField(value: &phone)
            case 4: try decoder.decodeSingularBoolField(value: &isEmailVerified)
            case 5: try decoder.decodeSingularBoolField(value: &isPhoneVerified)
            case 6: try decoder.decodeSingularBoolField(value: &isActive)
            case 7: try decoder.decodeSingularBoolField(value: &onboardingCompleted)
            case 8: try decoder.decodeSingularBoolField(value: &kycCompleted)
            case 9: try decoder.decodeSingularStringField(value: &borrowerProfileId)
            case 10: try decoder.decodeSingularStringField(value: &signupStage)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !userId.isEmpty { try visitor.visitSingularStringField(value: userId, fieldNumber: 1) }
        if !email.isEmpty { try visitor.visitSingularStringField(value: email, fieldNumber: 2) }
        if !phone.isEmpty { try visitor.visitSingularStringField(value: phone, fieldNumber: 3) }
        if isEmailVerified { try visitor.visitSingularBoolField(value: isEmailVerified, fieldNumber: 4) }
        if isPhoneVerified { try visitor.visitSingularBoolField(value: isPhoneVerified, fieldNumber: 5) }
        if isActive { try visitor.visitSingularBoolField(value: isActive, fieldNumber: 6) }
        if onboardingCompleted { try visitor.visitSingularBoolField(value: onboardingCompleted, fieldNumber: 7) }
        if kycCompleted { try visitor.visitSingularBoolField(value: kycCompleted, fieldNumber: 8) }
        if !borrowerProfileId.isEmpty { try visitor.visitSingularStringField(value: borrowerProfileId, fieldNumber: 9) }
        if !signupStage.isEmpty { try visitor.visitSingularStringField(value: signupStage, fieldNumber: 10) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.userId == rhs.userId && lhs.email == rhs.email && lhs.phone == rhs.phone && lhs.isEmailVerified == rhs.isEmailVerified && lhs.isPhoneVerified == rhs.isPhoneVerified && lhs.isActive == rhs.isActive && lhs.onboardingCompleted == rhs.onboardingCompleted && lhs.kycCompleted == rhs.kycCompleted && lhs.borrowerProfileId == rhs.borrowerProfileId && lhs.signupStage == rhs.signupStage
    }
}

struct Auth_V1_SearchBorrowerSignupStatusResponse: Sendable, SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    static let protoMessageName = "auth.v1.SearchBorrowerSignupStatusResponse"
    static let _protobuf_nameMap: SwiftProtobuf._NameMap = SwiftProtobuf._NameMap(bytecode: "\0\u{5}items\0")

    var items: [Auth_V1_BorrowerSignupStatusItem] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()

    init() {}
    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let f = try decoder.nextFieldNumber() {
            switch f {
            case 1: try decoder.decodeRepeatedMessageField(value: &items)
            default: break
            }
        }
    }
    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !items.isEmpty { try visitor.visitRepeatedMessageField(value: items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    static func ==(lhs: Self, rhs: Self) -> Bool {
        return lhs.items == rhs.items
    }
}

struct BorrowerSignupStatusSearchItem: Identifiable, Hashable {
    let userID: String
    let email: String
    let phone: String
    let isEmailVerified: Bool
    let isPhoneVerified: Bool
    let isActive: Bool
    let onboardingCompleted: Bool
    let kycCompleted: Bool
    let borrowerProfileID: String
    let signupStage: String

    var id: String { userID }

    fileprivate init(proto: Auth_BorrowerSignupStatusItem) {
        self.userID = proto.userID
        self.email = proto.email
        self.phone = proto.phone
        self.isEmailVerified = proto.isEmailVerified
        self.isPhoneVerified = proto.isPhoneVerified
        self.isActive = proto.isActive
        self.onboardingCompleted = proto.onboardingCompleted
        self.kycCompleted = proto.kycCompleted
        self.borrowerProfileID = proto.borrowerProfileID
        self.signupStage = proto.signupStage
    }
}

private struct Auth_SearchBorrowerSignupStatusRequest: Sendable {
    var query: String = ""
    var limit: Int32 = 0
    var offset: Int32 = 0
    var unknownFields = SwiftProtobuf.UnknownStorage()

    static let protoMessageName: String = "auth.v1.SearchBorrowerSignupStatusRequest"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")

    init() {}

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.query)
            case 2: try decoder.decodeSingularInt32Field(value: &self.limit)
            case 3: try decoder.decodeSingularInt32Field(value: &self.offset)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.query.isEmpty {
            try visitor.visitSingularStringField(value: self.query, fieldNumber: 1)
        }
        if self.limit != 0 {
            try visitor.visitSingularInt32Field(value: self.limit, fieldNumber: 2)
        }
        if self.offset != 0 {
            try visitor.visitSingularInt32Field(value: self.offset, fieldNumber: 3)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.query == rhs.query &&
        lhs.limit == rhs.limit &&
        lhs.offset == rhs.offset &&
        lhs.unknownFields == rhs.unknownFields
    }
}

private struct Auth_BorrowerSignupStatusItem: Sendable {
    var userID: String = ""
    var email: String = ""
    var phone: String = ""
    var isEmailVerified: Bool = false
    var isPhoneVerified: Bool = false
    var isActive: Bool = false
    var onboardingCompleted: Bool = false
    var kycCompleted: Bool = false
    var borrowerProfileID: String = ""
    var signupStage: String = ""
    var unknownFields = SwiftProtobuf.UnknownStorage()

    static let protoMessageName: String = "auth.v1.BorrowerSignupStatusItem"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")

    init() {}

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeSingularStringField(value: &self.userID)
            case 2: try decoder.decodeSingularStringField(value: &self.email)
            case 3: try decoder.decodeSingularStringField(value: &self.phone)
            case 4: try decoder.decodeSingularBoolField(value: &self.isEmailVerified)
            case 5: try decoder.decodeSingularBoolField(value: &self.isPhoneVerified)
            case 6: try decoder.decodeSingularBoolField(value: &self.isActive)
            case 7: try decoder.decodeSingularBoolField(value: &self.onboardingCompleted)
            case 8: try decoder.decodeSingularBoolField(value: &self.kycCompleted)
            case 9: try decoder.decodeSingularStringField(value: &self.borrowerProfileID)
            case 10: try decoder.decodeSingularStringField(value: &self.signupStage)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.userID.isEmpty { try visitor.visitSingularStringField(value: self.userID, fieldNumber: 1) }
        if !self.email.isEmpty { try visitor.visitSingularStringField(value: self.email, fieldNumber: 2) }
        if !self.phone.isEmpty { try visitor.visitSingularStringField(value: self.phone, fieldNumber: 3) }
        if self.isEmailVerified { try visitor.visitSingularBoolField(value: self.isEmailVerified, fieldNumber: 4) }
        if self.isPhoneVerified { try visitor.visitSingularBoolField(value: self.isPhoneVerified, fieldNumber: 5) }
        if self.isActive { try visitor.visitSingularBoolField(value: self.isActive, fieldNumber: 6) }
        if self.onboardingCompleted { try visitor.visitSingularBoolField(value: self.onboardingCompleted, fieldNumber: 7) }
        if self.kycCompleted { try visitor.visitSingularBoolField(value: self.kycCompleted, fieldNumber: 8) }
        if !self.borrowerProfileID.isEmpty { try visitor.visitSingularStringField(value: self.borrowerProfileID, fieldNumber: 9) }
        if !self.signupStage.isEmpty { try visitor.visitSingularStringField(value: self.signupStage, fieldNumber: 10) }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.userID == rhs.userID &&
        lhs.email == rhs.email &&
        lhs.phone == rhs.phone &&
        lhs.isEmailVerified == rhs.isEmailVerified &&
        lhs.isPhoneVerified == rhs.isPhoneVerified &&
        lhs.isActive == rhs.isActive &&
        lhs.onboardingCompleted == rhs.onboardingCompleted &&
        lhs.kycCompleted == rhs.kycCompleted &&
        lhs.borrowerProfileID == rhs.borrowerProfileID &&
        lhs.signupStage == rhs.signupStage &&
        lhs.unknownFields == rhs.unknownFields
    }
}

private struct Auth_SearchBorrowerSignupStatusResponse: Sendable {
    var items: [Auth_BorrowerSignupStatusItem] = []
    var unknownFields = SwiftProtobuf.UnknownStorage()

    static let protoMessageName: String = "auth.v1.SearchBorrowerSignupStatusResponse"
    static let _protobuf_nameMap = SwiftProtobuf._NameMap(bytecode: "")

    init() {}

    mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try decoder.decodeRepeatedMessageField(value: &self.items)
            default: break
            }
        }
    }

    func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.items.isEmpty {
            try visitor.visitRepeatedMessageField(value: self.items, fieldNumber: 1)
        }
        try unknownFields.traverse(visitor: &visitor)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items &&
        lhs.unknownFields == rhs.unknownFields
    }
}

extension Auth_SearchBorrowerSignupStatusRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {}
extension Auth_BorrowerSignupStatusItem: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {}
extension Auth_SearchBorrowerSignupStatusResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {}
