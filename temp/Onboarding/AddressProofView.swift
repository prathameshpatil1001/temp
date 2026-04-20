import SwiftUI

struct AddressProofView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDocument: AddressDocumentType?
    @State private var selectedAction: AddressUploadAction?

    private var hasSelectionPreview: Bool {
        selectedDocument != nil && selectedAction != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    documentSection

                    if let selectedDocument {
                        selectionSummary(document: selectedDocument)
                        uploadOptionsSection
                    }

                    if hasSelectionPreview {
                        uploadedPreviewSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }

            if hasSelectionPreview {
                bottomBar
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Address Proof")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if !path.isEmpty { path.removeLast() } else { dismiss() }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose proof of address")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.textPrimary)

            Text("Use a document that clearly shows your full name and current address.")
                .font(.system(size: 17))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            VStack(spacing: 0) {
                documentRow(.aadhaarCard)
                divider
                documentRow(.utilityBill)
                divider
                documentRow(.bankStatement)
                divider
                documentRow(.rentalAgreement)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func documentRow(_ type: AddressDocumentType) -> some View {
        let isSelected = selectedDocument == type

        return Button {
            selectedDocument = type
            selectedAction = nil
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DS.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(type.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text(type.subtitle)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textSecondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? DS.primary : Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func selectionSummary(document: AddressDocumentType) -> some View {
        HStack(spacing: 12) {
            Image(systemName: document.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DS.primary)
                .frame(width: 34, height: 34)
                .background(DS.primaryLight)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("Selected document")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DS.textSecondary)

                Text(document.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)
            }

            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var uploadOptionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How do you want to add it?")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(DS.textPrimary)

                Text("Choose one option to continue.")
                    .font(.system(size: 15))
                    .foregroundStyle(DS.textSecondary)
            }

            HStack(spacing: 12) {
                uploadOptionButton(.digiLocker)
                uploadOptionButton(.files)
                uploadOptionButton(.camera)
            }
        }
    }

    private func uploadOptionButton(_ action: AddressUploadAction) -> some View {
        let isSelected = selectedAction == action

        return Button {
            selectedAction = action
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.primary : DS.primaryLight)
                        .frame(width: 54, height: 54)

                    Image(systemName: action.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isSelected ? .white : DS.primary)
                }

                VStack(spacing: 2) {
                    Text(action.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)
                        .multilineTextAlignment(.center)

                    if action == .digiLocker {
                        Text("Recommended")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.primary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 126)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? DS.primary.opacity(0.35) : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var uploadedPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready to upload")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.primaryLight)
                    .frame(width: 64, height: 82)
                    .overlay {
                        Image(systemName: previewIcon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(DS.primary)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedDocument?.title ?? "Document")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text(previewTitle)
                        .font(.system(size: 15))
                        .foregroundStyle(DS.textSecondary)

                    Label("Ready to continue", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.primary)
                }

                Spacer()
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Continue", isLoading: viewModel.isLoading, disabled: false) {
                Task {
                    if await viewModel.submitAddressProof() {
                        path.append(KYCRoute.incomeDetails)
                    }
                }
            }

            Text("You can change this before submitting")
                .font(.system(size: 13))
                .foregroundStyle(DS.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var previewTitle: String {
        switch selectedAction {
        case .digiLocker: return "Will be added with DigiLocker"
        case .files: return "Will be uploaded from Files"
        case .camera: return "Will be captured with Camera"
        case .none: return "Ready"
        }
    }

    private var previewIcon: String {
        switch selectedAction {
        case .digiLocker: return "lock.doc"
        case .files: return "doc.fill"
        case .camera: return "camera.fill"
        case .none: return "doc"
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 66)
    }
}

private enum AddressDocumentType: CaseIterable, Hashable {
    case aadhaarCard, utilityBill, bankStatement, rentalAgreement

    var title: String {
        switch self {
        case .aadhaarCard: return "Aadhaar Card"
        case .utilityBill: return "Utility Bill"
        case .bankStatement: return "Bank Statement"
        case .rentalAgreement: return "Rental Agreement"
        }
    }

    var subtitle: String {
        switch self {
        case .aadhaarCard: return "Government-issued document"
        case .utilityBill: return "Electricity, water, or gas bill"
        case .bankStatement: return "Recent bank statement"
        case .rentalAgreement: return "Signed rental agreement"
        }
    }

    var icon: String {
        switch self {
        case .aadhaarCard: return "person.text.rectangle"
        case .utilityBill: return "bolt.fill"
        case .bankStatement: return "building.columns"
        case .rentalAgreement: return "doc.text"
        }
    }
}

private enum AddressUploadAction: Hashable {
    case digiLocker, files, camera

    var title: String {
        switch self {
        case .digiLocker: return "DigiLocker"
        case .files: return "Files"
        case .camera: return "Camera"
        }
    }

    var icon: String {
        switch self {
        case .digiLocker: return "lock.shield"
        case .files: return "doc"
        case .camera: return "camera"
        }
    }
}
