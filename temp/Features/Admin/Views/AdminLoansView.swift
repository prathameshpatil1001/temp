import SwiftUI

struct AdminLoansView: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Binding var showProfile: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var columns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 340, maximum: 600), spacing: Theme.Spacing.lg)
        ]
    }

    private var addLoanSheetBinding: Binding<Bool> {
        Binding(
            get: { loansVM.showAddLoanSheet },
            set: { loansVM.showAddLoanSheet = $0 }
        )
    }

    private var editingLoanBinding: Binding<LoanProduct?> {
        Binding(
            get: { loansVM.editingLoan },
            set: { loansVM.editingLoan = $0 }
        )
    }

    private var showActionAlertBinding: Binding<Bool> {
        Binding(
            get: { loansVM.showActionAlert },
            set: { loansVM.showActionAlert = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        header
                        searchBar

                        if loansVM.isLoading && loansVM.loanProducts.isEmpty {
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 400)
                        } else if loansVM.filteredProducts.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(columns: columns, spacing: Theme.Spacing.lg) {
                                ForEach(loansVM.filteredProducts) { product in
                                    LoanProductCard(product: product)
                                }
                            }
                            .padding(.horizontal, Theme.Spacing.lg)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .refreshable {
                    await loansVM.refresh()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if loansVM.isSaving {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Button {
                            loansVM.showAddLoanSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(loansVM.isSaving)

                        ProfileNavButton(showProfile: $showProfile)
                    }
                }
            }
            .task {
                loansVM.loadData()
            }
            .sheet(isPresented: addLoanSheetBinding) {
                AddLoanSheet()
                    .environmentObject(loansVM)
            }
            .sheet(item: editingLoanBinding) { loan in
                EditLoanSheet(product: loan)
                    .environmentObject(loansVM)
            }
            .alert(loansVM.actionMessage ?? "", isPresented: showActionAlertBinding) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            
            TextField("Search catalog...", text: $loansVM.searchText)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "banknote")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    Text("LOAN CATALOG")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.7)
                }
                Text("Loan Products")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer()
            Text("\(loansVM.filteredProducts.count) Products")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No loan products found")
                .font(Theme.Typography.headline)
                .foregroundStyle(.secondary)
            Text("Products shown here now come directly from the backend catalog.")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

struct LoanProductCard: View {
    let product: LoanProduct
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var primary: Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var surface: Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var border: Color { Theme.Colors.adaptiveBorder(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section: icon + product info + actions
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .fill(primary.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: product.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    HStack(spacing: 6) {
                        pill(product.categoryLabel, color: primary)
                        if !product.isActive { pill("Inactive", color: .secondary) }
                    }
                }

                Spacer()

                statusBadge
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // Bottom section: key metrics + edit/delete
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.amountRangeDisplay)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(product.rateDisplay)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 16) {
                    miniKPI(label: "Fees", value: "\(product.fees.count)")
                    if product.isRequiringCollateral { miniKPI(label: "Collateral", value: "Yes") }
                    miniKPI(label: "Docs", value: "\(product.requiredDocuments.count)")
                }

                Spacer()

                HStack(spacing: 8) {
                    iconButton(icon: "pencil", color: primary) { loansVM.editingLoan = product }
                    iconButton(icon: "trash", color: Theme.Colors.critical) { loansVM.deleteLoanProduct(product) }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemFill).opacity(0.4))
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        let color: Color = product.isActive ? Theme.Colors.adaptiveSuccess(colorScheme) : .gray
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(product.isActive ? "Active" : "Inactive")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private func iconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private func miniKPI(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label + ":")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private func pill(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.05))
            .foregroundStyle(color.opacity(0.8))
            .clipShape(Capsule())
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Colors.adaptiveBorder(colorScheme))
            .frame(width: 0.5, height: 24)
            .padding(.horizontal, Theme.Spacing.sm)
    }

    private func cardKPI(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(Theme.Typography.caption2)
            }
            .foregroundStyle(.secondary)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AddLoanSheet: View {
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft = LoanDraft.defaultDraft

    var body: some View {
        LoanProductEditor(title: "Add New Loan", draft: $draft, isSaving: loansVM.isSaving) { product in
            loansVM.addLoanProduct(product)
            dismiss()
        }
    }
}

