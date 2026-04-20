// AnalyticsManager.swift
// lms_borrower/Services
//
// Thin wrapper for analytics event tracking.

import Foundation

public enum AppAnalyticsEvent {
    case screenView(name: String)
    case signupStarted
    case signupCompleted
    case loginStarted
    case loginCompleted
    case kycStarted
    case kycCompleted
    case kycFailed
    
    var eventName: String {
        switch self {
        case .screenView: return "screen_view"
        case .signupStarted: return "signup_started"
        case .signupCompleted: return "signup_completed"
        case .loginStarted: return "login_started"
        case .loginCompleted: return "login_completed"
        case .kycStarted: return "kyc_started"
        case .kycCompleted: return "kyc_completed"
        case .kycFailed: return "kyc_failed"
        }
    }
    
    var parameters: [String: Any]? {
        switch self {
        case .screenView(let name):
            return ["screen_name": name]
        default:
            return nil
        }
    }
}

public final class AnalyticsManager: @unchecked Sendable {
    public static let shared = AnalyticsManager()
    
    private init() {}
    
    public func logEvent(_ event: AppAnalyticsEvent) {
        // Placeholder for actual analytics SDK (e.g. Firebase, Mixpanel, os_log)
        #if DEBUG
        if let params = event.parameters {
            print("[\(event.eventName)] \(params)")
        } else {
            print("[\(event.eventName)]")
        }
        #endif
    }
}
