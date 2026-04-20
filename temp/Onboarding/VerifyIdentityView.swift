import SwiftUI

struct VerifyIdentityView: View {
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDocument: IdentityDocumentType?
    @State private var selectedAction: UploadAction?

    private var hasUploadedDocument: Bool {
        selectedDocument != nil && selectedAction != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    documentSection

                    if let selectedDocument {
                        selectedDocumentSection(selectedDocument)
                        uploadOptionsSection
                    }

                    if hasUploadedDocument {
                        uploadedPreviewSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }

            if hasUploadedDocument {
                bottomBar
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Verify Identity")
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose an identity document")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.textPrimary)

            Text("Select a document, then choose how you want to add it.")
                .font(.system(size: 17))
                .foregroundStyle(DS.textSecondary)
        }
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            VStack(spacing: 0) {
                documentRow(.aadhaar)
                divider
                documentRow(.pan)
                divider
                documentRow(.passport)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func documentRow(_ document: IdentityDocumentType) -> some View {
        let isSelected = selectedDocument == document

        return Button {
            selectedDocument = document
            selectedAction = nil
        } label: {
            HStack(spacing: 14) {
                Image(systemName: document.icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(DS.primary)
                    .frame(width: 34, height: 34)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DS.textPrimary)

                    Text(document.subtitle)
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

    private func selectedDocumentSection(_ document: IdentityDocumentType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add \(document.title) using")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(DS.textPrimary)

            Text("Choose one option below.")
                .font(.system(size: 15))
                .foregroundStyle(DS.textSecondary)
        }
    }

    private var uploadOptionsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                uploadOptionButton(.digiLocker)
                uploadOptionButton(.files)
                uploadOptionButton(.camera)
            }

            if let selectedAction {
                Text(selectedAction.helperText)
                    .font(.system(size: 13))
                    .foregroundStyle(DS.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
            }
        }
    }

    private func uploadOptionButton(_ action: UploadAction) -> some View {
        let isSelected = selectedAction == action

        return Button {
            selectedAction = action
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? DS.primary : DS.primaryLight)
                        .frame(width: 52, height: 52)

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
            .frame(height: 128)
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
            Text("Added document")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(DS.primaryLight)
                    .frame(width: 64, height: 80)
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
            PrimaryBtn(title: "Continue", disabled: false) {
                path.append(KYCRoute.review)
            }

            Text("Your selected document is ready")
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
        case .digiLocker: return "Fetched with DigiLocker"
        case .files: return "Added from Files"
        case .camera: return "Captured with Camera"
        case .none: return "Added"
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
        Divider().padding(.leading, 64)
    }
}

private enum IdentityDocumentType: CaseIterable, Hashable {
    case aadhaar, pan, passport

    var title: String {
        switch self {
        case .aadhaar: return "Aadhaar Card"
        case .pan: return "PAN Card"
        case .passport: return "Passport"
        }
    }

    var subtitle: String {
        switch self {
        case .aadhaar: return "Front and back required"
        case .pan: return "Permanent Account Number"
        case .passport: return "First two pages required"
        }
    }

    var icon: String {
        switch self {
        case .aadhaar: return "person.text.rectangle"
        case .pan: return "creditcard"
        case .passport: return "book.closed"
        }
    }
}

private enum UploadAction: Hashable {
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

    var helperText: String {
        switch self {
        case .digiLocker: return "Continue with DigiLocker"
        case .files: return "Choose a file to upload"
        case .camera: return "Take a photo of your document"
        }
    }
}
