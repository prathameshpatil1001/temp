// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written gRPC-Swift 2 (GRPCCore) client stubs matching kyc/v1/kyc.proto.
// Follows the same pattern as the generated auth.grpc.swift client section.
// When protoc-gen-grpc-swift is wired up, replace this file with the generated output.
//
// service: kyc.v1.KycService

import GRPCCore
import GRPCProtobuf

// MARK: - kyc.v1.KycService (namespace)

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public enum Kyc_V1_KycService: Sendable {
    public static let descriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService")

    public enum Method: Sendable {
        public enum RecordUserConsent: Sendable {
            public typealias Input  = Kyc_V1_RecordUserConsentRequest
            public typealias Output = Kyc_V1_RecordUserConsentResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "RecordUserConsent",
                type: .unary
            )
        }
        public enum InitiateAadhaarKyc: Sendable {
            public typealias Input  = Kyc_V1_InitiateAadhaarKycRequest
            public typealias Output = Kyc_V1_InitiateAadhaarKycResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "InitiateAadhaarKyc",
                type: .unary
            )
        }
        public enum VerifyAadhaarKycOtp: Sendable {
            public typealias Input  = Kyc_V1_VerifyAadhaarKycOtpRequest
            public typealias Output = Kyc_V1_VerifyAadhaarKycOtpResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "VerifyAadhaarKycOtp",
                type: .unary
            )
        }
        public enum VerifyPanKyc: Sendable {
            public typealias Input  = Kyc_V1_VerifyPanKycRequest
            public typealias Output = Kyc_V1_VerifyPanKycResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "VerifyPanKyc",
                type: .unary
            )
        }
        public enum GetBorrowerKycStatus: Sendable {
            public typealias Input  = Kyc_V1_GetBorrowerKycStatusRequest
            public typealias Output = Kyc_V1_GetBorrowerKycStatusResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "GetBorrowerKycStatus",
                type: .unary
            )
        }
        public enum ListBorrowerKycHistory: Sendable {
            public typealias Input  = Kyc_V1_ListBorrowerKycHistoryRequest
            public typealias Output = Kyc_V1_ListBorrowerKycHistoryResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService"),
                method: "ListBorrowerKycHistory",
                type: .unary
            )
        }

        public static let descriptors: [GRPCCore.MethodDescriptor] = [
            RecordUserConsent.descriptor,
            InitiateAadhaarKyc.descriptor,
            VerifyAadhaarKycOtp.descriptor,
            VerifyPanKyc.descriptor,
            GetBorrowerKycStatus.descriptor,
            ListBorrowerKycHistory.descriptor,
        ]
    }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension GRPCCore.ServiceDescriptor {
    public static let kyc_v1_KycService = GRPCCore.ServiceDescriptor(fullyQualifiedService: "kyc.v1.KycService")
}

// MARK: - kyc.v1.KycService (client)

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Kyc_V1_KycService {

    /// Client for the ``Kyc_V1_KycService`` service.
    public struct Client<Transport: GRPCCore.ClientTransport>: Sendable {
        private let client: GRPCCore.GRPCClient<Transport>

        public init(wrapping client: GRPCCore.GRPCClient<Transport>) {
            self.client = client
        }

        // MARK: RecordUserConsent

        public func recordUserConsent<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_RecordUserConsentRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_RecordUserConsentRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_RecordUserConsentResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_RecordUserConsentResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.RecordUserConsent.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }

        // MARK: InitiateAadhaarKyc

        public func initiateAadhaarKyc<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_InitiateAadhaarKycRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_InitiateAadhaarKycRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_InitiateAadhaarKycResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_InitiateAadhaarKycResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.InitiateAadhaarKyc.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }

        // MARK: VerifyAadhaarKycOtp

        public func verifyAadhaarKycOtp<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_VerifyAadhaarKycOtpRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_VerifyAadhaarKycOtpRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_VerifyAadhaarKycOtpResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_VerifyAadhaarKycOtpResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.VerifyAadhaarKycOtp.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }

        // MARK: VerifyPanKyc

        public func verifyPanKyc<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_VerifyPanKycRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_VerifyPanKycRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_VerifyPanKycResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_VerifyPanKycResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.VerifyPanKyc.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }

        // MARK: GetBorrowerKycStatus

        public func getBorrowerKycStatus<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_GetBorrowerKycStatusRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_GetBorrowerKycStatusRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_GetBorrowerKycStatusResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_GetBorrowerKycStatusResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.GetBorrowerKycStatus.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }

        // MARK: ListBorrowerKycHistory

        public func listBorrowerKycHistory<Result>(
            request: GRPCCore.ClientRequest<Kyc_V1_ListBorrowerKycHistoryRequest>,
            serializer: some GRPCCore.MessageSerializer<Kyc_V1_ListBorrowerKycHistoryRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Kyc_V1_ListBorrowerKycHistoryResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Kyc_V1_ListBorrowerKycHistoryResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Kyc_V1_KycService.Method.ListBorrowerKycHistory.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }
    }
}

// MARK: - Convenience overloads using GRPCProtobuf serializers

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Kyc_V1_KycService.Client {

    public func recordUserConsent(
        request: GRPCCore.ClientRequest<Kyc_V1_RecordUserConsentRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_RecordUserConsentResponse {
        try await self.recordUserConsent(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_RecordUserConsentRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_RecordUserConsentResponse>(),
            options: options
        )
    }

    public func initiateAadhaarKyc(
        request: GRPCCore.ClientRequest<Kyc_V1_InitiateAadhaarKycRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_InitiateAadhaarKycResponse {
        try await self.initiateAadhaarKyc(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_InitiateAadhaarKycRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_InitiateAadhaarKycResponse>(),
            options: options
        )
    }

    public func verifyAadhaarKycOtp(
        request: GRPCCore.ClientRequest<Kyc_V1_VerifyAadhaarKycOtpRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_VerifyAadhaarKycOtpResponse {
        try await self.verifyAadhaarKycOtp(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_VerifyAadhaarKycOtpRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_VerifyAadhaarKycOtpResponse>(),
            options: options
        )
    }

    public func verifyPanKyc(
        request: GRPCCore.ClientRequest<Kyc_V1_VerifyPanKycRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_VerifyPanKycResponse {
        try await self.verifyPanKyc(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_VerifyPanKycRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_VerifyPanKycResponse>(),
            options: options
        )
    }

    public func getBorrowerKycStatus(
        request: GRPCCore.ClientRequest<Kyc_V1_GetBorrowerKycStatusRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_GetBorrowerKycStatusResponse {
        try await self.getBorrowerKycStatus(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_GetBorrowerKycStatusRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_GetBorrowerKycStatusResponse>(),
            options: options
        )
    }

    public func listBorrowerKycHistory(
        request: GRPCCore.ClientRequest<Kyc_V1_ListBorrowerKycHistoryRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Kyc_V1_ListBorrowerKycHistoryResponse {
        try await self.listBorrowerKycHistory(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Kyc_V1_ListBorrowerKycHistoryRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Kyc_V1_ListBorrowerKycHistoryResponse>(),
            options: options
        )
    }
}
