//
//  EarningsView.swift
//  LoanApp
//
//  Features/Earnings/Views/EarningsView.swift
//

import SwiftUI

struct EarningsView: View {
    @StateObject private var viewModel = EarningsViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.earnings.isEmpty {
                    ProgressView("Loading earnings...")
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text(error)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            Task {
                                await viewModel.loadData()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary Card
                            if let stats = viewModel.stats {
                                EarningsSummaryCard(stats: stats)
                                    .padding(.top, 8)
                            }
                            
                            // Removed Stats Row as requested
                            
                            // -- Start Filter Row --
                            FilterRowDynamic(viewModel: viewModel)
                                .padding(.top, 8)
                            // -- End Filter Row --
                            
                            // Transactions List
                            if viewModel.filteredEarnings.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "tray")
                                        .font(.system(size: 48))
                                        .foregroundColor(.secondary)
                                    Text("No transactions found")
                                        .font(.system(size: 15))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 60)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(viewModel.filteredEarnings) { earning in
                                        VStack(spacing: 0) {
                                            
                                            NavigationLink {
                                                EarningDetailView(
                                                    vm: EarningDetailViewModel(
                                                        earning: viewModel.mapToDetail(earning)
                                                    )
                                                )
                                            } label: {
                                                EarningTransactionRow(
                                                    earning: earning,
                                                    payoutText: viewModel.getExpectedPayoutText(for: earning)
                                                )
                                            }
                                            .buttonStyle(.plain) // keeps your UI clean
                                            
                                            if earning.id != viewModel.filteredEarnings.last?.id {
                                                Divider()
                                                    .padding(.leading, 68)
                                            }
                                        }
                                    }

                                }
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 80)
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationTitle("Earnings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            viewModel.showCalculator = true
                        } label: {
                            Label("Commission Calculator", systemImage: "percent")
                        }
                        
                        Button {
                            viewModel.showCommissionRates = true
                        } label: {
                            Label("View Commission Rates", systemImage: "list.bullet.rectangle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCalculator) {
                CommissionCalculatorSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showCommissionRates) {
                CommissionRateCard(rates: viewModel.commissionRates)
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
}

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    
    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.brandBlue : Color(.systemGray5))
            )
    }
}

struct ScrollOffsetTracker: PreferenceKey {
    static var defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next != 0 { value = next }
    }
}

struct FilterRowDynamic: View {
    @ObservedObject var viewModel: EarningsViewModel
    
    @State private var offset: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    @State private var viewWidth: CGFloat = 0
    
    var showLeftChevron: Bool { offset < -5 }
    var showRightChevron: Bool { viewWidth > 0 && contentWidth > viewWidth && offset > -(contentWidth - viewWidth + 5) }
    
    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { outerGeo in
                HStack(spacing: 0) {
                    if showLeftChevron {
                        Button {
                            if let first = EarningsViewModel.EarningFilter.allCases.first {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(first, anchor: .leading) }
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 16)
                                .padding(.trailing, 8)
                        }
                    }
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(EarningsViewModel.EarningFilter.allCases, id: \.self) { filter in
                                let title: String = {
                                    switch filter {
                                    case .all: return "All"
                                    case .paid: return "Paid \(viewModel.stats?.paidTransactionsCount ?? 0)"
                                    case .pending: return "Pending \(viewModel.stats?.pendingTransactionsCount ?? 0)"
                                    }
                                }()
                                
                                Button {
                                    viewModel.selectFilter(filter)
                                } label: {
                                    FilterPill(title: title, isSelected: viewModel.selectedFilter == filter)
                                }
                                .buttonStyle(.plain)
                                .id(filter)
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(
                            GeometryReader { geo in
                                Color.clear
                                    .preference(key: ScrollOffsetTracker.self, value: geo.frame(in: .named("earningsScroll")).minX)
                                    .onAppear { contentWidth = geo.size.width }
                                    .onChange(of: geo.size.width) { _ in contentWidth = geo.size.width }
                            }
                        )
                    }
                    .coordinateSpace(name: "earningsScroll")
                    .onPreferenceChange(ScrollOffsetTracker.self) { value in offset = value }
                    
                    if showRightChevron {
                        Button {
                            if let last = EarningsViewModel.EarningFilter.allCases.last {
                                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last, anchor: .trailing) }
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .onAppear { viewWidth = outerGeo.size.width }
                .onChange(of: outerGeo.size.width) { _ in viewWidth = outerGeo.size.width }
            }
            .frame(height: 36)
        }
    }
}

#Preview {
    EarningsView()
}
