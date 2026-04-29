import SwiftUI
import PhotosUI
import UIKit

struct ESignatureView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @State private var signaturePoints: [CGPoint] = []
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var uploadedImage: UIImage?
    @State private var showCamera = false

    private var hasManualSignature: Bool { !signaturePoints.isEmpty }
    private var hasImageSignature: Bool { uploadedImage != nil }
    private var canContinue: Bool { hasManualSignature || hasImageSignature }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("E-Signature")
                    .font(.title2.bold())
                Text("Sign manually on screen or upload your signature image.")
                    .foregroundStyle(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                SignatureCanvas(points: $signaturePoints)
                    .frame(height: 220)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 12) {
                    Button("Clear Drawing") {
                        signaturePoints.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasManualSignature)

                    PhotosPicker(selection: $selectedImageItem, matching: .images) {
                        Text("Choose Image")
                    }
                    .buttonStyle(.bordered)

                    Button("Camera") {
                        showCamera = true
                    }
                    .buttonStyle(.bordered)
                }

                if let uploadedImage {
                    Image(uiImage: uploadedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Spacer()

            PrimaryBtn(
                title: viewModel.isUploadingSignature ? "Uploading..." : "Continue",
                isLoading: viewModel.isUploadingSignature,
                disabled: !canContinue || viewModel.isUploadingSignature
            ) {
                Task {
                    let payload = signatureUploadPayload()
                    guard let payload else { return }
                    let didUpload = await viewModel.uploadSignature(
                        data: payload.data,
                        fileName: payload.fileName,
                        contentType: payload.contentType
                    )
                    if didUpload {
                        path.append(KYCRoute.review)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("E-Signature")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    uploadedImage = image
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            SignatureImagePicker { image in
                uploadedImage = image
            }
        }
    }

    private func signatureUploadPayload() -> (data: Data, fileName: String, contentType: String)? {
        if let uploadedImage, let data = uploadedImage.jpegData(compressionQuality: 0.9) {
            return (data, "signature_upload.jpg", "image/jpeg")
        }
        let renderer = ImageRenderer(content:
            SignatureCanvas(points: .constant(signaturePoints))
                .frame(width: 1000, height: 320)
                .background(Color.white)
        )
        if let image = renderer.uiImage, let data = image.pngData() {
            return (data, "signature_drawn.png", "image/png")
        }
        return nil
    }
}

private struct SignatureCanvas: View {
    @Binding var points: [CGPoint]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(Color.black, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let boundedPoint = CGPoint(
                            x: min(max(0, value.location.x), proxy.size.width),
                            y: min(max(0, value.location.y), proxy.size.height)
                        )
                        points.append(boundedPoint)
                    }
            )
        }
    }
}

private struct SignatureImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
