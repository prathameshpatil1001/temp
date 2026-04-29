import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct IncomeDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedDocumentName = ""
    @State private var selectedData: Data?
    @State private var selectedContentType = "image/jpeg"

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Income Documents")
                    .font(.title2.bold())
                Text("Upload one proof of income document to continue.")
                    .foregroundStyle(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label(selectedDocumentName.isEmpty ? "Upload Document" : selectedDocumentName, systemImage: "doc.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

//            if viewModel.hasUploadedIncomeDocument {
//                Label("Uploaded to backend", systemImage: "checkmark.circle.fill")
//                    .foregroundStyle(DS.primary)
//            }

            Spacer()

            PrimaryBtn(
                title: viewModel.isUploadingIncomeDocument ? "Uploading..." : "Continue",
                isLoading: viewModel.isUploadingIncomeDocument,
                disabled: selectedData == nil || viewModel.isUploadingIncomeDocument
            ) {
                guard let selectedData else { return }
                Task {
                    let fileName = selectedDocumentName.isEmpty ? "income_document.jpg" : selectedDocumentName
                    let uploaded = await viewModel.uploadIncomeDocument(
                        data: selectedData,
                        fileName: fileName,
                        contentType: selectedContentType
                    )
                    if uploaded {
                        path.append(KYCRoute.livePhoto)
                    }
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Income Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else {
                selectedDocumentName = ""
                selectedData = nil
                return
            }
            selectedDocumentName = newItem.itemIdentifier ?? "income_document.jpg"
            selectedContentType = contentType(for: newItem)
            Task {
                selectedData = try? await newItem.loadTransferable(type: Data.self)
            }
        }
    }

    private func contentType(for item: PhotosPickerItem) -> String {
        guard let type = item.supportedContentTypes.first else {
            return "image/jpeg"
        }
        if type.conforms(to: .pdf) {
            return "application/pdf"
        }
        if type.conforms(to: .png) {
            return "image/png"
        }
        return "image/jpeg"
    }
}
