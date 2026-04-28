import SwiftUI

struct LeadsView: View {
    @StateObject private var viewModel = LeadsViewModel()
    @State private var navPath = NavigationPath()
    @State private var showDeleteConfirm = false
    @State private var leadToDelete: Lead? = nil

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .top) {
                Color.surfaceSecondary.ignoresSafeArea()
                DSTHeaderGradientBackground(height: 230)

                VStack(spacing: 0) {
                    leadsHero
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.top, AppSpacing.sm)

                    stickyHeader

                    if !viewModel.isLoading {
                        HStack {
                            Text(viewModel.leadCountText)
                                .font(AppFont.subheadMed())
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.top, AppSpacing.xs)
                        .padding(.bottom, AppSpacing.xs)
                    }

                    leadListContent
                }
                .padding(.top, -8)
            }
            .navigationTitle("Leads")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showAddLead = true } label: {
                        Text("Add Lead")
                            .font(AppFont.subheadMed())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandBlue)
                    .buttonBorderShape(.capsule)
                }
            }
            // ── Add Lead modal — always bottom sheet, never iPad popup ──
            .sheet(isPresented: $viewModel.showAddLead) {
                AddLeadView(viewModel: viewModel)
                    .presentationDetents([.height(560), .large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
                    .presentationContentInteraction(.scrolls)
                    .presentationCompactAdaptation(.sheet)
            }
            // ── Lead Detail push ──
            .navigationDestination(for: Lead.self) { lead in
                LeadDetailView(
                    lead: lead,
                    onStatusUpdate: { id, status in
                        viewModel.updateLeadStatus(id: id, status: status)
                    },
                    onLeadSave: { updatedLead in
                        viewModel.updateLead(updatedLead)
                    }
                )
            }
            .refreshable {
                viewModel.loadLeads()
            }
        }
    }

    private var leadsHero: some View {
        DSTSurfaceCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                DSTSectionTitle("Lead Pipeline", subtitle: "Capture prospects, move them forward quickly, and keep every sales touchpoint visible.")

                HStack(spacing: AppSpacing.sm) {
                    leadMetric(title: "Total Leads", value: "\(viewModel.leads.count)", valueColor: Color.textPrimary)
                    leadMetric(title: "Submitted", value: "\(viewModel.leads.filter { $0.status == .submitted }.count)", valueColor: Color.brandBlue)
                    leadMetric(title: "Approved", value: "\(viewModel.leads.filter { $0.status == .approved }.count)", valueColor: Color.statusApproved)
                }
            }
        }
    }

    private func leadMetric(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.title2())
                .foregroundColor(valueColor)
            Text(title)
                .font(AppFont.caption())
                .foregroundColor(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.sm)
        .background(Color.brandBlueSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    // MARK: - Sticky Header
    private var stickyHeader: some View {
        VStack(spacing: 0) {
            SearchBarView(text: $viewModel.searchText)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)

            ScrollViewReader { proxy in
                GeometryReader { outerGeo in
                    HStack(spacing: 0) {
                        if viewModel.canScrollLeft {
                            Button {
                                if let first = viewModel.filters.first {
                                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first.id, anchor: .leading) }
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
                                ForEach(viewModel.filters) { filter in
                                    FilterChipView(
                                        filter: filter,
                                        count: viewModel.count(for: filter),
                                        isSelected: viewModel.selectedFilter == filter
                                    ) {
                                        viewModel.selectFilter(filter)
                                    }
                                    .id(filter.id)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ScrollOffsetTracker.self, value: geo.frame(in: .named("leadsScroll")).minX)
                                        .onAppear { viewModel.contentWidth = geo.size.width }
                                        .onChange(of: geo.size.width) { _ in viewModel.contentWidth = geo.size.width }
                                }
                            )
                        }
                        .coordinateSpace(name: "leadsScroll")
                        .onPreferenceChange(ScrollOffsetTracker.self) { value in viewModel.scrollOffset = value }

                        if viewModel.canScrollRight {
                            Button {
                                if let last = viewModel.filters.last {
                                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .trailing) }
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
            .padding(.bottom, AppSpacing.xs)
        }
        .background(Color.clear)
    }

    // MARK: - List Content
    @ViewBuilder
    private var leadListContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.filteredLeads.isEmpty {
            EmptyStateView(
                filter: viewModel.selectedFilter,
                searchText: viewModel.searchText
            ) { viewModel.showAddLead = true }
        } else {
            leadList
        }
    }

    // MARK: - Lead List
    private var leadList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.filteredLeads, id: \.id) { lead in
                    // NavigationLink for push navigation
                    NavigationLink(value: lead) {
                        LeadRowContent(lead: lead)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if lead.status == .submitted {
                            Button(role: .destructive) {
                                leadToDelete = lead
                                showDeleteConfirm = true
                            } label: {
                                Label("Delete Lead", systemImage: "trash")
                            }
                        }
                    }

                    if lead.id != viewModel.filteredLeads.last?.id {
                        Divider().padding(.leading, 76)
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
        .confirmationDialog("Delete Lead", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let lead = leadToDelete {
                    viewModel.deleteLead(lead)
                }
                leadToDelete = nil
            }
            Button("Cancel", role: .cancel) { leadToDelete = nil }
        } message: {
            if let lead = leadToDelete {
                Text("Delete \(lead.name)'s lead? This cannot be undone.")
            }
        }
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            Spacer()
            ProgressView().tint(Color.brandBlue)
            Text("Loading leads…")
                .font(AppFont.subhead())
                .foregroundColor(Color.textSecondary)
            Spacer()
        }
    }
}

// MARK: - Row Content (pure visual, no button wrapper)
struct LeadRowContent: View {
    let lead: Lead

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            AvatarView(
                initials: lead.initials,
                color: lead.name.avatarColor,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lead.name)
                        .font(AppFont.bodyMedium())
                        .foregroundColor(Color.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    StatusBadgeView(status: lead.status)
                }
                HStack(spacing: 6) {
                    Image(systemName: lead.loanType.icon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.textTertiary)
                    Text(lead.loanType.rawValue)
                        .font(AppFont.subhead())
                        .foregroundColor(Color.textSecondary)
                    Text("·")
                        .foregroundColor(Color.textTertiary)
                    Text(lead.formattedAmount)
                        .font(AppFont.subheadMed())
                        .foregroundColor(Color.textSecondary)
                    Spacer()
                    Text(lead.timeAgo)
                        .font(AppFont.caption())
                        .foregroundColor(Color.textTertiary)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(Color.surfacePrimary)
        .contentShape(Rectangle())
    }
}

#Preview {
    LeadsView()
}
