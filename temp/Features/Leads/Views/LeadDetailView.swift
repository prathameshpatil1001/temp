import SwiftUI

@available(iOS 18.0, *)
struct LeadDetailView: View {
    let lead: Lead
    var onStatusUpdate: ((String, LeadStatus) -> Void)?
    var onLeadSave: ((Lead) -> Void)?      // called when KYC state changes

    @StateObject private var vm: LeadDetailViewModel
    @StateObject private var loanAppVM: LoanApplicationViewModel
    @Environment(\.dismiss) private var dismiss

    init(lead: Lead, onStatusUpdate: ((String, LeadStatus) -> Void)? = nil, onLeadSave: ((Lead) -> Void)? = nil) {
        self.lead = lead
        self.onStatusUpdate = onStatusUpdate
        self.onLeadSave = onLeadSave
        
        let detailVM = LeadDetailViewModel(lead: lead, onStatusUpdate: onStatusUpdate)
        _vm = StateObject(wrappedValue: detailVM)
        
        let appVM = LoanApplicationViewModel(lead: lead)
        appVM.onDocumentUploaded = { [weak detailVM] docID, fileName, mediaFileID in
            detailVM?.markDocumentUploaded(id: docID, fileName: fileName, mediaFileID: mediaFileID)
            detailVM?.verifyUploadedDocument(id: docID)
        }
        _loanAppVM = StateObject(wrappedValue: appVM)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.surfaceSecondary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.md) {

                    // ── 1. Identity card ──
                    identityCard
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    // ── 2. Action buttons ──
                    actionButtons
                        .padding(.horizontal, AppSpacing.md)

                    // ── 3. Documents ──
                    DocumentSectionView(vm: vm, loanAppVM: loanAppVM)
                        .padding(.horizontal, AppSpacing.md)

                    // ── 4. Timeline ──
                    TimelineSectionView(events: vm.timeline)
                        .padding(.horizontal, AppSpacing.md)

                    // ── 5. Recent Messages ──
                    RecentMessagesSectionView(messages: vm.messages)
                        .padding(.horizontal, AppSpacing.md)

                    // Bottom padding for sticky bar
                    Spacer().frame(height: 80)
                }
            }

            // ── Sticky bottom bar ──
            bottomBar
        }
        .navigationTitle(lead.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareApp()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.textPrimary)
                }
            }
        }
        .onAppear {
            Task {
                await loanAppVM.fetchLoanProducts()
                await loanAppVM.fetchBranches()
                // Sync required docs from the product chosen at lead-creation time
                vm.syncRequiredDocuments(from: loanAppVM.requiredDocuments(for: lead.loanProductID))
            }
            loanAppVM.onLeadUpdated = { [weak vm] updatedLead in
                onLeadSave?(updatedLead)
                vm?.syncKYCDocuments(
                    aadhaarVerified: updatedLead.isAadhaarKycVerified,
                    panVerified: updatedLead.isPanKycVerified,
                    name: updatedLead.aadhaarVerifiedName,
                    dob: updatedLead.aadhaarVerifiedDOB
                )
            }
        }
        .sheet(isPresented: $vm.showEligibility) {
            EligibilityCheckView(vm: vm)
                .presentationDetents([.large])
        }
        .alert("Application Submitted!", isPresented: $vm.showSubmitSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("The application for \(lead.name) has been submitted for review.")
        }
        .alert("Submission Failed", isPresented: Binding(
            get: { loanAppVM.submissionError != nil },
            set: { if !$0 { loanAppVM.submissionError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loanAppVM.submissionError ?? "")
        }
    }

    // MARK: - 1. Identity Card
    private var identityCard: some View {
        VStack(spacing: 0) {
            // Top row: avatar + name + phone
            HStack(spacing: AppSpacing.md) {
                // Square avatar
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(lead.name.avatarColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Text(lead.initials)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(lead.name.avatarColor)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(lead.name)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color.textPrimary)
                    Text(lead.formattedPhone)
                        .font(AppFont.subhead())
                        .foregroundColor(Color.textSecondary)

                    // Loan type + amount chips
                    HStack(spacing: 8) {
                        loanTypeChip
                        amountChip
                    }
                }
                Spacer()
            }
            .padding(AppSpacing.md)

            Divider().padding(.horizontal, AppSpacing.md)

            // Commission row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Estimated Commission (0.25%)")
                        .font(AppFont.subhead())
                        .foregroundColor(Color.textSecondary)
                    Text("30-45 days after sanction")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                }
                Spacer()
                Text(lead.formattedCommission)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color.textPrimary)
            }
            .padding(AppSpacing.md)
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
    }

    private var loanTypeChip: some View {
        Text(lead.loanType.rawValue)
            .font(AppFont.captionMed())
            .foregroundColor(Color.brandBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.brandBlueSoft)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.brandBlue.opacity(0.25), lineWidth: 1))
    }

    private var amountChip: some View {
        Text(lead.formattedAmount)
            .font(AppFont.captionMed())
            .foregroundColor(Color.brandBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.brandBlueSoft)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.brandBlue.opacity(0.25), lineWidth: 1))
    }

    // MARK: - 2. Action Buttons
    private var actionButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            actionBtn(icon: "phone.fill",     label: "Call",             iconBg: Color.brandBlue.opacity(0.12),    iconFg: Color.brandBlue)       { call() }
            actionBtn(icon: "message.fill",   label: "WhatsApp",         iconBg: Color.brandBlue.opacity(0.12),    iconFg: Color.brandBlue)       { whatsapp() }
            actionBtn(icon: "paperplane.fill",label: "Request\nDocs",    iconBg: Color.brandBlue.opacity(0.12),    iconFg: Color.brandBlue)       { vm.showRequestDocsConfirm = true }
            actionBtn(icon: "checkmark.seal.fill", label: "Check\nEligibility", iconBg: Color.brandBlue.opacity(0.12), iconFg: Color.brandBlue)   { vm.showEligibility = true }
        }
        .fixedSize(horizontal: false, vertical: true)
        .alert("Docs Requested", isPresented: $vm.showRequestDocsConfirm) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Document request sent to \(lead.name) via SMS and WhatsApp.")
        }
    }

    private func actionBtn(
        icon: String,
        label: String,
        iconBg: Color,
        iconFg: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(iconFg)
                }
                Text(label)
                    .font(AppFont.caption())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 0) // Push content up slightly, keeping heights exact
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, AppSpacing.sm)
            .padding(.horizontal, 4)
            .background(Color.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.md)
                    .strokeBorder(Color.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticky Bottom Bar
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            if vm.canSubmit && !loanAppVM.branches.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("Select Branch")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)
                    
                    Picker("Branch", selection: $loanAppVM.selectedBranchID) {
                        ForEach(loanAppVM.branches) { branch in
                            Text("\(branch.name) (\(branch.city))")
                                .tag(Optional(branch.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(Color.textPrimary)
                    .padding(.horizontal, AppSpacing.sm)
                }
                .padding(.bottom, AppSpacing.xs)
            }
            
            Button {
                if vm.canSubmit {
                    // Use product ID set at lead-creation; fall back to picker selection
                    let productID = lead.loanProductID ?? loanAppVM.selectedProductID
                    guard let productID else {
                        loanAppVM.submissionError = "Please select a loan product first."
                        return
                    }
                    guard let branchID = loanAppVM.selectedBranchID else {
                        loanAppVM.submissionError = "Please select a branch first."
                        return
                    }
                    Task {
                        let success = await loanAppVM.submitApplication(
                            productID: productID,
                            branchID: branchID,
                            requestedAmount: "\(lead.loanAmount)",
                            tenureMonths: lead.loanType.defaultTenureMonths,
                            leadDocuments: vm.documents
                        )
                        if success {
                            vm.submitApplication()
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: vm.canSubmit ? "checkmark.circle.fill" : "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                    Text(vm.canSubmit
                         ? "Submit Application"
                         : "Complete \(vm.missingCount) Document\(vm.missingCount == 1 ? "" : "s") to Submit")
                        .font(AppFont.bodyMedium())
                }
                .foregroundColor(vm.canSubmit ? .white : Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    vm.canSubmit
                    ? Color.brandBlue
                    : Color.surfaceTertiary
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.md)
                        .strokeBorder(
                            vm.canSubmit ? Color.clear : Color.borderMedium,
                            lineWidth: 1
                        )
                )
                .overlay {
                    if loanAppVM.isSubmitting {
                        Color.black.opacity(0.2).clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                        ProgressView().tint(.white)
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .buttonStyle(.plain)
            .disabled(!vm.canSubmit)
            .animation(.easeInOut(duration: 0.2), value: vm.canSubmit)
        }
        .background(
            Color.surfacePrimary
                .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: -2)
        )
    }

    // MARK: - Helpers
    private func call() {
        guard let url = URL(string: "tel://\(lead.phone)") else { return }
        UIApplication.shared.open(url)
    }

    private func whatsapp() {
        let msg = "Hi \(lead.name), please share the required documents for your \(lead.loanType.rawValue) application."
        let encoded = msg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/91\(lead.phone)?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func shareApp() {
        let text = "Application for \(lead.name) — \(lead.loanType.rawValue) \(lead.formattedAmount)"
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}
