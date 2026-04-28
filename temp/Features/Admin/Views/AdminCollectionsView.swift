//
//  AdminCollectionsView.swift
//  lms_project
//
//  Admin Tab 6 — Collections
//  NEW FILE: Does not modify any existing views.
//

import SwiftUI

// MARK: - Collections View

struct AdminCollectionsView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var dpdBucket: DPDBucket = .thirty
    @State private var showSettlementSheet: CollectionCase? = nil

    // MARK: - DPD Buckets

    enum DPDBucket: String, CaseIterable {
        case thirty = "30 DPD"
        case sixty  = "60 DPD"
        case ninety = "90+ DPD"

        var color: Color {
            switch self {
            case .thirty: return Theme.Colors.warning
            case .sixty:  return Color(hex: "E8720C")
            case .ninety: return Theme.Colors.critical
            }
        }

        var description: String {
            switch self {
            case .thirty: return "30 days past due — Early intervention"
            case .sixty:  return "60 days past due — Escalation required"
            case .ninety: return "90+ days past due — Legal / NPA risk"
            }
        }
    }

    // MARK: - Dummy Data

    private let cases30: [CollectionCase] = [
        CollectionCase(id: "COL-001", borrower: "Vivek Tiwari",    loanType: "Personal Loan", outstanding: "₹2.4L",  emi: "₹8,500",  agent: "Ravi Kumar",    status: .contacted),
        CollectionCase(id: "COL-002", borrower: "Sunita Rao",      loanType: "Vehicle Loan",  outstanding: "₹3.8L",  emi: "₹12,200", agent: "Priya Sharma",  status: .pendingPTP),
        CollectionCase(id: "COL-003", borrower: "Arjun Kulkarni",  loanType: "Home Loan",     outstanding: "₹18.6L", emi: "₹24,500", agent: "Unassigned",    status: .unassigned),
    ]

    private let cases60: [CollectionCase] = [
        CollectionCase(id: "COL-004", borrower: "Deepa Nambiar",   loanType: "Business Loan", outstanding: "₹7.2L",  emi: "₹18,000", agent: "Suresh Nair",   status: .escalated),
        CollectionCase(id: "COL-005", borrower: "Manoj Patel",     loanType: "Personal Loan", outstanding: "₹1.9L",  emi: "₹6,800",  agent: "Ravi Kumar",    status: .partialPayment),
    ]

    private let cases90: [CollectionCase] = [
        CollectionCase(id: "COL-006", borrower: "Girish Mehta",    loanType: "Home Loan",     outstanding: "₹34.5L", emi: "₹42,000", agent: "Legal Team",    status: .legal),
        CollectionCase(id: "COL-007", borrower: "Rekha Joshi",     loanType: "Business Loan", outstanding: "₹11.2L", emi: "₹22,500", agent: "Vikram Seth",   status: .settled),
        CollectionCase(id: "COL-008", borrower: "Farhan Siddiqui", loanType: "Vehicle Loan",  outstanding: "₹5.6L",  emi: "₹14,000", agent: "Unassigned",    status: .unassigned),
    ]

    private var activeCases: [CollectionCase] {
        switch dpdBucket {
        case .thirty: return cases30
        case .sixty:  return cases60
        case .ninety: return cases90
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    dpdSegmentControl
                    ScrollView {
                        VStack(spacing: Theme.Spacing.lg) {
                            bucketSummaryCard
                            caseListSection
                            recoveryTrackerSection
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.lg)
                    }
                }
            }
            .navigationTitle("Collections")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .sheet(item: $showSettlementSheet) { ccase in
                AgentAssignmentSheet(collectionCase: ccase)
            }
            .animation(.easeInOut(duration: 0.2), value: dpdBucket)
        }
    }

    // MARK: - DPD Segmented Control

    private var dpdSegmentControl: some View {
        Picker("DPD Bucket", selection: $dpdBucket) {
            ForEach(DPDBucket.allCases, id: \.self) { bucket in
                Text(bucket.rawValue).tag(bucket)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }

    // MARK: - Bucket Summary Card

    private var bucketSummaryCard: some View {
        HStack(spacing: Theme.Spacing.lg) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(dpdBucket.rawValue)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(dpdBucket.color)
                Text(dpdBucket.description)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Text("\(activeCases.count)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(dpdBucket.color)
                Text("cases")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(dpdBucket.color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(dpdBucket.color.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
    }

    // MARK: - Case List

    private var caseListSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Borrower Cases", icon: "person.crop.rectangle.stack")

            if activeCases.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(activeCases) { ccase in
                        CollectionCaseRow(
                            ccase: ccase,
                            bucketColor: dpdBucket.color,
                            colorScheme: colorScheme,
                            onAssign: { showSettlementSheet = ccase }
                        )
                        if ccase.id != activeCases.last?.id {
                            Divider().padding(.leading, Theme.Spacing.md)
                        }
                    }
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(Theme.Colors.success)
            Text("No cases in this bucket")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.xxl)
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Recovery Tracker

    private var recoveryTrackerSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Recovery Summary", icon: "arrow.uturn.down.circle")

            VStack(spacing: 0) {
                recoveryRow(label: "Contacted",      count: 4, color: Theme.Colors.primary)
                Divider().padding(.leading, Theme.Spacing.md)
                recoveryRow(label: "PTP Received",   count: 3, color: Theme.Colors.success)
                Divider().padding(.leading, Theme.Spacing.md)
                recoveryRow(label: "Partial Payment",count: 2, color: Theme.Colors.warning)
                Divider().padding(.leading, Theme.Spacing.md)
                recoveryRow(label: "Settled",        count: 1, color: Theme.Colors.success)
                Divider().padding(.leading, Theme.Spacing.md)
                recoveryRow(label: "Legal Action",   count: 1, color: Theme.Colors.critical)
            }
            .cardStyle(colorScheme: colorScheme)
        }
    }

    private func recoveryRow(label: String, count: Int, color: Color) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Text("\(count)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 13)
    }
}

// MARK: - Collection Case Row

private struct CollectionCaseRow: View {
    let ccase:       CollectionCase
    let bucketColor: Color
    let colorScheme: ColorScheme
    let onAssign:    () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Status indicator
            Circle()
                .fill(ccase.status.color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(ccase.borrower)
                        .font(Theme.Typography.headline)
                    Spacer()
                    GenericBadge(text: ccase.status.displayName, color: ccase.status.color)
                }
                Text("\(ccase.id) · \(ccase.loanType)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Label(ccase.outstanding + " outstanding", systemImage: "indianrupeesign.circle")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if ccase.agent == "Unassigned" {
                        Button("Assign Agent") { onAssign() }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(bucketColor)
                            .buttonStyle(.plain)
                    } else {
                        Label(ccase.agent, systemImage: "person.fill")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
    }
}

// MARK: - Agent Assignment Sheet

private struct AgentAssignmentSheet: View {
    let collectionCase: CollectionCase
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAgent = 0
    @State private var showNotImplementedAlert = false
    private let agents = ["Ravi Kumar", "Priya Sharma", "Suresh Nair", "Vikram Seth", "Ananya Bose"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Case Details") {
                    LabeledContent("Case ID",    value: collectionCase.id)
                    LabeledContent("Borrower",   value: collectionCase.borrower)
                    LabeledContent("Outstanding",value: collectionCase.outstanding)
                    LabeledContent("EMI",        value: collectionCase.emi)
                }
                Section("Assign Recovery Agent") {
                    Picker("Agent", selection: $selectedAgent) {
                        ForEach(agents.indices, id: \.self) { i in
                            Text(agents[i]).tag(i)
                        }
                    }
                }
                Section {
                    Label("Collection agent assignment is not yet implemented in the backend. No gRPC endpoint exists for this action in the current loan.proto service definition.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.Colors.warning)
                }
            }
            .navigationTitle("Assign Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Assign") {
                        showNotImplementedAlert = true
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Not Implemented", isPresented: $showNotImplementedAlert) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("Collection agent assignment requires a backend endpoint that is not yet available. This will be connected once the backend implements AssignCollectionAgent in the loan service.")
            }
        }
    }
}

// MARK: - Data Models

struct CollectionCase: Identifiable {
    let id:          String
    let borrower:    String
    let loanType:    String
    let outstanding: String
    let emi:         String
    let agent:       String
    let status:      CollectionStatus
}

enum CollectionStatus: String {
    case unassigned    = "Unassigned"
    case contacted     = "Contacted"
    case pendingPTP    = "PTP Pending"
    case partialPayment = "Partial Pay"
    case escalated     = "Escalated"
    case settled       = "Settled"
    case legal         = "Legal"

    var displayName: String { rawValue }

    var color: Color {
        switch self {
        case .unassigned:     return Theme.Colors.neutral
        case .contacted:      return Theme.Colors.primary
        case .pendingPTP:     return Theme.Colors.warning
        case .partialPayment: return Color(hex: "E8720C")
        case .escalated:      return Theme.Colors.critical
        case .settled:        return Theme.Colors.success
        case .legal:          return Color(hex: "8B0000")
        }
    }
}
