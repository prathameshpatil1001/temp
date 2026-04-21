// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Hand-written Swift-Protobuf types matching onboarding/v1/onboarding.proto.
// Replace with protoc-gen-swift output when the generator is wired up.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftProtobuf

// MARK: - Enums

public enum Onboarding_V1_BorrowerGender: SwiftProtobuf.Enum, Swift.CaseIterable {
    public typealias RawValue = Int
    case unspecified // = 0
    case male        // = 1
    case female      // = 2
    case other       // = 3
    case UNRECOGNIZED(Int)

    public init() { self = .unspecified }
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .male
        case 2: self = .female
        case 3: self = .other
        default: self = .UNRECOGNIZED(rawValue)
        }
    }
    public var rawValue: Int {
        switch self {
        case .unspecified:       return 0
        case .male:              return 1
        case .female:            return 2
        case .other:             return 3
        case .UNRECOGNIZED(let i): return i
        }
    }
    public static let allCases: [Onboarding_V1_BorrowerGender] = [.unspecified, .male, .female, .other]
}

public enum Onboarding_V1_BorrowerEmploymentType: SwiftProtobuf.Enum, Swift.CaseIterable {
    public typealias RawValue = Int
    case unspecified   // = 0
    case salaried      // = 1
    case selfEmployed  // = 2
    case business      // = 3
    case UNRECOGNIZED(Int)

    public init() { self = .unspecified }
    public init?(rawValue: Int) {
        switch rawValue {
        case 0: self = .unspecified
        case 1: self = .salaried
        case 2: self = .selfEmployed
        case 3: self = .business
        default: self = .UNRECOGNIZED(rawValue)
        }
    }
    public var rawValue: Int {
        switch self {
        case .unspecified:        return 0
        case .salaried:           return 1
        case .selfEmployed:       return 2
        case .business:           return 3
        case .UNRECOGNIZED(let i): return i
        }
    }
    public static let allCases: [Onboarding_V1_BorrowerEmploymentType] = [.unspecified, .salaried, .selfEmployed, .business]
}

// MARK: - Messages

public struct Onboarding_V1_CompleteBorrowerOnboardingRequest: Sendable {
    public var firstName: String = String()
    public var lastName: String = String()
    public var dateOfBirth: String = String()
    public var gender: Onboarding_V1_BorrowerGender = .unspecified
    public var addressLine1: String = String()
    public var city: String = String()
    public var state: String = String()
    public var pincode: String = String()
    public var employmentType: Onboarding_V1_BorrowerEmploymentType = .unspecified
    public var monthlyIncome: String = String()
    public var profileCompletenessPercent: Int32 = 0
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

public struct Onboarding_V1_CompleteBorrowerOnboardingResponse: Sendable {
    public var success: Bool = false
    public var unknownFields = SwiftProtobuf.UnknownStorage()
    public init() {}
}

// MARK: - SwiftProtobuf conformances

fileprivate let _onboarding_protobuf_package = "onboarding.v1"

extension Onboarding_V1_BorrowerGender: SwiftProtobuf._ProtoNameProviding {
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "BORROWER_GENDER_UNSPECIFIED"),
        1: .same(proto: "BORROWER_GENDER_MALE"),
        2: .same(proto: "BORROWER_GENDER_FEMALE"),
        3: .same(proto: "BORROWER_GENDER_OTHER"),
    ]
}

extension Onboarding_V1_BorrowerEmploymentType: SwiftProtobuf._ProtoNameProviding {
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        0: .same(proto: "BORROWER_EMPLOYMENT_TYPE_UNSPECIFIED"),
        1: .same(proto: "BORROWER_EMPLOYMENT_TYPE_SALARIED"),
        2: .same(proto: "BORROWER_EMPLOYMENT_TYPE_SELF_EMPLOYED"),
        3: .same(proto: "BORROWER_EMPLOYMENT_TYPE_BUSINESS"),
    ]
}

