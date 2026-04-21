import SwiftUI
import PhotosUI

struct IncomeDetailsView: View {
    @Binding var path: NavigationPath

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedDocumentName = ""

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

            Spacer()

            PrimaryBtn(title: "Continue", disabled: selectedDocumentName.isEmpty) {
                path.append(KYCRoute.livePhoto)
            }
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Income Details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            selectedDocumentName = newItem?.itemIdentifier ?? "Income document selected"
        }
    }
}
