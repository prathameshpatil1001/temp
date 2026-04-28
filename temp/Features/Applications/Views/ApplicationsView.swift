import SwiftUI

struct ApplicationsView: View {
    @StateObject private var viewModel = ApplicationsViewModel()

    // Maps ApplicationStatus → display title for filter chips
    private let filterStatuses: [(label: String, status: ApplicationStatus?)] = [
        ("All", nil),
        ("Under Review", .underReview),
        ("Approved", .approved),
        ("Disbursed", .disbursed),
        ("Submitted", .submitted),
        ("Rejected", .rejected),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                VStack(spacing: 0) {
                    applicationsHero
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    VStack(spacing: 0) {
                        SearchBarView(text: $viewModel.searchText)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                        filterChipHeader
                    }
                    .padding(.bottom, AppSpacing.xs)
                    .background(Color.clear)

                    ScrollView {
                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.filteredApplications.isEmpty {
                            emptyView
                        } else {
                            VStack(spacing: AppSpacing.md) {
                                ApplicationStatsBar(stats: viewModel.stats)
                                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                                            .stroke(Color.borderLight, lineWidth: 1)
                                    )
                                    .cardShadow()
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.top, AppSpacing.sm)

                                applicationList
                            }
                        }
                    }
                }
                .padding(.top, -8)
            }
            .navigationTitle("Applications")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: LoanApplication.self) { app in
                ApplicationDetailView(application: app)
            }
            .refreshable {
                viewModel.loadApplications()
            }
        }
    }

    private var applicationsHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Application Pipeline", subtitle: "Track every converted file with the same transparency and confidence as the borrower experience.")
                HStack(spacing: AppSpacing.sm) {
                    statTile(title: "Total", value: "\(viewModel.stats.total)", color: Color.textPrimary)
                    statTile(title: "Under Review", value: "\(viewModel.stats.underReview)", color: Color.statusPending)
                    statTile(title: "Approved", value: "\(viewModel.stats.approved)", color: Color.statusApproved)
                }
            }
        }
    }

    private func statTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.title2())
                .foregroundColor(color)
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.brandBlueSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    // MARK: - FILTER CHIP HEADER WITH CHEVRONS
    private var filterChipHeader: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeo in
                HStack(spacing: 0) {
                    if viewModel.canScrollLeft {
                        Button {
                            if let first = filterStatuses.first {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first.label, anchor: .leading) }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.textTertiary)
                                .padding(.leading, AppSpacing.md)
                                .padding(.trailing, AppSpacing.xs)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.xs) {
                            ForEach(filterStatuses, id: \.label) { item in
                                chipView(for: item)
                                    .id(item.label)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetTracker.self, value: geo.frame(in: .named("appsScroll")).minX)
                                    .onAppear { viewModel.contentWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { _ in viewModel.contentWidth = geo.size.width }
                            }
                        )
                    }
                    .coordinateSpace(name: "appsScroll")
                    .onPreferenceChange(ScrollOffsetTracker.self) { value in viewModel.scrollOffset = value }

                    if viewModel.canScrollRight {
                        Button {
                            if let last = filterStatuses.last {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.label, anchor: .trailing) }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.textTertiary)
                                .padding(.trailing, AppSpacing.md)
                                .padding(.leading, AppSpacing.xs)
                        }
                    }
                }
                .onAppear { viewModel.viewWidth = outerGeo.size.width }
                .onChange(of: outerGeo.size.width) { _ in viewModel.viewWidth = outerGeo.size.width }
            }
            .frame(height: 44)
        }
    }

    // MARK: - CHIP VIEW (NO SHRINK, INSTANT RESPONSE)
    private func chipView(for item: (label: String, status: ApplicationStatus?)) -> some View {
        let isSelected = viewModel.selectedStatus == item.status

        return Button {
            viewModel.selectStatus(item.status)
        } label: {
            HStack(spacing: 5) {
                Text(item.label)
                    .font(AppFont.subheadMed())

                let count = item.status == nil
                    ? viewModel.stats.total
                    : countFor(item.status!)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : Color.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.2) : Color.surfaceTertiary)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? .white : Color.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.brandBlue : Color.surfacePrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.clear : Color.borderLight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func countFor(_ status: ApplicationStatus) -> Int {
        switch status {
        case .underReview: return viewModel.stats.underReview
        case .approved:    return viewModel.stats.approved
        case .disbursed:   return viewModel.stats.disbursed
        case .submitted:   return viewModel.applications.filter { $0.status == .submitted }.count
        case .rejected:    return viewModel.applications.filter { $0.status == .rejected }.count
        }
    }

    // MARK: - Application List
    private var applicationList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(viewModel.filteredApplications.enumerated()), id: \.element.id) { index, app in
                NavigationLink(value: app) {
                    ApplicationRowView(application: app)
                }
                .buttonStyle(.plain)
                if index < viewModel.filteredApplications.count - 1 {
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.md)
                .strokeBorder(Color.borderLight, lineWidth: 1)
        )
        .cardShadow()
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(Color.brandBlue)
            Text("Loading applications…")
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
        }
    }

    // MARK: - Empty
    private var emptyView: some View {
        VStack(spacing: AppSpacing.lg) {
            Spacer()
            ZStack {
                Circle().fill(Color.surfaceTertiary).frame(width: 72, height: 72)
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color.textTertiary)
            }
            VStack(spacing: AppSpacing.xs) {
                Text(viewModel.selectedStatus != nil
                     ? "No \(viewModel.selectedStatus!.rawValue) applications"
                     : "No applications yet")
                    .font(AppFont.headline())
                    .foregroundColor(Color.textPrimary)
                Text("Applications converted from leads will appear here.")
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xxl)
            }
            Spacer()
        }
    }
}

