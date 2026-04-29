import Foundation
import UIKit
import Vision
import PDFKit
import AVFoundation
import UniformTypeIdentifiers
import CoreImage

@available(iOS 18.0, *)
struct LocalDocumentCandidate {
    let data: Data
    let mimeType: String
    let previewImage: UIImage
    let pageCount: Int
    let isPDF: Bool
    let runsEdgeDetection: Bool
    fileprivate let validationImages: [UIImage]
}

@available(iOS 18.0, *)
struct LocalDocumentValidationSummary {
    let blurPassed: Bool
    let edgePassed: Bool
    let runsEdgeDetection: Bool
    let hasText: Bool
    let averageTextConfidence: Float
    let minimumTextConfidence: Float
    let recognizedTextBlockCount: Int

    var textConfidencePassed: Bool {
        averageTextConfidence >= 0.82 && minimumTextConfidence >= 0.55
    }

    var hasEnoughText: Bool {
        recognizedTextBlockCount >= 6
    }

    var isAccepted: Bool {
        blurPassed && edgePassed && hasText && hasEnoughText && textConfidencePassed
    }

    var failureMessage: String {
        if !hasText {
            return "Invalid upload. No readable text found."
        }
        if !hasEnoughText || !textConfidencePassed {
            return "Image unclear, retake"
        }
        return "Image unclear, retake"
    }
}

@available(iOS 18.0, *)
final class LocalDocumentValidationService {
    private let ciContext = CIContext()

    func makeCandidate(fromFileAt url: URL) throws -> LocalDocumentCandidate {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let type = UTType(filenameExtension: url.pathExtension)

        if type?.conforms(to: .pdf) == true {
            return try makePDFCandidate(from: data, runsEdgeDetection: false)
        }

        guard let image = UIImage(data: data) else {
            throw LocalDocumentValidationError.unsupportedFile
        }

        return LocalDocumentCandidate(
            data: data,
            mimeType: type?.preferredMIMEType ?? "image/jpeg",
            previewImage: image,
            pageCount: 1,
            isPDF: false,
            runsEdgeDetection: false,
            validationImages: [image]
        )
    }

    func makeCandidate(fromScannedPages pages: [UIImage]) throws -> LocalDocumentCandidate {
        guard !pages.isEmpty else {
            throw LocalDocumentValidationError.emptyScan
        }

        let pdfData = try makePDFData(from: pages)
        let pdfCandidate = try makePDFCandidate(from: pdfData, runsEdgeDetection: true)
        return pdfCandidate
    }

    func validate(_ candidate: LocalDocumentCandidate) async -> LocalDocumentValidationSummary {
        let pageChecks = candidate.validationImages.map { image in
            (
                blurPassed: passesBlurCheck(image),
                edgePassed: !candidate.runsEdgeDetection || detectsDocumentEdges(image),
                textCheck: recognizeText(in: image)
            )
        }

        let blurPassed = !pageChecks.isEmpty && pageChecks.allSatisfy(\.blurPassed)
        let edgePassed = pageChecks.allSatisfy(\.edgePassed)
        var hasText = false
        var confidenceValues: [Float] = []
        var recognizedTextBlockCount = 0

        for pageCheck in pageChecks {
            let textCheck = pageCheck.textCheck
            hasText = hasText || textCheck.hasText
            if textCheck.hasText {
                confidenceValues.append(textCheck.averageConfidence)
                recognizedTextBlockCount += textCheck.blockCount
            }
        }

        let averageConfidence: Float
        if confidenceValues.isEmpty {
            averageConfidence = 0
        } else {
            averageConfidence = confidenceValues.reduce(0, +) / Float(confidenceValues.count)
        }

        let minimumConfidence = confidenceValues.min() ?? 0

        return LocalDocumentValidationSummary(
            blurPassed: blurPassed,
            edgePassed: edgePassed,
            runsEdgeDetection: candidate.runsEdgeDetection,
            hasText: hasText,
            averageTextConfidence: averageConfidence,
            minimumTextConfidence: minimumConfidence,
            recognizedTextBlockCount: recognizedTextBlockCount
        )
    }

