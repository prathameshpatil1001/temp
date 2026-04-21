// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written Swift-Protobuf types matching kyc/v1/kyc.proto.
// Follows the same naming convention as the generated auth.pb.swift.
// When protoc-gen-swift is wired up, replace this file with the generated output.
//
// package: kyc.v1
// service: KycService

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftProtobuf

// MARK: - Enums

public enum Kyc_V1_KycDocType: SwiftProtobuf.Enum, Swift.CaseIterable {
    public typealias RawValue = Int
    case unspecified    // = 0
    case aadhaar        // = 1
    case pan            // = 2
    case UNRECOGNIZED(Int)

    public init() { self = .unspecified }

    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .aadhaar
        case 2: self = .pan
        default: self = .UNRECOGNIZED(rawValue)
        }
    }

    public var rawValue: Int {
        switch self {
        case .unspecified:       return 0
        case .aadhaar:           return 1
        case .pan:               return 2
        case .UNRECOGNIZED(let i): return i
        }
    }

    public static let allCases: [Kyc_V1_KycDocType] = [.unspecified, .aadhaar, .pan]
}

public enum Kyc_V1_ConsentType: SwiftProtobuf.Enum, Swift.CaseIterable {
    public typealias RawValue = Int
    case unspecified    // = 0
    case aadhaarKyc     // = 1
    case panKyc         // = 2
    case UNRECOGNIZED(Int)

    public init() { self = .unspecified }

    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .aadhaarKyc
        case 2: self = .panKyc
        default: self = .UNRECOGNIZED(rawValue)
        }
    }

    public var rawValue: Int {
        switch self {
        case .unspecified:       return 0
        case .aadhaarKyc:        return 1
        case .panKyc:            return 2
        case .UNRECOGNIZED(let i): return i
        }
    }

    public static let allCases: [Kyc_V1_ConsentType] = [.unspecified, .aadhaarKyc, .panKyc]
}

// MARK: - RecordUserConsent

