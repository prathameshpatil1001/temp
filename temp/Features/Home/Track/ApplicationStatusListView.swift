import SwiftUI

@available(iOS 18.0, *)
struct ApplicationStatusListView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = TrackViewModel()

    // Section collapse state
    @State private var activeExpanded    = true
    @State private var progressExpanded  = true
    @State private var pastExpanded      = false

    // Show more state
    @State private var activeShowAll     = false
    @State private var progressShowAll   = false
    @State private var pastShowAll       = false

    private let rowLimit = 5

    private var inProgressApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter {
            !pastStatuses.contains($0.status) && $0.status != .draft && $0.status != .disbursed
        }
    }

    private var disbursedApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter { $0.status == .disbursed }
    }

    private var pastApplications: [BorrowerLoanApplication] {
        viewModel.applications.filter { pastStatuses.contains($0.status) }
    }

    private let pastStatuses: Set<LoanApplicationStatus> = [.rejected, .cancelled, .officerRejected, .managerRejected]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection

                if viewModel.isLoading && viewModel.applications.isEmpty {
                    ProgressView().padding(.top, 20)
                } else if let error = viewModel.errorMessage, viewModel.applications.isEmpty {
                    errorSection(error)
                } else {
                    if !disbursedApplications.isEmpty {
                        CollapsibleSection(
                            title: "Active Loans",
                            count: disbursedApplications.count,
                            accentColor: DS.success,
                            isExpanded: $activeExpanded,
                            showAll: $activeShowAll,
                            rowLimit: rowLimit
                        ) {
                            ForEach(visibleItems(disbursedApplications, showAll: activeShowAll)) { app in
                                ApplicationRow(application: app, accent: DS.success) {
                                    router.push(.activeLoanDetails(app))
                                }
                            }
                        }
                    }

                    if !inProgressApplications.isEmpty {
                        CollapsibleSection(
                            title: "In Progress",
                            count: inProgressApplications.count,
                            accentColor: DS.primary,
                            isExpanded: $progressExpanded,
                            showAll: $progressShowAll,
                            rowLimit: rowLimit
                        ) {
                            ForEach(visibleItems(inProgressApplications, showAll: progressShowAll)) { app in
                                ApplicationRow(application: app, accent: DS.primary) {
                                    router.push(.detailedTracking(app))
                                }
                            }
                        }
                    }

                    if !pastApplications.isEmpty {
                        CollapsibleSection(
                            title: "Rejected / Cancelled",
                            count: pastApplications.count,
                            accentColor: DS.danger,
                            isExpanded: $pastExpanded,
                            showAll: $pastShowAll,
                            rowLimit: rowLimit
                        ) {
                            ForEach(visibleItems(pastApplications, showAll: pastShowAll)) { app in
                                ApplicationRow(application: app, accent: DS.danger) {
                                    if app.status == .rejected || app.status == .officerRejected || app.status == .managerRejected {
                                        router.push(.rejectionReason(app))
                                    } else {
                                        router.push(.detailedTracking(app))
                                    }
                                }
                            }
                        }
                    }

                    if viewModel.applications.isEmpty {
                        emptySection
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(DS.surface.ignoresSafeArea())
        .task { viewModel.fetchApplications() }
    }

    // MARK: - Helper
    private func visibleItems(_ items: [BorrowerLoanApplication], showAll: Bool) -> [BorrowerLoanApplication] {
        showAll ? items : Array(items.prefix(rowLimit))
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Track")
                .font(AppFonts.rounded(28, weight: .bold))
                .foregroundColor(DS.textPrimary)
            Text("Track and manage your live loan requests.")
                .font(AppFonts.rounded(14))
                .foregroundColor(DS.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    // MARK: - Empty / Error
    private var emptySection: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30))
                .foregroundColor(DS.textSecondary)
            Text("No applications yet")
                .font(AppFonts.rounded(16, weight: .semibold))
                .foregroundColor(DS.textPrimary)
            Text("Create a loan application from Discover and it will appear here.")
                .font(AppFonts.rounded(13))
                .foregroundColor(DS.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }

    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(AppFonts.rounded(13))
                .foregroundColor(DS.danger)
                .multilineTextAlignment(.center)
            Button("Retry") { viewModel.fetchApplications() }
                .font(AppFonts.rounded(14, weight: .semibold))
                .foregroundColor(DS.primary)
        }
        .padding(24)
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Collapsible Section
private struct CollapsibleSection<Content: View>: View {
    let title: String
    let count: Int
    let accentColor: Color
    @Binding var isExpanded: Bool
    @Binding var showAll: Bool
    let rowLimit: Int
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 8, height: 8)

                    Text(title)
                        .font(AppFonts.rounded(15, weight: .semibold))
                        .foregroundColor(DS.textPrimary)

                    Text("\(count)")
                        .font(AppFonts.rounded(11, weight: .bold))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DS.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 10) {
                    content

                    // Show more / less button
                    if count > rowLimit {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showAll.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(showAll ? "Show less" : "Show \(count - rowLimit) more")
                                    .font(AppFonts.rounded(13, weight: .semibold))
                                Image(systemName: showAll ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(accentColor.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(DS.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: DS.textPrimary.opacity(0.05), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 20)
    }
}

// MARK: - Application Row
private struct ApplicationRow: View {
    let application: BorrowerLoanApplication
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon(for: application.status))
                        .foregroundColor(accent)
                        .font(.system(size: 16, weight: .medium))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(application.loanProductName)
                        .font(AppFonts.rounded(14, weight: .semibold))
                        .foregroundColor(DS.textPrimary)
                    Text("App ID: \(application.referenceNumber)")
                        .font(AppFonts.rounded(11))
                        .foregroundColor(DS.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(BorrowerSanctionLetterSupport.statusTitle(for: application))
                        .font(AppFonts.rounded(11, weight: .bold))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accent.opacity(0.12))
                        .clipShape(Capsule())

                    Text(formatCurrency(application.requestedAmount))
                        .font(AppFonts.rounded(11))
                        .foregroundColor(DS.textSecondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DS.border)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        // Subtle press effect
        .background(DS.card)
        // Divider between rows (handled by VStack spacing instead)
    }

    private func icon(for status: LoanApplicationStatus) -> String {
        switch status {
        case .draft:             return "doc.text"
        case .disbursed:         return "banknote"
        case .rejected,
             .officerRejected,
             .managerRejected,
             .cancelled:         return "xmark.circle"
        default:                 return "clock.fill"
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}