// MARK: - Detail Placeholder (expand in next sprint)
struct ApplicationDetailPlaceholder: View {
    let application: LoanApplication
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    // Header card
                    VStack(spacing: AppSpacing.sm) {
                        AvatarView(
                            initials: application.initials,
                            color: application.name.avatarColor,
                            size: 64
                        )
                        Text(application.name)
                            .font(AppFont.title2())
                            .foregroundColor(Color.textPrimary)
                        ApplicationStatusBadge(status: application.status)
                        Text("\(application.loanType.rawValue)  ·  \(application.formattedAmount)")
                            .font(AppFont.body())
                            .foregroundColor(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.xl)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Pipeline
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Pipeline Status")
                            .font(AppFont.headline())
                            .foregroundColor(Color.textPrimary)

                        PipelineProgressBar(application: application)
                            .padding(.vertical, AppSpacing.xs)

                        HStack {
                            ForEach(LoanApplication.pipeline) { stage in
                                Text(stage.label)
                                    .font(AppFont.caption())
                                    .foregroundColor(Color.textTertiary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    // Info rows
                    VStack(spacing: 0) {
                        detailRow(label: "Bank", value: application.bankName ?? "—")
                        Divider().padding(.leading, AppSpacing.md)
                        detailRow(label: "RM Assigned", value: application.rmName ?? "—")
                        Divider().padding(.leading, AppSpacing.md)
                        detailRow(label: "Status Note", value: application.statusLabel)
                        if let sanctioned = application.sanctionedAmount {
                            Divider().padding(.leading, AppSpacing.md)
                            detailRow(label: "Sanctioned", value: formatAmount(sanctioned))
                        }
                        if let disbursed = application.disbursedAmount {
                            Divider().padding(.leading, AppSpacing.md)
                            detailRow(label: "Disbursed", value: formatAmount(disbursed))
                        }
                    }
                    .background(Color.surfacePrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))

                    Text("Full detail view — next sprint")
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                }
                .padding(AppSpacing.md)
            }
            .background(Color.surfaceSecondary.ignoresSafeArea())
            .navigationTitle("Application Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
            Text(value)
                .font(AppFont.subheadMed())
                .foregroundColor(Color.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
    }

    private func formatAmount(_ v: Double) -> String {
        let lakhs = v / 100_000
        return lakhs >= 100
            ? "₹\(String(format: "%.0f", lakhs / 100))Cr"
            : "₹\(Int(lakhs))L"
    }
}

#Preview {
    ApplicationsView()
}