public struct Kyc_V1_RecordUserConsentRequest: Sendable {
    public var consentType: Kyc_V1_ConsentType = .unspecified
    public var consentVersion: String = String()
    public var consentText: String = String()
    public var isGranted: Bool = false
    public var source: String = String()
    public var ipAddress: String = String()
    public var userAgent: String = String()
    public var metadataJson: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_RecordUserConsentResponse: Sendable {
    public var success: Bool = false
    public var consentID: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - InitiateAadhaarKyc

public struct Kyc_V1_InitiateAadhaarKycRequest: Sendable {
    public var aadhaarNumber: String = String()
    public var reason: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_InitiateAadhaarKycResponse: Sendable {
    public var success: Bool = false
    public var referenceID: String = String()
    public var providerTransactionID: String = String()
    public var message: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - VerifyAadhaarKycOtp

public struct Kyc_V1_VerifyAadhaarKycOtpRequest: Sendable {
    public var referenceID: String = String()
    public var otp: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_VerifyAadhaarKycOtpResponse: Sendable {
    public var success: Bool = false
    public var status: String = String()
    public var message: String = String()
    public var providerTransactionID: String = String()
    public var name: String = String()
    public var dateOfBirth: String = String()
    public var gender: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - VerifyPanKyc

public struct Kyc_V1_VerifyPanKycRequest: Sendable {
    public var pan: String = String()
    public var nameAsPerPan: String = String()
    public var dateOfBirth: String = String()
    public var reason: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_VerifyPanKycResponse: Sendable {
    public var success: Bool = false
    public var status: String = String()
    public var message: String = String()
    public var providerTransactionID: String = String()
    public var nameAsPerPanMatch: Bool = false
    public var dateOfBirthMatch: Bool = false
    public var aadhaarSeedingStatus: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - GetBorrowerKycStatus

public struct Kyc_V1_GetBorrowerKycStatusRequest: Sendable {
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_GetBorrowerKycStatusResponse: Sendable {
    public var isAadhaarVerified: Bool = false
    public var isPanVerified: Bool = false
    public var aadhaarVerifiedAt: String = String()
    public var panVerifiedAt: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - ListBorrowerKycHistory

public struct Kyc_V1_ListBorrowerKycHistoryRequest: Sendable {
    public var docType: Kyc_V1_KycDocType = .unspecified
    public var limit: Int32 = 0
    public var offset: Int32 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_KycHistoryItem: Sendable {
    public var id: String = String()
    public var docType: Kyc_V1_KycDocType = .unspecified
    public var status: String = String()
    public var failureCode: String = String()
    public var failureReason: String = String()
    public var providerTransactionID: String = String()
    public var attemptedAt: String = String()
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Kyc_V1_ListBorrowerKycHistoryResponse: Sendable {
    public var items: [Kyc_V1_KycHistoryItem] = []
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - SwiftProtobuf conformances

fileprivate let _kyc_protobuf_package = "kyc.v1"

extension Kyc_V1_KycDocType: SwiftProtobuf._ProtoNameProviding {
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "KYC_DOC_TYPE_UNSPECIFIED"),
        1: .same(proto: "KYC_DOC_TYPE_AADHAAR"),
        2: .same(proto: "KYC_DOC_TYPE_PAN"),
    ]
}

extension Kyc_V1_ConsentType: SwiftProtobuf._ProtoNameProviding {
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "CONSENT_TYPE_UNSPECIFIED"),
        1: .same(proto: "CONSENT_TYPE_AADHAAR_KYC"),
        2: .same(proto: "CONSENT_TYPE_PAN_KYC"),
    ]
}

extension Kyc_V1_RecordUserConsentRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".RecordUserConsentRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "consent_type"),
        2: .standard(proto: "consent_version"),
        3: .standard(proto: "consent_text"),
        4: .standard(proto: "is_granted"),
        5: .same(proto: "source"),
        6: .standard(proto: "ip_address"),
        7: .standard(proto: "user_agent"),
        8: .standard(proto: "metadata_json"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularEnumField(value: &self.consentType) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.consentVersion) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.consentText) }()
            case 4: try { try decoder.decodeSingularBoolField(value: &self.isGranted) }()
            case 5: try { try decoder.decodeSingularStringField(value: &self.source) }()
            case 6: try { try decoder.decodeSingularStringField(value: &self.ipAddress) }()
            case 7: try { try decoder.decodeSingularStringField(value: &self.userAgent) }()
            case 8: try { try decoder.decodeSingularStringField(value: &self.metadataJson) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.consentType != .unspecified { try visitor.visitSingularEnumField(value: self.consentType, fieldNumber: 1) }
        if !self.consentVersion.isEmpty { try visitor.visitSingularStringField(value: self.consentVersion, fieldNumber: 2) }
        if !self.consentText.isEmpty { try visitor.visitSingularStringField(value: self.consentText, fieldNumber: 3) }
        if self.isGranted { try visitor.visitSingularBoolField(value: self.isGranted, fieldNumber: 4) }
        if !self.source.isEmpty { try visitor.visitSingularStringField(value: self.source, fieldNumber: 5) }
        if !self.ipAddress.isEmpty { try visitor.visitSingularStringField(value: self.ipAddress, fieldNumber: 6) }
        if !self.userAgent.isEmpty { try visitor.visitSingularStringField(value: self.userAgent, fieldNumber: 7) }
        if !self.metadataJson.isEmpty { try visitor.visitSingularStringField(value: self.metadataJson, fieldNumber: 8) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_RecordUserConsentRequest, rhs: Kyc_V1_RecordUserConsentRequest) -> Bool {
        return lhs.consentType == rhs.consentType && lhs.consentVersion == rhs.consentVersion &&
               lhs.consentText == rhs.consentText && lhs.isGranted == rhs.isGranted &&
               lhs.source == rhs.source && lhs.ipAddress == rhs.ipAddress &&
               lhs.userAgent == rhs.userAgent && lhs.metadataJson == rhs.metadataJson &&
               lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_RecordUserConsentResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".RecordUserConsentResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .standard(proto: "consent_id"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.success) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.consentID) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.consentID.isEmpty { try visitor.visitSingularStringField(value: self.consentID, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_RecordUserConsentResponse, rhs: Kyc_V1_RecordUserConsentResponse) -> Bool {
        return lhs.success == rhs.success && lhs.consentID == rhs.consentID && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_InitiateAadhaarKycRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".InitiateAadhaarKycRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "aadhaar_number"),
        2: .same(proto: "reason"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularStringField(value: &self.aadhaarNumber) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.reason) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.aadhaarNumber.isEmpty { try visitor.visitSingularStringField(value: self.aadhaarNumber, fieldNumber: 1) }
        if !self.reason.isEmpty { try visitor.visitSingularStringField(value: self.reason, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_InitiateAadhaarKycRequest, rhs: Kyc_V1_InitiateAadhaarKycRequest) -> Bool {
        return lhs.aadhaarNumber == rhs.aadhaarNumber && lhs.reason == rhs.reason && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_InitiateAadhaarKycResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".InitiateAadhaarKycResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .standard(proto: "reference_id"),
        3: .standard(proto: "provider_transaction_id"),
        4: .same(proto: "message"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.success) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.referenceID) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.providerTransactionID) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.message) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.referenceID.isEmpty { try visitor.visitSingularStringField(value: self.referenceID, fieldNumber: 2) }
        if !self.providerTransactionID.isEmpty { try visitor.visitSingularStringField(value: self.providerTransactionID, fieldNumber: 3) }
        if !self.message.isEmpty { try visitor.visitSingularStringField(value: self.message, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_InitiateAadhaarKycResponse, rhs: Kyc_V1_InitiateAadhaarKycResponse) -> Bool {
        return lhs.success == rhs.success && lhs.referenceID == rhs.referenceID &&
               lhs.providerTransactionID == rhs.providerTransactionID && lhs.message == rhs.message &&
               lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_VerifyAadhaarKycOtpRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".VerifyAadhaarKycOtpRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "reference_id"),
        2: .same(proto: "otp"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularStringField(value: &self.referenceID) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.otp) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.referenceID.isEmpty { try visitor.visitSingularStringField(value: self.referenceID, fieldNumber: 1) }
        if !self.otp.isEmpty { try visitor.visitSingularStringField(value: self.otp, fieldNumber: 2) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_VerifyAadhaarKycOtpRequest, rhs: Kyc_V1_VerifyAadhaarKycOtpRequest) -> Bool {
        return lhs.referenceID == rhs.referenceID && lhs.otp == rhs.otp && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_VerifyAadhaarKycOtpResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".VerifyAadhaarKycOtpResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .same(proto: "status"),
        3: .same(proto: "message"),
        4: .standard(proto: "provider_transaction_id"),
        5: .same(proto: "name"),
        6: .standard(proto: "date_of_birth"),
        7: .same(proto: "gender"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.success) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.status) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.message) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.providerTransactionID) }()
            case 5: try { try decoder.decodeSingularStringField(value: &self.name) }()
            case 6: try { try decoder.decodeSingularStringField(value: &self.dateOfBirth) }()
            case 7: try { try decoder.decodeSingularStringField(value: &self.gender) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.status.isEmpty { try visitor.visitSingularStringField(value: self.status, fieldNumber: 2) }
        if !self.message.isEmpty { try visitor.visitSingularStringField(value: self.message, fieldNumber: 3) }
        if !self.providerTransactionID.isEmpty { try visitor.visitSingularStringField(value: self.providerTransactionID, fieldNumber: 4) }
        if !self.name.isEmpty { try visitor.visitSingularStringField(value: self.name, fieldNumber: 5) }
        if !self.dateOfBirth.isEmpty { try visitor.visitSingularStringField(value: self.dateOfBirth, fieldNumber: 6) }
        if !self.gender.isEmpty { try visitor.visitSingularStringField(value: self.gender, fieldNumber: 7) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_VerifyAadhaarKycOtpResponse, rhs: Kyc_V1_VerifyAadhaarKycOtpResponse) -> Bool {
        return lhs.success == rhs.success && lhs.status == rhs.status && lhs.message == rhs.message &&
               lhs.providerTransactionID == rhs.providerTransactionID && lhs.name == rhs.name &&
               lhs.dateOfBirth == rhs.dateOfBirth && lhs.gender == rhs.gender && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_VerifyPanKycRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".VerifyPanKycRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "pan"),
        2: .standard(proto: "name_as_per_pan"),
        3: .standard(proto: "date_of_birth"),
        4: .same(proto: "reason"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularStringField(value: &self.pan) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.nameAsPerPan) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.dateOfBirth) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.reason) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.pan.isEmpty { try visitor.visitSingularStringField(value: self.pan, fieldNumber: 1) }
        if !self.nameAsPerPan.isEmpty { try visitor.visitSingularStringField(value: self.nameAsPerPan, fieldNumber: 2) }
        if !self.dateOfBirth.isEmpty { try visitor.visitSingularStringField(value: self.dateOfBirth, fieldNumber: 3) }
        if !self.reason.isEmpty { try visitor.visitSingularStringField(value: self.reason, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_VerifyPanKycRequest, rhs: Kyc_V1_VerifyPanKycRequest) -> Bool {
        return lhs.pan == rhs.pan && lhs.nameAsPerPan == rhs.nameAsPerPan &&
               lhs.dateOfBirth == rhs.dateOfBirth && lhs.reason == rhs.reason && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_VerifyPanKycResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".VerifyPanKycResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
        2: .same(proto: "status"),
        3: .same(proto: "message"),
        4: .standard(proto: "provider_transaction_id"),
        5: .standard(proto: "name_as_per_pan_match"),
        6: .standard(proto: "date_of_birth_match"),
        7: .standard(proto: "aadhaar_seeding_status"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.success) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.status) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.message) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.providerTransactionID) }()
            case 5: try { try decoder.decodeSingularBoolField(value: &self.nameAsPerPanMatch) }()
            case 6: try { try decoder.decodeSingularBoolField(value: &self.dateOfBirthMatch) }()
            case 7: try { try decoder.decodeSingularStringField(value: &self.aadhaarSeedingStatus) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        if !self.status.isEmpty { try visitor.visitSingularStringField(value: self.status, fieldNumber: 2) }
        if !self.message.isEmpty { try visitor.visitSingularStringField(value: self.message, fieldNumber: 3) }
        if !self.providerTransactionID.isEmpty { try visitor.visitSingularStringField(value: self.providerTransactionID, fieldNumber: 4) }
        if self.nameAsPerPanMatch { try visitor.visitSingularBoolField(value: self.nameAsPerPanMatch, fieldNumber: 5) }
        if self.dateOfBirthMatch { try visitor.visitSingularBoolField(value: self.dateOfBirthMatch, fieldNumber: 6) }
        if !self.aadhaarSeedingStatus.isEmpty { try visitor.visitSingularStringField(value: self.aadhaarSeedingStatus, fieldNumber: 7) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_VerifyPanKycResponse, rhs: Kyc_V1_VerifyPanKycResponse) -> Bool {
        return lhs.success == rhs.success && lhs.status == rhs.status && lhs.message == rhs.message &&
               lhs.providerTransactionID == rhs.providerTransactionID &&
               lhs.nameAsPerPanMatch == rhs.nameAsPerPanMatch && lhs.dateOfBirthMatch == rhs.dateOfBirthMatch &&
               lhs.aadhaarSeedingStatus == rhs.aadhaarSeedingStatus && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_GetBorrowerKycStatusRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".GetBorrowerKycStatusRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [:]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while try decoder.nextFieldNumber() != nil {}
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_GetBorrowerKycStatusRequest, rhs: Kyc_V1_GetBorrowerKycStatusRequest) -> Bool {
        return lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_GetBorrowerKycStatusResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".GetBorrowerKycStatusResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "is_aadhaar_verified"),
        2: .standard(proto: "is_pan_verified"),
        3: .standard(proto: "aadhaar_verified_at"),
        4: .standard(proto: "pan_verified_at"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.isAadhaarVerified) }()
            case 2: try { try decoder.decodeSingularBoolField(value: &self.isPanVerified) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.aadhaarVerifiedAt) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.panVerifiedAt) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.isAadhaarVerified { try visitor.visitSingularBoolField(value: self.isAadhaarVerified, fieldNumber: 1) }
        if self.isPanVerified { try visitor.visitSingularBoolField(value: self.isPanVerified, fieldNumber: 2) }
        if !self.aadhaarVerifiedAt.isEmpty { try visitor.visitSingularStringField(value: self.aadhaarVerifiedAt, fieldNumber: 3) }
        if !self.panVerifiedAt.isEmpty { try visitor.visitSingularStringField(value: self.panVerifiedAt, fieldNumber: 4) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_GetBorrowerKycStatusResponse, rhs: Kyc_V1_GetBorrowerKycStatusResponse) -> Bool {
        return lhs.isAadhaarVerified == rhs.isAadhaarVerified && lhs.isPanVerified == rhs.isPanVerified &&
               lhs.aadhaarVerifiedAt == rhs.aadhaarVerifiedAt && lhs.panVerifiedAt == rhs.panVerifiedAt &&
               lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_ListBorrowerKycHistoryRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".ListBorrowerKycHistoryRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "doc_type"),
        2: .same(proto: "limit"),
        3: .same(proto: "offset"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularEnumField(value: &self.docType) }()
            case 2: try { try decoder.decodeSingularInt32Field(value: &self.limit) }()
            case 3: try { try decoder.decodeSingularInt32Field(value: &self.offset) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.docType != .unspecified { try visitor.visitSingularEnumField(value: self.docType, fieldNumber: 1) }
        if self.limit != 0 { try visitor.visitSingularInt32Field(value: self.limit, fieldNumber: 2) }
        if self.offset != 0 { try visitor.visitSingularInt32Field(value: self.offset, fieldNumber: 3) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_ListBorrowerKycHistoryRequest, rhs: Kyc_V1_ListBorrowerKycHistoryRequest) -> Bool {
        return lhs.docType == rhs.docType && lhs.limit == rhs.limit && lhs.offset == rhs.offset && lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_KycHistoryItem: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".KycHistoryItem"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "id"),
        2: .standard(proto: "doc_type"),
        3: .same(proto: "status"),
        4: .standard(proto: "failure_code"),
        5: .standard(proto: "failure_reason"),
        6: .standard(proto: "provider_transaction_id"),
        7: .standard(proto: "attempted_at"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularStringField(value: &self.id) }()
            case 2: try { try decoder.decodeSingularEnumField(value: &self.docType) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.status) }()
            case 4: try { try decoder.decodeSingularStringField(value: &self.failureCode) }()
            case 5: try { try decoder.decodeSingularStringField(value: &self.failureReason) }()
            case 6: try { try decoder.decodeSingularStringField(value: &self.providerTransactionID) }()
            case 7: try { try decoder.decodeSingularStringField(value: &self.attemptedAt) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.id.isEmpty { try visitor.visitSingularStringField(value: self.id, fieldNumber: 1) }
        if self.docType != .unspecified { try visitor.visitSingularEnumField(value: self.docType, fieldNumber: 2) }
        if !self.status.isEmpty { try visitor.visitSingularStringField(value: self.status, fieldNumber: 3) }
        if !self.failureCode.isEmpty { try visitor.visitSingularStringField(value: self.failureCode, fieldNumber: 4) }
        if !self.failureReason.isEmpty { try visitor.visitSingularStringField(value: self.failureReason, fieldNumber: 5) }
        if !self.providerTransactionID.isEmpty { try visitor.visitSingularStringField(value: self.providerTransactionID, fieldNumber: 6) }
        if !self.attemptedAt.isEmpty { try visitor.visitSingularStringField(value: self.attemptedAt, fieldNumber: 7) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_KycHistoryItem, rhs: Kyc_V1_KycHistoryItem) -> Bool {
        return lhs.id == rhs.id && lhs.docType == rhs.docType && lhs.status == rhs.status &&
               lhs.failureCode == rhs.failureCode && lhs.failureReason == rhs.failureReason &&
               lhs.providerTransactionID == rhs.providerTransactionID && lhs.attemptedAt == rhs.attemptedAt &&
               lhs.unknownFields == rhs.unknownFields
    }
}

extension Kyc_V1_ListBorrowerKycHistoryResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _kyc_protobuf_package + ".ListBorrowerKycHistoryResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "items"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeRepeatedMessageField(value: &self.items) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.items.isEmpty { try visitor.visitRepeatedMessageField(value: self.items, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Kyc_V1_ListBorrowerKycHistoryResponse, rhs: Kyc_V1_ListBorrowerKycHistoryResponse) -> Bool {
        return lhs.items == rhs.items && lhs.unknownFields == rhs.unknownFields
    }
}
