// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written gRPC-Swift 2 (GRPCCore) client stubs for onboarding.v1.OnboardingService.
// Replace with protoc-gen-grpc-swift output when the generator is wired up.

import GRPCCore
import GRPCProtobuf

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
public enum Onboarding_V1_OnboardingService: Sendable {
    public static let descriptor = GRPCCore.ServiceDescriptor(fullyQualifiedService: "onboarding.v1.OnboardingService")

    public enum Method: Sendable {
        public enum CompleteBorrowerOnboarding: Sendable {
            public typealias Input  = Onboarding_V1_CompleteBorrowerOnboardingRequest
            public typealias Output = Onboarding_V1_CompleteBorrowerOnboardingResponse
            public static let descriptor = GRPCCore.MethodDescriptor(
                service: GRPCCore.ServiceDescriptor(fullyQualifiedService: "onboarding.v1.OnboardingService"),
                method: "CompleteBorrowerOnboarding",
                type: .unary
            )
        }

        public static let descriptors: [GRPCCore.MethodDescriptor] = [
            CompleteBorrowerOnboarding.descriptor,
        ]
    }
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension GRPCCore.ServiceDescriptor {
    public static let onboarding_v1_OnboardingService = GRPCCore.ServiceDescriptor(fullyQualifiedService: "onboarding.v1.OnboardingService")
}

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Onboarding_V1_OnboardingService {

    public struct Client<Transport: GRPCCore.ClientTransport>: Sendable {
        private let client: GRPCCore.GRPCClient<Transport>

        public init(wrapping client: GRPCCore.GRPCClient<Transport>) {
            self.client = client
        }

        public func completeBorrowerOnboarding<Result>(
            request: GRPCCore.ClientRequest<Onboarding_V1_CompleteBorrowerOnboardingRequest>,
            serializer: some GRPCCore.MessageSerializer<Onboarding_V1_CompleteBorrowerOnboardingRequest>,
            deserializer: some GRPCCore.MessageDeserializer<Onboarding_V1_CompleteBorrowerOnboardingResponse>,
            options: GRPCCore.CallOptions = .defaults,
            onResponse handleResponse: @Sendable @escaping (GRPCCore.ClientResponse<Onboarding_V1_CompleteBorrowerOnboardingResponse>) async throws -> Result = { response in
                try response.message
            }
        ) async throws -> Result where Result: Sendable {
            try await self.client.unary(
                request: request,
                descriptor: Onboarding_V1_OnboardingService.Method.CompleteBorrowerOnboarding.descriptor,
                serializer: serializer,
                deserializer: deserializer,
                options: options,
                onResponse: handleResponse
            )
        }
    }
}

// MARK: - Convenience overloads

@available(macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0, *)
extension Onboarding_V1_OnboardingService.Client {

    public func completeBorrowerOnboarding(
        request: GRPCCore.ClientRequest<Onboarding_V1_CompleteBorrowerOnboardingRequest>,
        options: GRPCCore.CallOptions = .defaults
    ) async throws -> Onboarding_V1_CompleteBorrowerOnboardingResponse {
        try await self.completeBorrowerOnboarding(
            request: request,
            serializer: GRPCProtobuf.ProtobufSerializer<Onboarding_V1_CompleteBorrowerOnboardingRequest>(),
            deserializer: GRPCProtobuf.ProtobufDeserializer<Onboarding_V1_CompleteBorrowerOnboardingResponse>(),
            options: options
        )
    }
}
