// Services/BiometricAuth.swift
// LoanOS — Borrower App
// Wraps LocalAuthentication (Face ID / Touch ID) calls.

import LocalAuthentication

// ═══════════════════════════════════════════════════════════════
// MARK: - Biometric Auth Service
// ═══════════════════════════════════════════════════════════════

enum BiometricAuth {
    /// Triggers Face ID / Touch ID and returns on the main thread.
    static func authenticate(reason: String, completion: @escaping (Bool, LAError?) -> Void) {
        let ctx = LAContext()
        var nsErr: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &nsErr) else {
            DispatchQueue.main.async { completion(false, nsErr as? LAError) }
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                           localizedReason: reason) { ok, err in
            DispatchQueue.main.async { completion(ok, err as? LAError) }
        }
    }

    static func humanMessage(for error: LAError?) -> String {
        guard let e = error else { return "Authentication failed." }
        switch e.code {
        case .userCancel:              return "Cancelled — tap to try again."
        case .userFallback:            return "Use device passcode."
        case .biometryNotAvailable:    return "Face ID not available on this device."
        case .biometryNotEnrolled:     return "No Face ID enrolled. Set it up in Settings."
        case .biometryLockout:         return "Face ID locked — use TOTP instead."
        case .authenticationFailed:    return "Face not recognised — try again."
        default:                       return e.localizedDescription
        }
    }
}
