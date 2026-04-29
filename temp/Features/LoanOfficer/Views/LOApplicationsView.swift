//
//  LOApplicationsView.swift
//  lms_project
//
//  Applications tab for Loan Officer.
//  Features: collapsable sidebar, filter chips (default: Under Review),
//  financial details on top, documents with upload, internal remarks.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import PDFKit
import WebKit

// MARK: - Main View

struct LOApplicationsView: View {
    
    private enum LOChip: String, CaseIterable {
        case all = "All"
        case new = "New"
        case myReview = "My Review"
        case sentToManager = "Sent to Manager"
        case approved = "Approved"
        case rejected = "Rejected"
    }
    @State private var showFilterSheet = false
    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    // MARK: - Theme Helpers
        private var primary:  Color { Theme.Colors.adaptivePrimary(colorScheme) } // Blue
        private var surface:  Color { Theme.Colors.adaptiveSurface(colorScheme) }
        private var bg:       Color { Theme.Colors.adaptiveBackground(colorScheme) }
        private var border:   Color { Theme.Colors.adaptiveBorder(colorScheme) }
        private var secondary: Color { Color.secondary }
    
    @State private var showNewApplication = false
    @State private var sidebarCollapsed   = false
    
    @State private var showAddDocumentAlert = false
    @State private var newDocumentName = ""
    @State private var showSanctionLetterPicker = false
    @State private var sanctionLetterAppID: String? = nil
    @State private var selectedLOChip: LOChip = .all

    private let sidebarWidth: CGFloat = 320

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // ── Collapsable sidebar ──────────────────────────
                        if !sidebarCollapsed {
                            applicationListPanel
                                .frame(width: sidebarWidth)
                                .transition(.move(edge: .leading).combined(with: .opacity))

                            Divider()
                        }

