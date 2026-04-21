import SwiftUI
import UIKit

struct LivePhotoCaptureView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    private var hasPhoto: Bool { capturedImage != nil || viewModel.selfieImageData != nil }

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Live Photo", systemImage: "faceid")
                    .font(.title2.bold())
                Text("Capture a quick selfie for liveness verification.")
                    .foregroundStyle(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 240, height: 240)

                if let image = displayImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 240, height: 240)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 72))
                        .foregroundStyle(DS.textSecondary)
                }
            }

            HStack(spacing: 12) {
                Button(hasPhoto ? "Retake" : "Take Selfie") {
                    showCamera = true
                }
                .buttonStyle(.bordered)

                if hasPhoto {
                    Button("Use this photo") {
                        path.append(KYCRoute.eSignature)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            Spacer()

            PrimaryBtn(title: "Continue", disabled: !hasPhoto) {
                path.append(KYCRoute.eSignature)
            }
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Live Photo")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                capturedImage = image
                viewModel.selfieImageData = image.jpegData(compressionQuality: 0.85)
            }
        }
    }

    private var displayImage: UIImage? {
        if let capturedImage {
            return capturedImage
        }
        if let data = viewModel.selfieImageData {
            return UIImage(data: data)
        }
        return nil
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
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
