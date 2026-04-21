// Services/QRGenerator.swift
// LoanOS — Borrower App
// Generates QR code UIImages from strings using CoreImage.

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// ═══════════════════════════════════════════════════════════════
// MARK: - QR Code Generator Service
// ═══════════════════════════════════════════════════════════════

enum QRGen {
    static func make(_ s: String) -> UIImage? {
        let ctx = CIContext(); let f = CIFilter.qrCodeGenerator()
        f.message = Data(s.utf8); f.correctionLevel = "M"
        guard let ci = f.outputImage else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}
