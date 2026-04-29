// TOTPProvider.swift
// lms_borrower/Utils
//
// Utility for generating a Core Image QR Code from the backend's provisioning_uri.

import SwiftUI
import CoreImage.CIFilterBuiltins
import CryptoKit

@MainActor
public enum TOTPProvider {
    
    /// Generates a SwiftUI Image containing the QR code for a provisioning URI.
    ///
    /// - Parameter uri: The `otpauth://...` URI returned by the backend `SetupTOTP` RPC.
    /// - Returns: A SwiftUI Image that scales nicely, or `nil` if generation fails.
    public static func generateQRCode(from uri: String) -> Image? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(uri.utf8)
        filter.correctionLevel = "M" // Medium error correction is fine for typical authenticator scans
        
        guard let outputImage = filter.outputImage else {
            return nil
        }
        
        // Scale up the image so it doesn't look blurry when rendered in SwiftUI.
        // A scale of 10 usually gives a sharp image on retina displays.
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
    }

    /// Validates a 6-digit TOTP code against a Base32 secret.
    public static func isValid(
        code: String,
        secret: String,
        digits: Int = 6,
        period: TimeInterval = 30,
        allowedDrift: Int = 1
    ) -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == digits, trimmedCode.allSatisfy(\.isNumber) else { return false }
        guard let secretData = decodeBase32(secret) else { return false }

        let counter = Int(Date().timeIntervalSince1970 / period)
        for drift in -allowedDrift...allowedDrift {
            if otp(secret: secretData, counter: counter + drift, digits: digits) == trimmedCode {
                return true
            }
        }
        return false
    }

    private static func otp(secret: Data, counter: Int, digits: Int) -> String {
        var movingFactor = UInt64(max(counter, 0)).bigEndian
        let counterData = Data(bytes: &movingFactor, count: MemoryLayout<UInt64>.size)

        let key = SymmetricKey(data: secret)
        let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
        let hash = Array(hmac)

        let offset = Int(hash[hash.count - 1] & 0x0f)
        let binary =
            (UInt32(hash[offset] & 0x7f) << 24) |
            (UInt32(hash[offset + 1]) << 16) |
            (UInt32(hash[offset + 2]) << 8) |
            UInt32(hash[offset + 3])

        let modulo = UInt32(pow(10.0, Double(digits)))
        let otpValue = binary % modulo
        return String(format: "%0*u", digits, otpValue)
    }

    private static func decodeBase32(_ value: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        let decodeTable = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })

        let cleaned = value
            .uppercased()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")

        var buffer = 0
        var bitsLeft = 0
        var bytes: [UInt8] = []

        for char in cleaned {
            guard let charValue = decodeTable[char] else { return nil }
            buffer = (buffer << 5) | charValue
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                let byte = UInt8((buffer >> bitsLeft) & 0xff)
                bytes.append(byte)
            }
        }

        return Data(bytes)
    }
}