    private func makePDFCandidate(from data: Data, runsEdgeDetection: Bool) throws -> LocalDocumentCandidate {
        guard let document = PDFDocument(data: data), document.pageCount > 0 else {
            throw LocalDocumentValidationError.invalidPDF
        }

        var validationImages: [UIImage] = []
        for index in 0..<min(document.pageCount, 3) {
            guard let page = document.page(at: index),
                  let image = renderPDFPage(page) else { continue }
            validationImages.append(image)
        }

        guard let previewImage = validationImages.first else {
            throw LocalDocumentValidationError.invalidPDF
        }

        return LocalDocumentCandidate(
            data: data,
            mimeType: "application/pdf",
            previewImage: previewImage,
            pageCount: document.pageCount,
            isPDF: true,
            runsEdgeDetection: runsEdgeDetection,
            validationImages: validationImages
        )
    }

    private func makePDFData(from pages: [UIImage]) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
        return renderer.pdfData { context in
            for image in pages {
                context.beginPage()
                let fittedRect = AVMakeRect(aspectRatio: image.size, insideRect: CGRect(x: 24, y: 24, width: 547, height: 794))
                image.draw(in: fittedRect)
            }
        }
    }

    private func renderPDFPage(_ page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        let scale = min(2.0, 1200 / max(bounds.width, 1))
        let targetSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: targetSize))

            context.cgContext.saveGState()
            context.cgContext.translateBy(x: 0, y: targetSize.height)
            context.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: context.cgContext)
            context.cgContext.restoreGState()
        }
    }

    private func passesBlurCheck(_ image: UIImage) -> Bool {
        guard let ciImage = CIImage(image: image) else {
            return false
        }

        let prepared = preparedValidationImage(from: ciImage)
        let edgeStrength = meanIntensity(
            of: prepared.applyingFilter("CIEdges", parameters: ["inputIntensity": 8.0])
        )

        let blurred = prepared
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.2])
            .cropped(to: prepared.extent)

        let highFrequencyDifference = prepared
            .applyingFilter("CIDifferenceBlendMode", parameters: [kCIInputBackgroundImageKey: blurred])
            .cropped(to: prepared.extent)

        let sharpnessDelta = meanIntensity(of: highFrequencyDifference)

        return edgeStrength > 0.12 && sharpnessDelta > 0.035
    }

    private func preparedValidationImage(from ciImage: CIImage) -> CIImage {
        let extent = ciImage.extent
        let maxDimension = max(extent.width, extent.height)
        let scale = maxDimension > 1400 ? 1400 / maxDimension : 1

        return ciImage
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 1.1
            ])
    }

    private func meanIntensity(of image: CIImage) -> Double {
        let average = image.applyingFilter(
            "CIAreaAverage",
            parameters: [kCIInputExtentKey: CIVector(cgRect: image.extent)]
        )

        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(
            average,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        let channelTotal = Int(bitmap[0]) + Int(bitmap[1]) + Int(bitmap[2])
        return Double(channelTotal) / (255.0 * 3.0)
    }

    private func detectsDocumentEdges(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else {
            return false
        }

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 2
        request.minimumConfidence = 0.5
        request.minimumSize = 0.3

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let rectangle = request.results?.first else {
                return false
            }
            let area = rectangle.boundingBox.width * rectangle.boundingBox.height
            return area > 0.2
        } catch {
            return false
        }
    }

    private func recognizeText(in image: UIImage) -> (hasText: Bool, averageConfidence: Float, blockCount: Int) {
        guard let cgImage = image.cgImage else {
            return (false, 0, 0)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
            guard !candidates.isEmpty else {
                return (false, 0, 0)
            }

            let total = candidates.reduce(Float(0)) { $0 + $1.confidence }
            return (true, total / Float(candidates.count), candidates.count)
        } catch {
            return (false, 0, 0)
        }
    }
}

@available(iOS 18.0, *)
private enum LocalDocumentValidationError: LocalizedError {
    case unsupportedFile
    case invalidPDF
    case emptyScan

    var errorDescription: String? {
        switch self {
        case .unsupportedFile:
            return "Choose a valid image or PDF file."
        case .invalidPDF:
            return "The selected PDF could not be validated."
        case .emptyScan:
            return "No document pages were captured."
        }
    }
}
