import SwiftUI

struct IncomeDetailsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDocument: IncomeDocumentType?
    @State private var selectedAction: IncomeUploadAction?
    @State private var uploadedItems: [String] = []

    private var hasPreview: Bool {
        !uploadedItems.isEmpty
    }
    
    private var isFormValid: Bool {
        guard let income = Decimal(string: viewModel.netMonthlyIncome.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return income > 0
    }

    let employmentTypes = ["Salaried", "Self-Employed", "Business Owner", "Student", "Retired"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    
                    formSection

                    documentSection

                    if let selectedDocument {
                        selectionSummary(document: selectedDocument)
                        uploadOptionsSection
                    }

                    if hasPreview {
                        uploadedPreviewSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }

            if !viewModel.netMonthlyIncome.isEmpty {
                bottomBar
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Income Details")
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
                .accessibilityLabel("Back")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add income details")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(DS.textPrimary)

            Text("Enter your employment details and provide a document to verify your income.")
                .font(.system(size: 17))
                .foregroundStyle(DS.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var formSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Employment Type")
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                Picker("Employment Type", selection: $viewModel.selectedEmploymentStatus) {
                    ForEach(employmentTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Monthly Income (₹)")
                    .font(.caption)
                    .foregroundStyle(DS.textSecondary)
                TextField("E.g. 50000", text: $viewModel.netMonthlyIncome)
                    .keyboardType(.decimalPad)
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Document")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            VStack(spacing: 0) {
                documentRow(.salarySlip)
                divider
                documentRow(.bankStatement)
                divider
                documentRow(.itr)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func documentRow(_ type: IncomeDocumentType) -> some View {
        let isSelected = selectedDocument == type

        return Button {
            selectedDocument = type
            selectedAction = nil
            uploadedItems = []
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

    private func selectionSummary(document: IncomeDocumentType) -> some View {
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

                Text(uploadHint)
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

    private func uploadOptionButton(_ action: IncomeUploadAction) -> some View {
        let isSelected = selectedAction == action

        return Button {
            selectedAction = action
            uploadedItems = mockUploads(for: action)
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
            Text("Added")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DS.textSecondary)

            VStack(spacing: 12) {
                ForEach(uploadedItems, id: \.self) { item in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(DS.primaryLight)
                            .frame(width: 52, height: 64)
                            .overlay {
                                Image(systemName: previewIcon)
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(DS.primary)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DS.textPrimary)

                            Text(previewSubtitle)
                                .font(.system(size: 14))
                                .foregroundStyle(DS.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(DS.primary)
                    }
                    .padding(14)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            PrimaryBtn(title: "Save & Continue", isLoading: viewModel.isLoading, disabled: !isFormValid) {
                Task {
                    if await viewModel.submitIncomeDetails() {
                        path.append(KYCRoute.review)
                    }
                }
            }

            if !isFormValid {
                Text("Complete income form & upload document to proceed.")
                    .font(.footnote)
                    .foregroundStyle(DS.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }

    private var uploadHint: String {
        switch selectedDocument {
        case .salarySlip: return "Add your latest 3 salary slips."
        case .bankStatement: return "Add a recent bank statement."
        case .itr: return "Add your latest ITR."
        case .none: return ""
        }
    }

    private var previewSubtitle: String {
        switch selectedAction {
        case .digiLocker: return "Added with DigiLocker"
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

    private func mockUploads(for action: IncomeUploadAction) -> [String] {
        guard let selectedDocument else { return [] }

        switch selectedDocument {
        case .salarySlip: return ["Salary Slip 1", "Salary Slip 2", "Salary Slip 3"]
        case .bankStatement: return ["Bank Statement"]
        case .itr: return ["Latest ITR"]
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 66)
    }
}

private enum IncomeDocumentType: CaseIterable, Hashable {
    case salarySlip, bankStatement, itr

    var title: String {
        switch self {
        case .salarySlip: return "Salary Slip"
        case .bankStatement: return "Bank Statement"
        case .itr: return "ITR"
        }
    }

    var subtitle: String {
        switch self {
        case .salarySlip: return "Last 3 months preferred"
        case .bankStatement: return "Recent statement"
        case .itr: return "Latest filed return"
        }
    }

    var icon: String {
        switch self {
        case .salarySlip: return "doc.text"
        case .bankStatement: return "building.columns"
        case .itr: return "indianrupeesign.square"
        }
    }
}

private enum IncomeUploadAction: Hashable {
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