                        // ── Detail panel ─────────────────────────────────
                        applicationDetailPanel(collapsed: sidebarCollapsed)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Sidebar toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            sidebarCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: sidebarCollapsed ? "sidebar.left" : "sidebar.left")
                            .symbolVariant(sidebarCollapsed ? .none : .fill)
                    }
                }
                // Replace the existing ToolbarItem for the "plus" button with this:
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        // 1. Existing Plus Button
                        Button {
                            showNewApplication = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        
                        // MARK: - Update this specific block in LOApplicationsView.swift

                        Menu {
                            Section("Sort Applications") {
                                Button {
                                    applicationsVM.updateSort(.newestFirst) // Wire this to Line 89
                                } label: {
                                    Label("Date (Newest First)", systemImage: "calendar")
                                }
                                
                                Button {
                                    applicationsVM.updateSort(.highestAmount) // Wire this to Line 93
                                } label: {
                                    Label("Loan Amount (High to Low)", systemImage: "indianrupeesign.circle")
                                }
                            }
                            
                            Section("Advanced Filters") {
                                Button {
                                    showFilterSheet = true
                                } label: {
                                    Label("Amount & Date Ranges...", systemImage: "slider.horizontal.3")
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                applicationsVM.resetFiltersToAll()
                applicationsVM.loadData(autoSelectFirst: true)
                selectedLOChip = .all
                if let app = applicationsVM.selectedApplication {
                    applicationsVM.loadBranchOfficers(branchName: app.branch)
                }
            }
            .alert("Action", isPresented: $applicationsVM.showActionAlert) {
                Button("OK") {}
            } message: {
                Text(applicationsVM.actionMessage ?? "")
            }
            .sheet(isPresented: $applicationsVM.showXMLUploadResult) { xmlResultSheet }
            .sheet(isPresented: $showNewApplication) {
                CreateApplicationSheet(applicationsVM: applicationsVM)
            }
            .sheet(isPresented: $showSanctionLetterPicker) {
                DocumentFilePicker { data, name, contentType in
                    if let appID = sanctionLetterAppID,
                       let app = applicationsVM.applications.first(where: { $0.id == appID }) {
                        applicationsVM.uploadSanctionLetter(
                            application: app,
                            data: data,
                            fileName: name,
                            contentType: contentType
                        )
                    }
                    showSanctionLetterPicker = false
                    sanctionLetterAppID = nil
                } onCancel: {
                    showSanctionLetterPicker = false
                    sanctionLetterAppID = nil
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                    FilterRangeSheet(applicationsVM: applicationsVM)
                }
        }
        .animation(.easeInOut(duration: 0.28), value: sidebarCollapsed)
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Sidebar: Application List
    // ────────────────────────────────────────────────────────────────

    private var applicationListPanel: some View {
        VStack(spacing: 0) {
            // List Header
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Applications")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                }
                Spacer()
                Text("\(filteredLOApplications.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search bar
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Theme.Colors.primary)
                    .font(.system(size: 14, weight: .bold))
                TextField("Search applications...", text: $applicationsVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .padding(.horizontal, 16)

            // Filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LOChip.allCases, id: \.self) { chip in
                        AppFilterChip(label: chip.rawValue, isSelected: selectedLOChip == chip) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedLOChip = chip
                                // Pass the selection to the ViewModel
                                switch chip {
                                case .all: applicationsVM.filterStatus = nil
                                case .new: applicationsVM.filterStatus = .pending
                                case .myReview: applicationsVM.filterStatus = .officerReview
                                case .sentToManager: applicationsVM.filterStatus = .managerReview
                                case .approved: applicationsVM.filterStatus = .approved
                                case .rejected: applicationsVM.filterStatus = .rejected
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 10)

            Divider()

            // List
            if filteredLOApplications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .thin))
                        .foregroundStyle(Theme.Colors.primary.opacity(0.3))
                    Text("No applications found")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(applicationsVM.filteredApplications) { app in
                            // Inside applicationListPanel ScrollView
                            ApplicationRow(
                                application: app,
                                isSelected: applicationsVM.selectedApplication?.id == app.id,
                                useMinimalStyle: true
                            )
                            .padding(.horizontal, 8)
                            .background(applicationsVM.selectedApplication?.id == app.id ? primary.opacity(0.08) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3)) {
                                    applicationsVM.selectApplication(app)
                                }
                            }
                            
                            Divider().padding(.leading, 72)
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }

    // MARK: - Advanced Filtering & Sorting Logic

    private var filteredLOApplications: [LoanApplication] {
        // 1. Start with the base list from VM
        var base = applicationsVM.applications
        
        // 2. Apply Status Filter (from Chips)
        switch selectedLOChip {
        case .all: break
        case .new:
            base = base.filter { $0.status == .pending }
        case .myReview:
            base = base.filter { $0.status == .officerReview }
        case .sentToManager:
            base = base.filter { $0.status == .managerReview || $0.status == .officerApproved }
        case .approved:
            base = base.filter { $0.status == .approved || $0.status == .managerApproved }
        case .rejected:
            base = base.filter { $0.status == .rejected || $0.status == .officerRejected || $0.status == .managerRejected }
        }
        
        // 3. Apply Search Query
        let query = applicationsVM.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            base = base.filter {
                $0.borrower.name.localizedCaseInsensitiveContains(query) ||
                $0.id.localizedCaseInsensitiveContains(query) ||
                $0.borrower.employer.localizedCaseInsensitiveContains(query)
            }
        }
        
        return base.sorted {
            if $0.slaStatus != $1.slaStatus {
                return $0.slaStatus == .overdue
            }
            // Optional: Add Risk Level as the tie-breaker before Date
            if $0.riskLevel != $1.riskLevel {
                return $0.riskLevel == .high
            }
            return $0.createdAt > $1.createdAt
        }
    }
    
    // MARK: - Consolidated Borrower Profile
        private func consolidatedBorrowerProfile(_ app: LoanApplication) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                sectionLabel("Borrower Profile & Risk Analysis", icon: "person.text.rectangle.fill")
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    modernFinTile("Full Name", app.borrower.name, icon: "person.fill")
                    modernFinTile("Email Address", app.borrower.email, icon: "envelope.fill")
                    modernFinTile("CIBIL Score", "\(app.financials.cibilScore)", icon: "bolt.fill", color: cibilColor(app.financials.cibilScore))
                    modernFinTile("DTI Ratio", app.financials.dtiRatio.percentFormatted, icon: "chart.pie.fill", color: dtiColor(app.financials.dtiRatio))
                    modernFinTile("Risk Assessment", app.riskLevel.displayName, icon: "shield.fill", color: app.riskLevel.adaptiveColor(colorScheme))
                    modernFinTile("Monthly Income", app.financials.monthlyIncome.currencyFormatted, icon: "arrow.up.right.circle")
                    modernFinTile("Annual Income", app.financials.annualIncome.currencyFormatted, icon: "calendar")
                    modernFinTile("EMI Amount", app.loan.emi.currencyFormatted, icon: "indianrupeesign.circle.fill")
                    modernFinTile("FOIR", String(format: "%.1f%%", app.financials.foir), icon: "percent")
                }
            }
            .padding(20)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
        }

        private func modernFinTile2(_ label: String, _ value: String, icon: String, color: Color = .primary) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(color.opacity(0.6))
                    Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary).tracking(0.8)
                }
                Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(color == Theme.Colors.success ? primary : color)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.08), lineWidth: 0.5))
        }
    
    // MARK: - Repayment History Section
        private func repaymentHistorySection(_ app: LoanApplication) -> some View {
            VStack(alignment: .leading, spacing: 18) {
                sectionLabel("Loan Repayment Ledger", icon: "clock.badge.checkmark.fill")
                
                HStack(spacing: 12) {
                    summaryMiniTile(label: "Outstanding", value: "₹18,45,200", color: primary)
                    summaryMiniTile(label: "Paid to Date", value: "₹6,54,800", color: .secondary)
                    summaryMiniTile(label: "Next EMI", value: "15 May", color: .orange)
                }
                
                VStack(spacing: 0) {
                    repaymentRow(period: "April 2026", date: "15 Apr", amount: app.loan.emi.currencyFormatted, status: "Paid", isPaid: true)
                    repaymentRow(period: "May 2026", date: "15 May", amount: app.loan.emi.currencyFormatted, status: "Upcoming", isPaid: false)
                }
                .background(Color(.tertiarySystemFill).opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(20)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(border, lineWidth: 1))
        }

        private func summaryMiniTile(label: String, value: String, color: Color) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased()).font(.system(size: 9, weight: .bold)).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(color.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }

        private func repaymentRow(period: String, date: String, amount: String, status: String, isPaid: Bool) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(period).font(.system(size: 13, weight: .semibold))
                    Text("Due: \(date)").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
                Spacer()
                Text(amount).font(.system(size: 13, weight: .bold, design: .rounded))
                Text(status).font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isPaid ? primary : .orange)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(isPaid ? primary.opacity(0.1) : Color.orange.opacity(0.1)).clipShape(Capsule())
            }
            .padding(12)
            .overlay(Divider().padding(.horizontal, 10), alignment: .bottom)
        }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Detail Panel
    // ────────────────────────────────────────────────────────────────

    private func applicationDetailPanel(collapsed: Bool) -> some View {
        Group {
            if let app = applicationsVM.selectedApplication {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        selectedApplicationHint(app)
                        // Header row
                        detailHeader(app)

                        if collapsed {
                            // Wide layout: financials + docs side by side
                            HStack(alignment: .top, spacing: 24) {
                                VStack(alignment: .leading, spacing: 24) {
                                    consolidatedBorrowerProfile(app)
                                    borrowerHistorySection(app)
                                    repaymentHistorySection(app)
                                    documentsSection(app)
                                    sanctionLetterSection(app)
                                }
                                .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 24) {
                                    internalRemarksSection(app)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            conversationSection(app)
                        } else {
                            // Normal stacked layout
                            consolidatedBorrowerProfile(app)
                            borrowerHistorySection(app)
                            repaymentHistorySection(app)
                            documentsSection(app)
                            sanctionLetterSection(app)
                            internalRemarksSection(app)
                            conversationSection(app)
                        }
                    }
                    .padding(20)
                }
                .background(Theme.Colors.adaptiveBackground(colorScheme))
                .safeAreaInset(edge: .bottom) {
                    LOActionPanel(
                        status: app.status,
                        onSendToManager: { applicationsVM.sendToManager(app) },
                        onReject: { applicationsVM.rejectApplication(app) },
                        onRequestDocs: { applicationsVM.requestDocuments(app) }
                    )
                    .background(Theme.Colors.adaptiveSurface(colorScheme))
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("Select an application")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Detail Header
    // ────────────────────────────────────────────────────────────────

    private func detailHeader(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            // Main Identity Row
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(primary.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Text(app.borrower.name.prefix(1))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(primary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(app.borrower.name)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        StatusBadge(status: app.status)
                        if app.isHighRisk {
                                HighRiskBadge()
                            }
                    }
                    
                    HStack(spacing: 6) {
                        Text(app.loan.amount.currencyFormatted)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(primary)
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(app.loan.type.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                // Top Right Metadata
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ID: \(app.id)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    metaLabel(app.borrower.phone, systemImage: "phone.fill")
                }
            }
            
            // Borrower Meta Grid
            HStack(spacing: 20) {
                metaLabel(app.borrower.employer, systemImage: "building.2.fill")
                metaLabel(app.borrower.employmentType, systemImage: "person.text.rectangle.fill")
            }
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            
            // Subtle Staff/SLA Footer
            HStack(spacing: 12) {
                // SLA Pill
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("Due \(app.slaDeadline.shortFormatted)")
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(primary.opacity(0.1))
                .foregroundStyle(primary)
                .clipShape(Capsule())
                
                Spacer()
                
                // Origin/Assignment labels
                Group {
                    Text("Officer: ").foregroundStyle(.tertiary) +
                    Text(applicationsVM.officerDisplayName(for: app.assignedTo)).foregroundStyle(.secondary)
                    
                    Text(" • ").foregroundStyle(.tertiary)
                    
                    Text("By: ").foregroundStyle(.tertiary) +
                    Text(applicationsVM.officerDisplayName(for: app.createdByUserID)).foregroundStyle(.secondary)
                }
                .font(.system(size: 11, weight: .medium))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(border, lineWidth: 1)
        )
    }

    private func selectedApplicationHint(_ app: LoanApplication) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(primary)
            Text("Reviewing: \(app.id)")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(border, lineWidth: 1)
        )
    }

    private func metaLabel(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 10))
                .foregroundStyle(primary.opacity(0.7))
            Text(text)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Financial Section
    // ────────────────────────────────────────────────────────────────

    private func financialSection(_ app: LoanApplication) -> some View {
            VStack(alignment: .leading, spacing: 20) {
                // Header with a subtle trailing info or refresh indicator
                HStack {
                    sectionLabel("Financial Overview", icon: "chart.bar.fill")
                    Spacer()
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(primary.opacity(0.5))
                }
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    modernFinTile("Monthly Income", app.financials.monthlyIncome.currencyFormatted, icon: "arrow.up.right.circle")
                    modernFinTile("Existing EMI", app.financials.existingEMI.currencyFormatted, icon: "arrow.down.left.circle")
                    modernFinTile("CIBIL Score", "\(app.financials.cibilScore)", icon: "gauge.medium", color: cibilColor(app.financials.cibilScore))
                    modernFinTile("DTI Ratio", app.financials.dtiRatio.percentFormatted, icon: "percent")
                    modernFinTile("Bank Balance", app.financials.bankBalance.currencyFormatted, icon: "building.columns")
                    modernFinTile("Annual Income", app.financials.annualIncome.currencyFormatted, icon: "calendar")
                }
            }
            .padding(20)
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: 24)) // Slightly larger radius for the container
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(border, lineWidth: 1)
            )
        }

        private func modernFinTile(_ label: String, _ value: String, icon: String, color: Color = .primary) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                // Icon and Label Row
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color.opacity(0.6))
                    
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .tracking(0.8)
                }
                
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color == Theme.Colors.success ? primary : color)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            // Subtle tile background
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.04)) // Extremely subtle tint based on the color of the metric
            )
            // Inner hair-line border for the tile
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.08), lineWidth: 0.5)
            )
        }

    private func cibilColor(_ s: Int)    -> Color { s >= 750 ? Theme.Colors.success : s >= 650 ? Theme.Colors.neutral : Theme.Colors.critical }
    private func dtiColor(_ r: Double)   -> Color { r <= 0.30 ? Theme.Colors.success : r <= 0.40 ? Theme.Colors.neutral : Theme.Colors.critical }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Borrower History Section
    // ────────────────────────────────────────────────────────────────

    private func borrowerHistorySection(_ app: LoanApplication) -> some View {
        let thisBank = sampleThisBankLoans(for: app)
        let otherBanks = sampleOtherBankLoans(for: app)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Borrower History", icon: "clock.arrow.circlepath")
                .description("Previous loans from this bank and other institutions.")

            // ── This Bank ──
            VStack(alignment: .leading, spacing: 8) {
                historySubHeader("This Bank", icon: "building.columns.fill", color: Theme.Colors.primary)
                if thisBank.isEmpty {
                    Text("No previous loans with this bank.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.leading, 4)
                } else {
                    ForEach(thisBank) { entry in
                        historyRow(entry)
                    }
                }
            }

            Divider()

            // ── Other Banks ──
            VStack(alignment: .leading, spacing: 8) {
                historySubHeader("Other Banks / NBFCs", icon: "building.2.fill", color: Color(hex: "#5E5CE6"))
                if otherBanks.isEmpty {
                    Text("No declared external loan history.")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .padding(.leading, 4)
                } else {
                    ForEach(otherBanks) { entry in
                        historyRow(entry)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.adaptiveSurface(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
        )
    }

    private func historySubHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }

    private func historyRow(_ entry: BorrowerLoanHistoryEntry) -> some View {
        HStack(spacing: 12) {
            // Left accent
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.statusColor)
                .frame(width: 4, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.loanType)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(entry.institution)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.amount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(entry.status)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(entry.statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(entry.statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(entry.statusColor.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(entry.statusColor.opacity(0.12), lineWidth: 1)
        )
    }

    // Sample borrower history data (replace with real API data when available)
    private func sampleThisBankLoans(for app: LoanApplication) -> [BorrowerLoanHistoryEntry] {
        let score = app.financials.cibilScore
        if score > 0 {
            return [
                BorrowerLoanHistoryEntry(loanType: "Personal Loan", institution: "Our Bank", amount: "₹1,50,000", status: "Closed", statusColor: Theme.Colors.success),
                BorrowerLoanHistoryEntry(loanType: "Vehicle Loan",  institution: "Our Bank", amount: "₹3,20,000", status: "Active",  statusColor: Theme.Colors.primary)
            ]
        }
        return []
    }

    private func sampleOtherBankLoans(for app: LoanApplication) -> [BorrowerLoanHistoryEntry] {
        let emi = app.financials.existingEMI
        if emi > 0 {
            return [
                BorrowerLoanHistoryEntry(loanType: "Home Loan",     institution: "HDFC Bank",  amount: "₹28,00,000", status: "Active",  statusColor: Theme.Colors.warning),
                BorrowerLoanHistoryEntry(loanType: "Credit Card",   institution: "ICICI Bank", amount: "₹50,000",    status: "Overdue", statusColor: Theme.Colors.critical)
            ]
        }
        return [
            BorrowerLoanHistoryEntry(loanType: "Education Loan", institution: "SBI",       amount: "₹4,00,000",  status: "Closed", statusColor: Theme.Colors.success)
        ]
    }



    // ────────────────────────────────────────────────────────────────
    // MARK: - Documents Section
    // ────────────────────────────────────────────────────────────────

    private func documentsSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Required Documents", icon: "doc.fill")
                .description("Upload and verify necessary documentation for loan eligibility.")
                .info { /* Info Action */ }

            ForEach(app.documents) { doc in
                DocumentUploadRow(
                    applicationID: app.id,
                    doc: doc,
                    uploadedFiles: applicationsVM.uploadedFiles[doc.id] ?? [],
                    onUpload: { file in
                        applicationsVM.recordUploadedFile(file, forDocumentId: doc.id)
                    },
                    onVerify: { approved, reason in
                        applicationsVM.verifyDocument(
                            documentId: doc.id,
                            applicationId: app.id,
                            approved: approved,
                            rejectionReason: reason
                        )
                    }
                )
            }
            
            Button {
                newDocumentName = ""
                showAddDocumentAlert = true
            } label: {
                Label("Add Other Document", systemImage: "plus.circle")
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(Theme.Colors.primary)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
        )
        .alert("Add Document", isPresented: $showAddDocumentAlert) {
            TextField("Document Name", text: $newDocumentName)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                if !newDocumentName.trimmingCharacters(in: .whitespaces).isEmpty {
                    applicationsVM.addOtherDocument(to: app, label: newDocumentName)
                }
            }
        } message: {
            Text("Enter a name for the new document.")
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Sanction Letter
    // ────────────────────────────────────────────────────────────────

    private func sanctionLetterSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sanction Letter", icon: "doc.badge.shield.fill")

            if let letter = app.sanctionLetter, let activeVersion = letter.activeVersion {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version v\(activeVersion.version)")
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(.primary)
                        Text("Generated: \(activeVersion.generatedAt.shortFormatted)")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(activeVersion.status.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
            } else {
                Text("No sanction letter is available yet.")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }

            if canUploadSanctionLetter(app) {
                Button {
                    sanctionLetterAppID = app.id
                    showSanctionLetterPicker = true
                } label: {
                    Label("Upload Sanction Letter (PDF/Image)", systemImage: "arrow.up.doc")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(Theme.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
        )
    }

    private func canUploadSanctionLetter(_ app: LoanApplication) -> Bool {
        app.status == .approved || app.status == .managerApproved
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Internal Remarks
    // ────────────────────────────────────────────────────────────────

    private func internalRemarksSection(_ app: LoanApplication) -> some View {
        InternalRemarksView(app: app, applicationsVM: applicationsVM)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .fill(Theme.Colors.adaptiveSurface(colorScheme)))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
            )
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Conversation Section
    // ────────────────────────────────────────────────────────────────

    private func conversationSection(_ app: LoanApplication) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Conversation", icon: "bubble.left.and.bubble.right")

            let messages = applicationsVM.messagesForApplication(app.id)
            VStack(spacing: 8) {
                ForEach(messages) { msg in
                    appMessageBubble(msg)
                }
            }

            HStack(spacing: 10) {
                TextField("Type a message...", text: $applicationsVM.chatText)
                    .font(Theme.Typography.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )

                Button {
                    applicationsVM.sendApplicationMessage(
                        applicationId: app.id,
                        senderName: "Amit Singh",
                        senderRole: "Loan Officer"
                    )
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.35)
                            : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(applicationsVM.chatText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg)
            .fill(Theme.Colors.adaptiveSurface(colorScheme)))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.primary.opacity(0.20), lineWidth: 1.5)
        )
        .onAppear { applicationsVM.loadApplicationMessages(for: app.id) }
    }

    private func appMessageBubble(_ msg: ApplicationMessage) -> some View {
        Group {
            if msg.type == .managerRemark {
                VStack(spacing: 3) {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkered").font(.system(size: 11))
                        Text("Manager · \(msg.senderName)").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.secondary)
                    Text(msg.text)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .bottom, spacing: 8) {
                    if msg.isFromCurrentUser { Spacer(minLength: 60) }
                    VStack(alignment: msg.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                        if !msg.isFromCurrentUser {
                            Text(msg.senderName).font(Theme.Typography.caption).foregroundStyle(.secondary)
                        }
                        Text(msg.text)
                            .font(Theme.Typography.subheadline)
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(msg.isFromCurrentUser ? Color(hex: "#E5E5EA") : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
                            )
                        Text(msg.timestamp.timeFormatted)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.tertiary)
                    }
                    if !msg.isFromCurrentUser { Spacer(minLength: 60) }
                }
            }
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - XML Result Sheet
    // ────────────────────────────────────────────────────────────────

    private var xmlResultSheet: some View {
        NavigationStack {
            if let result = applicationsVM.xmlParseResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Parsed Data").font(Theme.Typography.title)
                            infoRow("Account Holder", result.accountHolder)
                            infoRow("Bank",            result.bankName)
                            infoRow("Account",         result.accountNumber)
                            infoRow("Monthly Income",  result.monthlyIncome.currencyFormatted)
                            infoRow("Avg Balance",     result.averageBalance.currencyFormatted)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transactions").font(Theme.Typography.headline)
                            ForEach(result.transactions) { txn in
                                HStack {
                                    Image(systemName: txn.type == .credit ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                    VStack(alignment: .leading) {
                                        Text(txn.description).font(Theme.Typography.subheadline)
                                        Text(txn.date.shortFormatted).font(Theme.Typography.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text((txn.type == .credit ? "+" : "-") + txn.amount.currencyFormatted)
                                        .font(Theme.Typography.mono)
                                        .foregroundStyle(txn.type == .credit ? Theme.Colors.success : Theme.Colors.critical)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
                .navigationTitle("XML Result")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { applicationsVM.showXMLUploadResult = false }
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typography.subheadline).foregroundStyle(.primary)
        }
    }

    // ────────────────────────────────────────────────────────────────
    // MARK: - Shared helpers
    // ────────────────────────────────────────────────────────────────

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.primary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Document Upload Row
// ────────────────────────────────────────────────────────────────────

struct DocumentUploadRow: View {
    let applicationID: String
    let doc: LoanDocument
    let uploadedFiles: [UploadedDocFile]
    let onUpload: (UploadedDocFile) -> Void
    /// Callback wired to ApplicationsViewModel.verifyDocument(documentId:status:reason:)
    var onVerify: ((Bool, String?) -> Void)? = nil

    @EnvironmentObject var applicationsVM: ApplicationsViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPicker     = false
    @State private var showFilePicker = false
    @State private var showOptions    = false
    @State private var selectedPhotos : [PhotosPickerItem] = []
    @State private var previewFile    : UploadedDocFile?   = nil
    @State private var showRejectDialog = false
    @State private var rejectReason     = ""

    private var hasLinkedDocument: Bool {
        doc.mediaFileID != nil || doc.fileURL != nil
    }

    private var linkedPreviewFile: UploadedDocFile {
        let isImage = (doc.contentType ?? "").hasPrefix("image/")
        return UploadedDocFile(
            name: doc.fileName ?? "Linked Document",
            url: doc.fileURL,
            data: nil,
            contentType: doc.contentType,
            isImage: isImage,
            uploadedAt: doc.uploadedAt ?? Date()
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                Image(systemName: doc.type.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.label)
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.primary)
                    Text(doc.status.displayName)
                        .font(.system(size: 12))
                        .foregroundStyle(statusColor)
                }

                Spacer()

                // Verify / Reject actions (shown once files are uploaded)
                if (!uploadedFiles.isEmpty || hasLinkedDocument) && doc.status != .verified {
                    HStack(spacing: 6) {
                        if doc.status != .verified {
                            Button {
                                onVerify?(true, nil)
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 12))
                                    Text("Verify")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(Theme.Colors.success)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Theme.Colors.success.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        if doc.status != .rejected {
                            Button {
                                rejectReason = ""
                                showRejectDialog = true
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "xmark.circle")
                                        .font(.system(size: 12))
                                    Text("Reject")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(Theme.Colors.critical)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Theme.Colors.critical.opacity(0.1))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Upload button
                Button {
                    showOptions = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 14))
                        Text("Upload")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(Theme.Colors.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.primary.opacity(0.08))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .confirmationDialog("Upload Document", isPresented: $showOptions, titleVisibility: .visible) {
                    Button("Choose from Photos") { showPicker = true }
                    Button("Choose from Files")  { showFilePicker = true }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding(.vertical, 10)

            // Uploaded files list
            if !uploadedFiles.isEmpty {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 36)
                    ForEach(uploadedFiles) { file in
                        Button {
                            previewFile = file
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: file.isImage ? "photo" : "doc.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.Colors.primary)
                                    .frame(width: 20)
                                Text(file.name)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(file.uploadedAt.timeFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.leading, 36)
                            .padding(.trailing, 4)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        if file.id != uploadedFiles.last?.id {
                            Divider().padding(.leading, 56)
                        }
                    }
                }
            } else if hasLinkedDocument {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 36)
                    Button {
                        Task {
                            await openLinkedPreview()
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: (doc.contentType ?? "").hasPrefix("image/") ? "photo" : "doc.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.Colors.primary)
                                .frame(width: 20)
                            Text(doc.fileName ?? "Linked Document")
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            if let uploadedAt = doc.uploadedAt {
                                Text(uploadedAt.timeFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.leading, 36)
                        .padding(.trailing, 4)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
            )
        .sheet(isPresented: $showFilePicker) {
            DocumentFilePicker { data, name, contentType in
                let file = UploadedDocFile(
                    name: name,
                    url: nil,
                    data: data,
                    contentType: contentType,
                    isImage: contentType.hasPrefix("image/"),
                    uploadedAt: Date()
                )
                onUpload(file)
                showFilePicker = false
            } onCancel: {
                showFilePicker = false
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $selectedPhotos, maxSelectionCount: 1, matching: .images)
        .onChange(of: selectedPhotos) { _, items in
            guard let item = items.first else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let name = "Photo_\(Int(Date().timeIntervalSince1970)).jpg"
                    let file = UploadedDocFile(name: name, url: nil, data: data, contentType: "image/jpeg", isImage: true, uploadedAt: Date())
                    await MainActor.run { onUpload(file); selectedPhotos = [] }
                }
            }
        }
        // Document preview sheet
        .sheet(item: $previewFile) { file in
            DocumentPreviewSheet(file: file)
        }
        .alert("Reject Document", isPresented: $showRejectDialog) {
            TextField("Rejection reason", text: $rejectReason)
            Button("Cancel", role: .cancel) { }
            Button("Reject", role: .destructive) {
                onVerify?(false, rejectReason.isEmpty ? "Rejected by Loan Officer" : rejectReason)
            }
        } message: {
            Text("Provide a reason for rejecting \(doc.label).")
        }
    }

    private var statusColor: Color {
        switch doc.status {
        case .pending:   return Theme.Colors.neutral
        case .uploaded:  return Theme.Colors.primary
        case .verified:  return Theme.Colors.success
        case .rejected:  return Theme.Colors.critical
        }
    }

    @MainActor
    private func openLinkedPreview() async {
        if let local = applicationsVM.uploadedFiles[doc.id]?.last {
            previewFile = local
            return
        }

        if let refreshed = await applicationsVM.refreshDocumentPreview(documentID: doc.id, applicationID: applicationID) {
            let isImage = (refreshed.contentType ?? "").hasPrefix("image/")
            previewFile = UploadedDocFile(
                name: refreshed.fileName ?? refreshed.label,
                url: refreshed.fileURL,
                data: nil,
                contentType: refreshed.contentType,
                isImage: isImage,
                uploadedAt: refreshed.uploadedAt ?? Date()
            )
            return
        }

        previewFile = linkedPreviewFile
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Document Preview Sheet
// ────────────────────────────────────────────────────────────────────

struct DocumentPreviewSheet: View {
    let file: UploadedDocFile
    @Environment(\.dismiss) private var dismiss
    @State private var remoteDocumentData: Data? = nil
    @State private var remotePreviewError: String? = nil

    private var fileExtension: String {
        if let pathExtension = file.url?.pathExtension, !pathExtension.isEmpty {
            return pathExtension.lowercased()
        }
        return URL(fileURLWithPath: file.name).pathExtension.lowercased()
    }

    private var isImageFile: Bool {
        if file.isImage { return true }
        if let contentType = file.contentType?.lowercased(), contentType.hasPrefix("image/") {
            return true
        }
        return ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"].contains(fileExtension)
    }

    private var isPDFFile: Bool {
        if let contentType = file.contentType?.lowercased(), contentType.contains("pdf") {
            return true
        }
        return fileExtension == "pdf"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                previewContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)

                VStack(spacing: 4) {
                    Text(file.name)
                        .font(Theme.Typography.headline)
                        .multilineTextAlignment(.center)
                    Text("Uploaded \(file.uploadedAt.fullFormatted)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: file.id) {
                await loadRemotePreviewIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let data = file.data, isImageFile, let uiImage = UIImage(data: data) {
            ScrollView([.horizontal, .vertical]) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(Theme.Radius.md)
            }
        } else if let data = file.data, isPDFFile, let document = PDFDocument(data: data) {
            PDFDocumentView(document: document)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        } else if let url = file.url, isImageFile {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .success(let image):
                    ScrollView([.horizontal, .vertical]) {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .cornerRadius(Theme.Radius.md)
                    }
                case .failure:
                    previewUnavailable(message: "The uploaded image could not be loaded.")
                @unknown default:
                    previewUnavailable(message: "Preview is unavailable for this image.")
                }
            }
        } else if isPDFFile {
            if let data = file.data ?? remoteDocumentData, let document = PDFDocument(data: data) {
                PDFDocumentView(document: document)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
            } else if let remotePreviewError {
                previewUnavailable(message: remotePreviewError)
            } else if file.url != nil {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                previewUnavailable(message: "This PDF could not be loaded.")
            }
        } else if let url = file.url {
            RemoteDocumentWebView(url: url)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        } else {
            previewUnavailable(message: "Preview is unavailable for this file.")
        }
    }

    private func previewUnavailable(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: isImageFile ? "photo.fill" : "doc.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.Colors.primary.opacity(0.6))
            Text(message)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private func loadRemotePreviewIfNeeded() async {
        guard isPDFFile, file.data == nil, remoteDocumentData == nil, let url = file.url else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let document = PDFDocument(data: data)
            await MainActor.run {
                remoteDocumentData = data
                remotePreviewError = document == nil ? "The uploaded PDF could not be rendered." : nil
            }
        } catch {
            await MainActor.run {
                remotePreviewError = "Failed to load the document preview."
            }
        }
    }
}

private struct PDFDocumentView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        view.document = document
    }
}

private struct RemoteDocumentWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.load(URLRequest(url: url))
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Internal Remarks View
// ────────────────────────────────────────────────────────────────────

struct InternalRemarksView: View {
    let app: LoanApplication
    @ObservedObject var applicationsVM: ApplicationsViewModel
    var authorName: String = "Amit Singh"
    @Environment(\.colorScheme) private var colorScheme
    @State private var remarkText = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "lock.doc")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.primary)
                Text("Internal Remarks")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Spacer()
                Text("Visible to staff only")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            // Remarks list
            if app.internalRemarks.isEmpty {
                Text("No remarks yet")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(app.internalRemarks) { remark in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(remark.author)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.primary)
                                Spacer()
                                Text(remark.timestamp.relativeFormatted)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                            Text(remark.text)
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.primary)
                        }
                        .padding(10)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
                    }
                }
            }

            // Input
            HStack(spacing: 8) {
                TextField("Add internal remark...", text: $remarkText, axis: .vertical)
                    .font(Theme.Typography.subheadline)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 1)
            )
                    .focused($focused)

                Button {
                    applicationsVM.addInternalRemark(
                        applicationId: app.id,
                        text: remarkText,
                        author: authorName
                    )
                    remarkText = ""
                    focused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            remarkText.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color.secondary.opacity(0.35)
                            : Theme.Colors.primary
                        )
                }
                .buttonStyle(.plain)
                .disabled(remarkText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Filter Chip
// ────────────────────────────────────────────────────────────────────

struct AppFilterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.Colors.adaptivePrimary(colorScheme) : Color.clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Backwards-compatible alias so ManagerApprovalsView keeps compiling unchanged.
typealias FilterChip = AppFilterChip


// ────────────────────────────────────────────────────────────────────
// MARK: - Create Application Sheet
// ────────────────────────────────────────────────────────────────────

@available(iOS 18.0, *)
struct CreateApplicationSheet: View {
    @ObservedObject var applicationsVM: ApplicationsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Borrower Info
    @State private var borrowerName        = ""
    @State private var borrowerPhone       = ""
    @State private var borrowerEmail       = ""
    @State private var borrowerProfileID   = ""
    @State private var borrowerAddress     = ""

    // Borrower lookup (client-side from loaded apps)
    @State private var borrowerLookupHint  = ""
    @State private var borrowerLookupOK    = false

    // Loan
    @State private var selectedLoanProductID = ""
    @State private var loanAmountText        = ""
    @State private var tenureText            = ""
    @State private var monthlyIncomeText     = ""
    @State private var existingEMIText       = ""
    @State private var xmlParsed             = false

    // Submission state
    @State private var isSubmitting    = false
    @State private var submitError     = ""
    @State private var showSubmitError = false

    // Documents: driven by selected loan product
    struct DocEntry: Identifiable {
        let id = UUID()
        var requiredDocID: String       // product required_doc id (empty if manually added)
        var label: String               // display name
        var isMandatory: Bool
        var fileData: Data?
        var fileName: String?
        var contentType: String?
        var isUploading: Bool = false
        var uploadError: String?
    }
    @State private var docEntries: [DocEntry] = []
    @State private var showFilePicker      = false
    @State private var activeDocEntryID: UUID? = nil

    // MARK: Computed

    private var selectedProduct: LoanProduct? {
        applicationsVM.availableLoanProducts.first { $0.id == selectedLoanProductID }
    }

    private var canSubmit: Bool {
        !borrowerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !loanAmountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedLoanProductID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        borrowerSection
                        loanSection
                        financialSection
                        documentsSection
                    }
                    .padding(24)
                }
            }
            .navigationTitle("New Loan Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submit) {
                        Group {
                            if isSubmitting {
                                ProgressView().controlSize(.small).tint(.white)
                            } else {
                                Text("Create").fontWeight(.bold)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(canSubmit ? Theme.Colors.primary : Theme.Colors.neutral.opacity(0.2))
                        .foregroundStyle(canSubmit ? .white : .secondary)
                        .clipShape(Capsule())
                    }
                    .disabled(!canSubmit || isSubmitting)
                }
            }
        }
        .alert("Unable to Create Application", isPresented: $showSubmitError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(submitError)
        }
        .task {
            if applicationsVM.availableLoanProducts.isEmpty {
                await applicationsVM.loadAvailableLoanProducts()
            }
            if selectedLoanProductID.isEmpty {
                selectedLoanProductID = applicationsVM.availableLoanProducts.first?.id ?? ""
            }
        }
        .onChange(of: applicationsVM.availableLoanProducts) { _, products in
            if selectedLoanProductID.isEmpty {
                selectedLoanProductID = products.first?.id ?? ""
            }
        }
        .onChange(of: selectedLoanProductID) { _, _ in
            refreshDocEntries()
        }
        .onChange(of: borrowerEmail) { _, _ in runBorrowerLookup() }
        .onChange(of: borrowerPhone) { _, _ in runBorrowerLookup() }
        .sheet(isPresented: $showFilePicker) {
            if let docID = activeDocEntryID {
                DocumentFilePicker { data, name, ct in
                    attachFile(data: data, fileName: name, contentType: ct, toEntryID: docID)
                    showFilePicker = false
                } onCancel: {
                    showFilePicker = false
                }
            }
        }
    }

    // MARK: - Section Views

    private var borrowerSection: some View {
        formSection(title: "Borrower Information", icon: "person.fill") {
            VStack(spacing: 16) {
                customTextField("Full Name", text: $borrowerName, icon: "person")
                HStack(spacing: 16) {
                    customTextField("Phone", text: $borrowerPhone, icon: "phone").keyboardType(.phonePad)
                    customTextField("Email", text: $borrowerEmail, icon: "envelope").keyboardType(.emailAddress).autocapitalization(.none)
                }
                if !borrowerLookupHint.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: borrowerLookupOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(borrowerLookupOK ? Theme.Colors.success : Theme.Colors.warning)
                        Text(borrowerLookupHint)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .animation(.easeInOut, value: borrowerLookupHint)
                }
                customTextField("Residential Address", text: $borrowerAddress, icon: "mappin.and.ellipse", isMultiline: true)
            }
        }
    }

    private var loanSection: some View {
        formSection(title: "Loan Parameters", icon: "indianrupeesign.circle.fill") {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Loan Product").font(Theme.Typography.caption2).foregroundStyle(.secondary)
                        Picker("Loan Product", selection: $selectedLoanProductID) {
                            if applicationsVM.availableLoanProducts.isEmpty {
                                Text("Loading...").tag("")
                            } else {
                                ForEach(applicationsVM.availableLoanProducts) { p in
                                    Text(p.name).tag(p.id)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    customTextField("Tenure (months)", text: $tenureText, icon: "calendar").keyboardType(.numberPad)
                }
                customTextField("Requested Amount (₹)", text: $loanAmountText, icon: "banknote").keyboardType(.numberPad)
                if let product = selectedProduct {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(.secondary)
                        Text("Range: \(product.amountRangeDisplay)  •  Rate: \(product.rateDisplay)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var financialSection: some View {
        formSection(title: "Financial Profile", icon: "chart.bar.doc.horizontal.fill") {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    customTextField("Monthly Income (₹)", text: $monthlyIncomeText, icon: "arrow.up.right.circle").keyboardType(.numberPad)
                    customTextField("Existing EMI (₹)", text: $existingEMIText, icon: "arrow.down.left.circle").keyboardType(.numberPad)
                }
                Button {
                    withAnimation {
                        applicationsVM.simulateXMLUpload()
                        xmlParsed = true
                        if let r = applicationsVM.xmlParseResult {
                            monthlyIncomeText = String(Int(r.monthlyIncome))
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: xmlParsed ? "checkmark.seal.fill" : "doc.viewfinder.fill")
                        Text(xmlParsed ? "Bank Statement Parsed" : "Auto-fill via Bank Statement (XML)")
                            .fontWeight(.semibold)
                    }
                    .font(Theme.Typography.subheadline)
                    .foregroundStyle(xmlParsed ? .white : Theme.Colors.primary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(xmlParsed ? Theme.Colors.success : Theme.Colors.primary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var documentsSection: some View {
        formSection(title: "Required Documents", icon: "doc.on.doc.fill") {
            VStack(spacing: 12) {
                if docEntries.isEmpty {
                    Text("Select a loan product to see required documents")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(docEntries) { entry in
                        docRow(entry: entry)
                    }
                }
            }
        }
    }

    private func docRow(entry: DocEntry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.label).font(Theme.Typography.subheadline)
                    if entry.isMandatory {
                        Text("*").foregroundStyle(Theme.Colors.critical).font(.system(size: 12, weight: .bold))
                    }
                }
                if let err = entry.uploadError {
                    Text(err).font(.system(size: 10)).foregroundStyle(Theme.Colors.critical)
                } else if let name = entry.fileName {
                    Text(name).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if entry.isUploading {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    activeDocEntryID = entry.id
                    showFilePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: entry.fileData != nil ? "checkmark.circle.fill" : "arrow.up.circle")
                        Text(entry.fileData != nil ? "Attached" : "Attach")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(entry.fileData != nil ? Theme.Colors.success : Theme.Colors.primary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background((entry.fileData != nil ? Theme.Colors.success : Theme.Colors.primary).opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func refreshDocEntries() {
        guard let product = selectedProduct else { docEntries = []; return }
        withAnimation {
            docEntries = product.requiredDocuments.map { req in
                DocEntry(requiredDocID: req.id, label: req.label, isMandatory: req.isMandatory)
            }
            if docEntries.isEmpty {
                docEntries = [
                    DocEntry(requiredDocID: "", label: "Identity Document", isMandatory: true),
                    DocEntry(requiredDocID: "", label: "Address Proof",     isMandatory: true),
                    DocEntry(requiredDocID: "", label: "Income Proof",      isMandatory: false)
                ]
            }
        }
    }

    private func attachFile(data: Data, fileName: String, contentType: String, toEntryID: UUID) {
        guard let idx = docEntries.firstIndex(where: { $0.id == toEntryID }) else { return }
        docEntries[idx].fileData = data
        docEntries[idx].fileName = fileName
        docEntries[idx].contentType = contentType
        docEntries[idx].uploadError = nil
    }

    private func runBorrowerLookup() {
        let email = borrowerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let phone = borrowerPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty || !phone.isEmpty else {
            borrowerLookupHint = ""; borrowerLookupOK = false; return
        }
        
        borrowerLookupHint = "Searching..."
        Task {
            do {
                if let profileID = try await applicationsVM.resolveBorrowerProfileID(email: email, phone: phone) {
                    await MainActor.run {
                        borrowerLookupOK = true
                        borrowerLookupHint = "Borrower found! Profile verified."
                        self.borrowerProfileID = profileID
                    }
                } else {
                    await MainActor.run {
                        borrowerLookupOK = false
                        borrowerLookupHint = "No matching borrower found in the system. Please ensure they have signed up."
                    }
                }
            } catch {
                await MainActor.run {
                    borrowerLookupOK = false
                    borrowerLookupHint = "Error searching for borrower: \(error.localizedDescription)"
                }
            }
        }
    }

    private func submit() {
        let amount = Double(loanAmountText) ?? 0
        let tenure = Int(tenureText) ?? 12
        let income = Double(monthlyIncomeText) ?? 0
        let emi    = Double(existingEMIText) ?? 0
        guard let selectedProduct else {
            submitError = "Please select a valid loan product."; showSubmitError = true; return
        }
        isSubmitting = true
        Task {
            do {
                let appID = try await applicationsVM.createBackendApplication(
                    borrowerProfileID: borrowerProfileID,
                    borrowerName: borrowerName,
                    borrowerPhone: borrowerPhone,
                    borrowerEmail: borrowerEmail,
                    borrowerAddress: borrowerAddress,
                    selectedLoanProduct: selectedProduct,
                    requestedAmount: amount,
                    tenureMonths: tenure,
                    monthlyIncome: income,
                    existingEMI: emi,
                    documents: []
                )
                await uploadDocuments(applicationID: appID)
                await MainActor.run { isSubmitting = false; dismiss() }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    submitError = (error as? LocalizedError)?.errorDescription ?? "Could not create application."
                    showSubmitError = true
                }
            }
        }
    }

    @MainActor
    private func uploadDocuments(applicationID: String) async {
        guard #available(iOS 18.0, *) else { return }
        for i in docEntries.indices {
            guard let data = docEntries[i].fileData,
                  let fileName = docEntries[i].fileName,
                  let contentType = docEntries[i].contentType else { continue }
            docEntries[i].isUploading = true
            do {
                let uploadedMedia = try await MediaAPI().uploadFile(data: data, fileName: fileName, contentType: contentType)
                applicationsVM.cacheMediaPreview(uploadedMedia)
                _ = try await LoanAPI().addApplicationDocument(
                    applicationID: applicationID,
                    borrowerProfileID: borrowerProfileID,
                    requiredDocID: docEntries[i].requiredDocID,
                    mediaFileID: uploadedMedia.mediaID
                )
                docEntries[i].isUploading = false
            } catch {
                docEntries[i].isUploading = false
                docEntries[i].uploadError = "Upload failed"
            }
        }
    }

    // MARK: - Form Components

    private func formSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Theme.Colors.primary)
                Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(.secondary)
            }
            content()
                .padding(16)
                .background(Theme.Colors.adaptiveSurface(colorScheme))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func customTextField(_ label: String, text: Binding<String>, icon: String, isMultiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Theme.Typography.caption2).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.primary.opacity(0.7)).frame(width: 16)
                if isMultiline {
                    TextField(label, text: text, axis: .vertical).lineLimit(2...4)
                } else {
                    TextField(label, text: text)
                }
            }
            .font(Theme.Typography.subheadline).padding(12)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Document File Picker (UIDocumentPickerViewController wrapper)

struct DocumentFilePicker: UIViewControllerRepresentable {
    var onPick: (Data, String, String) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.jpeg, .png, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (Data, String, String) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (Data, String, String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick; self.onCancel = onCancel
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { onCancel(); return }
            guard url.startAccessingSecurityScopedResource() else { onCancel(); return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { onCancel(); return }
            let ext = url.pathExtension.lowercased()
            let contentType: String
            switch ext {
            case "pdf": contentType = "application/pdf"
            case "jpg", "jpeg": contentType = "image/jpeg"
            default: contentType = "image/png"
            }
            onPick(data, url.lastPathComponent, contentType)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }
    }
}

// ────────────────────────────────────────────────────────────────────
// MARK: - Borrower Loan History Entry Model
// ────────────────────────────────────────────────────────────────────

struct BorrowerLoanHistoryEntry: Identifiable {
    let id = UUID()
    let loanType: String
    let institution: String
    let amount: String
    let status: String
    let statusColor: Color
}