struct EditLoanSheet: View {
    let product: LoanProduct
    @EnvironmentObject var loansVM: AdminLoansViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: LoanDraft

    init(product: LoanProduct) {
        self.product = product
        _draft = State(initialValue: LoanDraft(product: product))
    }

    var body: some View {
        LoanProductEditor(title: "Edit Loan", draft: $draft, isSaving: loansVM.isSaving) { updated in
            loansVM.updateLoanProduct(oldProduct: product, newProduct: updated)
            dismiss()
        }
    }
}

private struct LoanProductEditor: View {
    let title: String
    @Binding var draft: LoanDraft
    let isSaving: Bool
    let onSave: (LoanProduct) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Product name", text: $draft.name)
                        .font(.system(size: 16, weight: .medium))
                    Picker("Category", selection: $draft.category) {
                        ForEach(LoanDraft.availableCategories, id: \.self) { category in
                            Text(LoanDraft.categoryLabel(for: category)).tag(category)
                        }
                    }
                    Picker("Interest type", selection: $draft.interestType) {
                        ForEach(LoanDraft.availableInterestTypes, id: \.self) { type in
                            Text(LoanDraft.interestLabel(for: type)).tag(type)
                        }
                    }
                    Toggle("Requires collateral", isOn: $draft.isRequiringCollateral)
                    Toggle("Active", isOn: $draft.isActive)
                } header: {
                    Text("General").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }

                Section {
                    numericField("Interest rate (%)", text: $draft.baseInterestRate)
                    numericField("Min amount", text: $draft.minAmount, prefix: "₹")
                    numericField("Max amount", text: $draft.maxAmount, prefix: "₹")
                } header: {
                    Text("Pricing").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }

                Section {
                    integerField("Min age", text: $draft.minAge)
                    numericField("Min monthly income", text: $draft.minMonthlyIncome, prefix: "₹")
                    integerField("Min bureau score", text: $draft.minBureauScore)
                    TextField("Employment types", text: $draft.allowedEmploymentTypes)
                        .font(.system(size: 14))
                } header: {
                    Text("Eligibility").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }

                Section {
                    if draft.fees.isEmpty {
                        Text("No fees").font(.system(size: 14)).foregroundStyle(.secondary).padding(.vertical, 4)
                    }
                    
                    ForEach($draft.fees) { $fee in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Fee Item").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) {
                                    if let idx = draft.fees.firstIndex(where: { $0.id == fee.id }) {
                                        draft.fees.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Picker("Type", selection: $fee.type) {
                                ForEach(LoanDraft.availableFeeTypes, id: \.self) { type in
                                    Text(LoanDraft.feeTypeLabel(for: type)).tag(type)
                                }
                            }
                            
                            if fee.type == .unspecified {
                                HStack {
                                    Text("Custom Type")
                                    Spacer()
                                    TextField("e.g. Legal Fee", text: $fee.customType)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 150)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Picker("Calculation", selection: $fee.calcMethod) {
                                ForEach(LoanDraft.availableCalcMethods, id: \.self) { method in
                                    Text(LoanDraft.calcMethodLabel(for: method)).tag(method)
                                }
                            }
                            
                            HStack {
                                Text("Value")
                                Spacer()
                                TextField("0.00", text: $fee.value)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 100)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.05))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button {
                        withAnimation { draft.fees.append(.empty) }
                    } label: {
                        Label("Add Another Fee", systemImage: "plus.circle.fill")
                            .font(Theme.Typography.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Fees").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }

                Section {
                    if draft.documents.isEmpty {
                        Text("No documents").font(.system(size: 14)).foregroundStyle(.secondary).padding(.vertical, 4)
                    }
                    
                    ForEach($draft.documents) { $document in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Document Requirement").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button(role: .destructive) {
                                    if let idx = draft.documents.firstIndex(where: { $0.id == document.id }) {
                                        draft.documents.remove(at: idx)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Picker("Type", selection: $document.requirementType) {
                                ForEach(LoanDraft.availableDocumentTypes, id: \.self) { type in
                                    Text(LoanDraft.documentLabel(for: type)).tag(type)
                                }
                            }

                            if document.requirementType == .unspecified {
                                HStack {
                                    Text("Custom Document")
                                    Spacer()
                                    TextField("e.g. Birth Certificate", text: $document.customType)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 150)
                                        .padding(8)
                                        .background(Color.secondary.opacity(0.05))
                                        .cornerRadius(8)
                                }
                            }
                            
                            Toggle("Mandatory Requirement", isOn: $document.isMandatory)
                                .font(Theme.Typography.subheadline)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button {
                        withAnimation { draft.documents.append(.empty) }
                    } label: {
                        Label("Add Another Document", systemImage: "plus.circle.fill")
                            .font(Theme.Typography.caption)
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Documents").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving..." : "Done") {
                        onSave(draft.toProduct())
                    }
                    .disabled(!draft.isValid || isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func numericField(_ title: String, text: Binding<String>, prefix: String? = nil) -> some View {
        HStack {
            Text(title)
            Spacer()
            if let prefix {
                Text(prefix).foregroundStyle(.secondary)
            }
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
    }

    private func integerField(_ title: String, text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }
}

private struct LoanDraft {
    struct FeeDraft: Identifiable {
        var id = UUID()
        var type: Loan_V1_ProductFeeType
        var customType: String = ""
        var calcMethod: Loan_V1_FeeCalcMethod
        var value: String

        static let empty = FeeDraft(type: .processing, calcMethod: .percentage, value: "")
    }

    struct DocumentDraft: Identifiable {
        var id = UUID()
        var requirementType: Loan_V1_DocumentRequirementType
        var customType: String = ""
        var isMandatory: Bool

        static let empty = DocumentDraft(requirementType: .identity, isMandatory: true)
    }

    var id: String
    var name: String
    var category: Loan_V1_LoanProductCategory
    var interestType: Loan_V1_InterestType
    var baseInterestRate: String
    var minAmount: String
    var maxAmount: String
    var isRequiringCollateral: Bool
    var isActive: Bool
    var minAge: String
    var minMonthlyIncome: String
    var minBureauScore: String
    var allowedEmploymentTypes: String
    var fees: [FeeDraft]
    var documents: [DocumentDraft]

    static let availableCategories: [Loan_V1_LoanProductCategory] = [.home, .personal, .vehicle, .education]
    static let availableInterestTypes: [Loan_V1_InterestType] = [.fixed, .floating]
    static let availableFeeTypes: [Loan_V1_ProductFeeType] = [.processing, .prepayment, .latePayment, .unspecified]
    static let availableCalcMethods: [Loan_V1_FeeCalcMethod] = [.flat, .percentage]
    static let availableDocumentTypes: [Loan_V1_DocumentRequirementType] = [.identity, .address, .income, .collateral, .unspecified]

    init(
        id: String,
        name: String,
        category: Loan_V1_LoanProductCategory,
        interestType: Loan_V1_InterestType,
        baseInterestRate: String,
        minAmount: String,
        maxAmount: String,
        isRequiringCollateral: Bool,
        isActive: Bool,
        minAge: String,
        minMonthlyIncome: String,
        minBureauScore: String,
        allowedEmploymentTypes: String,
        fees: [FeeDraft],
        documents: [DocumentDraft]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.interestType = interestType
        self.baseInterestRate = baseInterestRate
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.isRequiringCollateral = isRequiringCollateral
        self.isActive = isActive
        self.minAge = minAge
        self.minMonthlyIncome = minMonthlyIncome
        self.minBureauScore = minBureauScore
        self.allowedEmploymentTypes = allowedEmploymentTypes
        self.fees = fees
        self.documents = documents
    }

    static let defaultDraft = LoanDraft(
        id: "",
        name: "",
        category: .home,
        interestType: .fixed,
        baseInterestRate: "8.5",
        minAmount: "100000",
        maxAmount: "5000000",
        isRequiringCollateral: true,
        isActive: true,
        minAge: "21",
        minMonthlyIncome: "25000",
        minBureauScore: "650",
        allowedEmploymentTypes: "Salaried, Self-employed",
        fees: [.init(type: .processing, calcMethod: .percentage, value: "1.0")],
        documents: [
            .init(requirementType: .identity, isMandatory: true),
            .init(requirementType: .address, isMandatory: true),
            .init(requirementType: .income, isMandatory: true),
            .init(requirementType: .collateral, isMandatory: false)
        ]
    )

    init(product: LoanProduct) {
        self.id = product.id
        self.name = product.name
        self.category = product.category
        self.interestType = product.interestType
        self.baseInterestRate = product.baseInterestRate
        self.minAmount = product.minAmount
        self.maxAmount = product.maxAmount
        self.isRequiringCollateral = product.isRequiringCollateral
        self.isActive = product.isActive
        self.minAge = product.eligibilityRule.map { String($0.minAge) } ?? ""
        self.minMonthlyIncome = product.eligibilityRule?.minMonthlyIncome ?? ""
        self.minBureauScore = product.eligibilityRule.map { String($0.minBureauScore) } ?? ""
        self.allowedEmploymentTypes = product.eligibilityRule?.allowedEmploymentTypes.joined(separator: ", ") ?? ""
        self.fees = product.fees.map { .init(type: $0.type, calcMethod: $0.calcMethod, value: $0.value) }
        self.documents = product.requiredDocuments.map { .init(requirementType: $0.requirementType, isMandatory: $0.isMandatory) }
        if fees.isEmpty { fees = [.empty] }
        if documents.isEmpty { documents = [.empty] }
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && Double(baseInterestRate) != nil
        && Double(minAmount.replacingOccurrences(of: ",", with: "")) != nil
        && Double(maxAmount.replacingOccurrences(of: ",", with: "")) != nil
    }

    func toProduct() -> LoanProduct {
        LoanProduct(
            id: id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            interestType: interestType,
            baseInterestRate: baseInterestRate,
            minAmount: minAmount.replacingOccurrences(of: ",", with: ""),
            maxAmount: maxAmount.replacingOccurrences(of: ",", with: ""),
            isRequiringCollateral: isRequiringCollateral,
            isActive: isActive,
            eligibilityRule: LoanProduct.EligibilityRule(
                id: "",
                minAge: Int(minAge) ?? 0,
                minMonthlyIncome: minMonthlyIncome.replacingOccurrences(of: ",", with: ""),
                minBureauScore: Int(minBureauScore) ?? 0,
                allowedEmploymentTypes: allowedEmploymentTypes
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            ),
            fees: fees.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.map {
                LoanProduct.Fee(id: "", type: $0.type, calcMethod: $0.calcMethod, value: $0.value)
            },
            requiredDocuments: documents.map {
                LoanProduct.RequiredDocument(id: "", requirementType: $0.requirementType, isMandatory: $0.isMandatory)
            }
        )
    }

    static func categoryLabel(for category: Loan_V1_LoanProductCategory) -> String {
        switch category {
        case .home: return "Home"
        case .personal: return "Personal"
        case .vehicle: return "Vehicle"
        case .education: return "Education"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func interestLabel(for type: Loan_V1_InterestType) -> String {
        switch type {
        case .fixed: return "Fixed"
        case .floating: return "Floating"
        case .unspecified, .UNRECOGNIZED(_): return "Unspecified"
        }
    }

    static func feeTypeLabel(for type: Loan_V1_ProductFeeType) -> String {
        switch type {
        case .processing: return "Processing"
        case .prepayment: return "Prepayment"
        case .latePayment: return "Late Payment"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func calcMethodLabel(for method: Loan_V1_FeeCalcMethod) -> String {
        switch method {
        case .flat: return "Flat Amount"
        case .percentage: return "Percentage"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }

    static func documentLabel(for type: Loan_V1_DocumentRequirementType) -> String {
        switch type {
        case .identity: return "Identity"
        case .address: return "Address"
        case .income: return "Income"
        case .collateral: return "Collateral"
        case .unspecified, .UNRECOGNIZED(_): return "Other"
        }
    }
}