extension Onboarding_V1_CompleteBorrowerOnboardingRequest: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _onboarding_protobuf_package + ".CompleteBorrowerOnboardingRequest"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .standard(proto: "first_name"),
        2: .standard(proto: "last_name"),
        3: .standard(proto: "date_of_birth"),
        4: .same(proto: "gender"),
        5: .standard(proto: "address_line1"),
        6: .same(proto: "city"),
        7: .same(proto: "state"),
        8: .same(proto: "pincode"),
        9: .standard(proto: "employment_type"),
        10: .standard(proto: "monthly_income"),
        11: .standard(proto: "profile_completeness_percent"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularStringField(value: &self.firstName) }()
            case 2: try { try decoder.decodeSingularStringField(value: &self.lastName) }()
            case 3: try { try decoder.decodeSingularStringField(value: &self.dateOfBirth) }()
            case 4: try { try decoder.decodeSingularEnumField(value: &self.gender) }()
            case 5: try { try decoder.decodeSingularStringField(value: &self.addressLine1) }()
            case 6: try { try decoder.decodeSingularStringField(value: &self.city) }()
            case 7: try { try decoder.decodeSingularStringField(value: &self.state) }()
            case 8: try { try decoder.decodeSingularStringField(value: &self.pincode) }()
            case 9: try { try decoder.decodeSingularEnumField(value: &self.employmentType) }()
            case 10: try { try decoder.decodeSingularStringField(value: &self.monthlyIncome) }()
            case 11: try { try decoder.decodeSingularInt32Field(value: &self.profileCompletenessPercent) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if !self.firstName.isEmpty { try visitor.visitSingularStringField(value: self.firstName, fieldNumber: 1) }
        if !self.lastName.isEmpty { try visitor.visitSingularStringField(value: self.lastName, fieldNumber: 2) }
        if !self.dateOfBirth.isEmpty { try visitor.visitSingularStringField(value: self.dateOfBirth, fieldNumber: 3) }
        if self.gender != .unspecified { try visitor.visitSingularEnumField(value: self.gender, fieldNumber: 4) }
        if !self.addressLine1.isEmpty { try visitor.visitSingularStringField(value: self.addressLine1, fieldNumber: 5) }
        if !self.city.isEmpty { try visitor.visitSingularStringField(value: self.city, fieldNumber: 6) }
        if !self.state.isEmpty { try visitor.visitSingularStringField(value: self.state, fieldNumber: 7) }
        if !self.pincode.isEmpty { try visitor.visitSingularStringField(value: self.pincode, fieldNumber: 8) }
        if self.employmentType != .unspecified { try visitor.visitSingularEnumField(value: self.employmentType, fieldNumber: 9) }
        if !self.monthlyIncome.isEmpty { try visitor.visitSingularStringField(value: self.monthlyIncome, fieldNumber: 10) }
        if self.profileCompletenessPercent != 0 { try visitor.visitSingularInt32Field(value: self.profileCompletenessPercent, fieldNumber: 11) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Onboarding_V1_CompleteBorrowerOnboardingRequest, rhs: Onboarding_V1_CompleteBorrowerOnboardingRequest) -> Bool {
        return lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName &&
               lhs.dateOfBirth == rhs.dateOfBirth && lhs.gender == rhs.gender &&
               lhs.addressLine1 == rhs.addressLine1 && lhs.city == rhs.city &&
               lhs.state == rhs.state && lhs.pincode == rhs.pincode &&
               lhs.employmentType == rhs.employmentType && lhs.monthlyIncome == rhs.monthlyIncome &&
               lhs.profileCompletenessPercent == rhs.profileCompletenessPercent &&
               lhs.unknownFields == rhs.unknownFields
    }
}

extension Onboarding_V1_CompleteBorrowerOnboardingResponse: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
    public static let protoMessageName: String = _onboarding_protobuf_package + ".CompleteBorrowerOnboardingResponse"
    public static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
        1: .same(proto: "success"),
    ]
    public mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
        while let fieldNumber = try decoder.nextFieldNumber() {
            switch fieldNumber {
            case 1: try { try decoder.decodeSingularBoolField(value: &self.success) }()
            default: break
            }
        }
    }
    public func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
        if self.success { try visitor.visitSingularBoolField(value: self.success, fieldNumber: 1) }
        try unknownFields.traverse(visitor: &visitor)
    }
    public static func ==(lhs: Onboarding_V1_CompleteBorrowerOnboardingResponse, rhs: Onboarding_V1_CompleteBorrowerOnboardingResponse) -> Bool {
        return lhs.success == rhs.success && lhs.unknownFields == rhs.unknownFields
    }
}
