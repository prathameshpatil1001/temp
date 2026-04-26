// TOTPProvider.swift
// lms_borrower/Utils
//
// Utility for generating a Core Image QR Code from the backend's provisioning_uri.

import SwiftUI
import CoreImage.CIFilterBuiltins

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
}
