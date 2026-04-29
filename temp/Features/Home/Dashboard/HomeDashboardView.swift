import SwiftUI
import Combine

// MARK: - Main Home View
struct HomeDashboardView: View {
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject private var session: SessionStore
    @StateObject var viewModel = HomeDashboardViewModel()
    @State private var headerScrollOffset: CGFloat = 0

    private var displayName: String {
        let trimmedName = session.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? "LoanOS Borrower" : trimmedName
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let collapseProgress = min(max(-headerScrollOffset / 110, 0), 1)

            ZStack(alignment: .top) {
                DS.surface.ignoresSafeArea()
                HeaderGradientBackground()
                    .frame(height: 560 + topInset)
                    .ignoresSafeArea(edges: .top)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeaderScrollTracker()
                            .frame(height: 0)

                        HeaderView(userName: displayName, collapseProgress: collapseProgress)
                            .padding(.top, topInset + 18)

                        if viewModel.isLoading && viewModel.activeLoans.isEmpty {
                            ProgressView()
                                .padding(.top, 36)
                        } else {
                            if let errorMessage = viewModel.errorMessage {
                                DashboardInfoCard(
                                    title: "Loan summary unavailable",
                                    message: errorMessage
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 18)
                            }

                            if !viewModel.activeLoans.isEmpty {
                                // ── 2. LOAN SUMMARY CARDS (Paging Scroll) ──────
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 16) {
                                        ForEach(viewModel.activeLoans) { loan in
                                            Button {
                                                if let application = loan.application {
                                                    router.push(.activeLoanDetails(application))
                                                }
                                            } label: {
                                                LoanSummaryCardView(loan: loan)
                                                    .frame(width: proxy.size.width * 0.85)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .safeAreaPadding(.horizontal, 20)
                                .padding(.top, 18)
                            }

                            if viewModel.activeLoans.isEmpty && !viewModel.inProgressApplications.isEmpty {
                                InProgressApplicationsCard(applications: viewModel.inProgressApplications)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                            }

                            // ── 3. NEXT EMI BANNER ─────────────────────────
                            if let nextEMI = viewModel.nextEMI {
                                NextEMIBannerView(emi: nextEMI)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 18)
                            }
                        }

                        // ── 4. QUICK ACTIONS ───────────────────────────
                        QuickActionsGridView(actions: viewModel.quickActions, viewModel: viewModel)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)

                        // ── 5. CREDIBILITY SCORE (With Inner Buttons) ──
                        Group {
                            if let credibilityScore = viewModel.credibilityScore {
                                Button {
                                    router.push(.credibilityOverview(score: credibilityScore))
                                } label: {
                                    CredibilityScoreCardView(score: credibilityScore)
                                }
                                .buttonStyle(PlainButtonStyle())
                            } else {
                                CredibilityScoreUnavailableView()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
                .coordinateSpace(name: "HomeDashboardScroll")
                .onPreferenceChange(HeaderScrollOffsetKey.self) { headerScrollOffset = $0 }

                HeaderTopBlurOverlay(collapseProgress: collapseProgress, topInset: topInset)
            }
        }
        .navigationBarHidden(true)
        .task {
            viewModel.fetchDashboardData()
        }
    }
}

// MARK: - 1. Header
struct HeaderView: View {
    let userName: String
    let collapseProgress: CGFloat
    @EnvironmentObject var router: AppRouter

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Good Morning,")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.80))
                Text(userName)
                    .font(.system(size: 32 - (5 * collapseProgress), weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            Spacer()

            Button(action: {
                router.push(.notifications)
            }) {
                NotificationButton()
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 34 - (12 * collapseProgress))
    }
}

struct HeaderGradientBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    DS.primary,
                    DS.primary,
                    DS.primaryLight,
                    Color(hex: "#E9EEFF")
                ],
                startPoint: UnitPoint(x: 0.15, y: 0.0),
                endPoint: UnitPoint(x: 0.95, y: 1.0)
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.26),
                    .white.opacity(0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.15, y: 0.0),
                startRadius: 12,
                endRadius: 260
            )
            .offset(x: -20, y: -30)

            LinearGradient(
                colors: [
                    .white.opacity(0.12),
                    .clear,
                    DS.primaryLight.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    .white.opacity(0.18),
                    .clear
                ],
                center: UnitPoint(x: 0.92, y: 0.1),
                startRadius: 0,
                endRadius: 150
            )

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.18),
                    DS.surface.opacity(0.30),
                    DS.surface
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.45),
                endPoint: .bottom
            )

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.18),
                            DS.surface.opacity(0.55),
                            DS.surface.opacity(0.96)
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0.08),
                        endPoint: .bottom
                    )
                )
                .blur(radius: 20)
                .scaleEffect(x: 1.05, y: 1.18, anchor: .bottom)
                .offset(y: 180)
        }
    }
}

struct HeaderTopBlurOverlay: View {
    let collapseProgress: CGFloat
    let topInset: CGFloat

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [
                        .white.opacity(0.10 + (0.15 * collapseProgress)),
                        .white.opacity(0.02)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(collapseProgress)
            .frame(height: topInset + 52)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

struct NotificationButton: View {
    var body: some View {
        Circle()
            .fill(.white.opacity(0.16))
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            )
            .frame(width: 42, height: 42)
            .overlay {
                Image(systemName: "bell.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.96))
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(DS.danger)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    )
                    .offset(x: 0, y: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct HeaderScrollTracker: View {
    var body: some View {
        GeometryReader { geometry in
            Color.clear.preference(
                key: HeaderScrollOffsetKey.self,
                value: geometry.frame(in: .named("HomeDashboardScroll")).minY
            )
        }
    }
}

struct HeaderScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - 2. Loan Summary Card
struct LoanSummaryCardView: View {
    let loan: LoanSummary

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(loan.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondaryBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.88))
                    .clipShape(Capsule())
                Spacer()
                Text("Manage →")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.mainBlue)
            }
            .padding(.bottom, 18)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outstanding Balance").font(.subheadline).foregroundColor(.secondary)
                    Text(formatINRCurrency(loan.outstandingBalance))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.mainBlue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Loan").font(.subheadline).foregroundColor(.secondary)
                    Text(formatINRCurrency(loan.totalAmount)).font(.system(size: 20, weight: .bold)).foregroundColor(.primary)
                }
            }
            .padding(.bottom, 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#E8EEFF"))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [.mainBlue, .secondaryBlue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * loan.repaidFraction, height: 12)
                }
            }
            .frame(height: 12)
            .padding(.bottom, 10)

            HStack {
                Text("\(Int(loan.repaidFraction * 100))% repaid").font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text("\(loan.remainingEMIs) EMIs left").font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.98),
                    Color(hex: "#F7F9FF")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.85), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#AFC4FF").opacity(0.24), radius: 24, x: 0, y: 12)
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

struct DashboardInfoCard: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct InProgressApplicationsCard: View {
    let applications: [BorrowerLoanApplication]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Applications In Progress")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)

            if let app = applications.first {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.loanProductName.isEmpty ? "Loan Application" : app.loanProductName)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(DS.textPrimary)
                            
                            Text("Status: \(BorrowerSanctionLetterSupport.statusTitle(for: app))")
                                .font(.system(size: 14))
                                .foregroundColor(DS.textSecondary)
                        }
                        
                        Spacer()
                        
                        Text(formatINRCurrency(app.requestedAmount))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(DS.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DS.primary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(DS.primary.opacity(0.24), lineWidth: 1)
                                    .shadow(color: DS.primary.opacity(0.2), radius: 4)
                            )
                    }

                    // Progress Tracker
                    ApplicationStepTracker(currentStatus: app.status)

                    HStack {
                        Spacer()
                        Text("Track tab shows full application details...")
                            .font(.system(size: 12))
                            .foregroundColor(DS.textSecondary.opacity(0.8))
                    }
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 15, x: 0, y: 5)
    }
}

struct ApplicationStepTracker: View {
    let currentStatus: LoanApplicationStatus
    
    let steps = ["Application", "Verification", "Approval", "Sanction", "Disbursement"]
    
    private var currentStep: Int {
        switch currentStatus {
        case .draft: return 0
        case .submitted, .underReview, .officerReview, .managerReview: return 1
        case .approved, .officerApproved: return 2
        case .managerApproved: return 3
        case .disbursed: return 4
        case .rejected, .officerRejected, .managerRejected, .cancelled: return 0 // Fallback
        default: return 0
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(DS.border.opacity(0.5))
                        .frame(height: 6)

                    Capsule()
                        .fill(DS.primary)
                        .frame(width: progressWidth(for: geometry.size.width), height: 6)

                    HStack(spacing: 0) {
                        ForEach(0..<steps.count) { index in
                            Circle()
                                .fill(index <= currentStep ? DS.primary : .white)
                                .frame(width: 14, height: 14)
                                .overlay(
                                    Circle()
                                        .stroke(index <= currentStep ? DS.primary : DS.border, lineWidth: 2)
                                )
                                .frame(maxWidth: .infinity, alignment: stepAlignment(index))
                        }
                    }
                }

                HStack(spacing: 0) {
                    ForEach(0..<steps.count) { index in
                        Text(steps[index])
                            .font(.system(size: 10, weight: index == currentStep ? .bold : .medium))
                            .foregroundColor(index <= currentStep ? DS.textPrimary : DS.textSecondary.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: stepAlignment(index))
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 34)
    }
    
    private func progressWidth(for availableWidth: CGFloat) -> CGFloat {
        guard steps.count > 1 else { return 0 }
        return (availableWidth / CGFloat(steps.count - 1)) * CGFloat(currentStep)
    }
    
    private func stepAlignment(_ index: Int) -> Alignment {
        if index == 0 { return .leading }
        if index == steps.count - 1 { return .trailing }
        return .center
    }
}

// MARK: - 3. Next EMI Banner
struct NextEMIBannerView: View {
    let emi: NextEMIInfo
    @EnvironmentObject var router: AppRouter

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(emi.isUrgent ? DS.danger.opacity(0.12) : DS.primary.opacity(0.10))
                .frame(width: 44, height: 44)
                .overlay(Image(systemName: emi.isUrgent ? "exclamationmark.circle.fill" : "calendar.badge.clock").font(.body).foregroundColor(emi.isUrgent ? .alertRed : .mainBlue))

            VStack(alignment: .leading, spacing: 2) {
                Text("Next EMI").font(.caption).foregroundColor(.secondary).lineLimit(1)
                Text(emi.dueDate).font(.subheadline).bold().foregroundColor(emi.isUrgent ? .alertRed : .primary).lineLimit(1).minimumScaleFactor(0.8)
            }
            
            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(emi.amount.formatted(.number.grouping(.automatic)))")
                    .font(.subheadline).bold()
                    .foregroundColor(.mainBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: true, vertical: false)
                Text(emi.daysLeft).font(.caption2).foregroundColor(emi.isUrgent ? .alertRed : .secondary).lineLimit(1)
            }
            .padding(.trailing, 8)

            Button {
                router.push(.paymentCheckout(
                    loanId: emi.loanId,
                    emiScheduleId: emi.emiScheduleId,
                    amount: emi.amount
                ))
            } label: {
                Text("Pay Now").font(.caption).bold().foregroundColor(.white).padding(.horizontal, 12).padding(.vertical, 8).background(DS.primary).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(14)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(emi.isUrgent ? DS.danger.opacity(0.4) : Color.clear, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 4. Quick Actions Grid
struct QuickActionsGridView: View {
    let actions: [QuickAction]
    let viewModel: HomeDashboardViewModel
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions").font(.title3).bold().foregroundColor(.primary)
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(actions) { action in QuickActionItemView(action: action, viewModel: viewModel) }
            }
        }
        .padding(20)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

struct QuickActionItemView: View {
    let action: QuickAction
    let viewModel: HomeDashboardViewModel
    @EnvironmentObject var router: AppRouter

    var body: some View {
        Button {
            switch action.kind {
            case .autoPay:
                router.push(.autoPaySetup)
            case .payEMI:
                if let nextEMI = viewModel.nextEMI {
                    router.push(.paymentCheckout(
                        loanId: nextEMI.loanId,
                        emiScheduleId: nextEMI.emiScheduleId,
                        amount: nextEMI.amount
                    ))
                } else if let appId = viewModel.activeLoans.first?.application?.id, !appId.isEmpty {
                    router.push(.repaymentDashboard(applicationId: appId))
                }
            case .history:
                router.push(.repaymentsList(loanId: "", initialTab: 1))
            case .support:
                router.push(.chatList)
            case .schedule:
                if let loanId = viewModel.activeLoans.first?.id, !loanId.isEmpty {
                    router.push(.amortisationSchedule(loanId: loanId))
                }
            case .foreclose:
                if let loan = viewModel.activeLoans.first, let appId = loan.application?.id, !loan.id.isEmpty {
                    router.push(.outstandingBalance(loanId: loan.id, applicationId: appId))
                }
            case .statement:
                router.push(.statementDownload)
            case .analytics:
                router.push(.costBreakdown)
            }
        } label: {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 16).fill(DS.primaryLight).frame(width: 64, height: 64)
                    .overlay(Image(systemName: action.icon).font(.title2).foregroundColor(.mainBlue))
                Text(action.label).font(.caption).multilineTextAlignment(.center).foregroundColor(.primary).lineLimit(2)
            }
        }
    }
}

// MARK: - 5. Credibility Score Card
struct CredibilityScoreCardView: View {
    let score: Int
    @EnvironmentObject var router: AppRouter
    
    private var scoreColor: Color {
        switch score { case 750...: return Color(hex: "#00C48C"); case 600..<750: return DS.primary; default: return DS.danger }
    }
    private var scoreLabel: String {
        switch score { case 750...: return String(localized: "Excellent"); case 650..<750: return String(localized: "Good"); case 500..<650: return String(localized: "Fair"); default: return String(localized: "Poor") }
    }
    var body: some View {
        VStack(spacing: 20) {
            // Top Section: Score Info
            HStack(spacing: 20) {
                ZStack {
                    Circle().stroke(DS.primaryLight, lineWidth: 10).frame(width: 90, height: 90)
                    Circle().trim(from: 0, to: CGFloat(score) / 900).stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round)).frame(width: 90, height: 90).rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\(score)").font(.title3).bold().foregroundColor(scoreColor)
                        Text("/ 900").font(.caption).foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Credibility Score").font(.headline).foregroundColor(.primary)
                    Text(scoreLabel).font(.subheadline).bold().foregroundColor(scoreColor).padding(.horizontal, 12).padding(.vertical, 5).background(scoreColor.opacity(0.12)).clipShape(Capsule())
                    Text("Updated today").font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.title3).foregroundColor(.secondary)
            }
            
            Divider()
            
            // Bottom Section: Inner Buttons
            HStack(spacing: 12) {
                Button {
                    router.push(.scoreBreakdown)
                } label: {
                    HStack {
                        Image(systemName: "list.clipboard.fill")
                        Text("Breakdown")
                    }
                    .font(.subheadline).bold()
                    .foregroundColor(.mainBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.primaryLight.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button {
                    router.push(.scoreHistory)
                } label: {
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                        Text("History")
                    }
                    .font(.subheadline).bold()
                    .foregroundColor(.mainBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DS.primaryLight.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(22)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
    }
}

struct CredibilityScoreUnavailableView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Credibility Score")
                .font(.headline)
                .foregroundColor(.primary)
            Text("Your live score will appear here after bureau checks are recorded for an application.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("No score available yet")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.mainBlue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 5)
    }
}

// MARK: - Models & ViewModel
struct LoanSummary: Identifiable {
    let id: String
    let application: BorrowerLoanApplication?
    let title: String
    let totalAmount: Double
    let outstandingBalance: Double
    var repaidFraction: Double {
        guard totalAmount > 0 else { return 0 }
        return min(max(1 - (outstandingBalance / totalAmount), 0), 1)
    }
    let remainingEMIs: Int
}
struct NextEMIInfo {
    let amount: Double
    let dueDate: String
    let daysLeft: String
    let isUrgent: Bool
    // Context for real payment flow
    let loanId: String
    let emiScheduleId: String
    let applicationId: String
}
enum QuickActionKind: String, Hashable {
    case autoPay
    case payEMI
    case history
    case support
    case schedule
    case foreclose
    case statement
    case analytics
}

struct QuickAction: Identifiable {
    let kind: QuickActionKind
    let icon: String
    let label: String

    var id: QuickActionKind { kind }
}

private func formatINRCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: "en_IN")
    formatter.numberStyle = .currency
    formatter.currencySymbol = "₹"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    return formatter.string(from: NSNumber(value: amount)) ?? "₹\(Int(amount))"
}

private func formatINRCurrency(_ rawAmount: String) -> String {
    guard let amount = Double(rawAmount) else { return "₹\(rawAmount)" }
    return formatINRCurrency(amount)
}

@MainActor
@available(iOS 18.0, *)
final class HomeDashboardViewModel: ObservableObject {
    @Published var activeLoans: [LoanSummary] = []
    @Published var inProgressApplications: [BorrowerLoanApplication] = []
    @Published var hasAnyLoanRecord: Bool = false
    @Published var nextEMI: NextEMIInfo? = nil
    @Published var credibilityScore: Int? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    let quickActions: [QuickAction] = [
        QuickAction(kind: .support, icon: "headphones", label: String(localized: "Messages")),
        QuickAction(kind: .payEMI, icon: "indianrupeesign.circle.fill", label: String(localized: "Pay EMI")),
        QuickAction(kind: .history, icon: "clock.arrow.circlepath", label: String(localized: "History")),
        QuickAction(kind: .analytics, icon: "chart.bar.fill", label: String(localized: "Analytics"))
    ]

    private let service: LoanServiceProtocol
    private let authRepository: AuthRepository

    init(
        service: LoanServiceProtocol = ServiceContainer.loanService,
        authRepository: AuthRepository = AuthRepository()
    ) {
        self.service = service
        self.authRepository = authRepository
    }

    func fetchDashboardData() {
        Task {
            await fetchDashboardDataInternal()
        }
    }

    private func fetchDashboardDataInternal() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let applicationsTask = service.listLoanApplications(limit: 100, offset: 0)
            async let loansTask = service.listLoans(limit: 100, offset: 0)
            async let profileTask = authRepository.getMyProfile()

            let (applications, loans, profile) = try await (applicationsTask, loansTask, profileTask)
            let schedules = try await loadSchedules(for: loans)
            let liveLoans = loans.filter { loan in
                !isLoanCompleted(loan, schedule: schedules[loan.id] ?? [])
            }
            let activeApplicationIDs = Set(liveLoans.map(\.applicationId))
            let reconciledApplications = applications.map { application in
                if application.status == .disbursed && !loans.contains(where: { $0.applicationId == application.id }) {
                    return application.withStatus(.managerApproved)
                }
                return application
            }
            let applicationsById = Dictionary(uniqueKeysWithValues: reconciledApplications.map { ($0.id, $0) })
            credibilityScore = profile.cibilScore

            inProgressApplications = reconciledApplications
                .filter { !activeApplicationIDs.contains($0.id) && $0.status.isInProgressForDashboard }
                .sorted { parseDate($0.updatedAt) > parseDate($1.updatedAt) }

            activeLoans = liveLoans.map { loan in
                let application = applicationsById[loan.applicationId]
                let totalAmount = Double(loan.principalAmount) ?? Double(application?.requestedAmount ?? "") ?? 0
                let outstanding = Double(loan.outstandingBalance) ?? 0
                let remainingEMIs = (schedules[loan.id] ?? []).filter { $0.status != .paid }.count
                return LoanSummary(
                    id: loan.id,
                    application: application,
                    title: (application?.loanProductName.isEmpty == false ? application!.loanProductName : "Active Loan"),
                    totalAmount: totalAmount,
                    outstandingBalance: outstanding,
                    remainingEMIs: remainingEMIs
                )
            }
            .sorted { lhs, rhs in
                parseDate(lhs.application?.updatedAt ?? "") > parseDate(rhs.application?.updatedAt ?? "")
            }
            hasAnyLoanRecord = !activeLoans.isEmpty

            nextEMI = buildNextEMI(
                loans: liveLoans,
                applicationsById: applicationsById,
                schedules: schedules
            )
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load your live loan dashboard."
            activeLoans = []
            inProgressApplications = []
            hasAnyLoanRecord = false
            nextEMI = nil
            credibilityScore = nil
        }
    }

    private func loadSchedules(for loans: [ActiveLoan]) async throws -> [String: [EmiScheduleItem]] {
        try await withThrowingTaskGroup(of: (String, [EmiScheduleItem]).self) { group in
            for loan in loans {
                group.addTask { [service] in
                    let items = try await service.listEmiSchedule(loanId: loan.id)
                    return (loan.id, items)
                }
            }

            var schedules: [String: [EmiScheduleItem]] = [:]
            for try await (loanId, items) in group {
                schedules[loanId] = items
            }
            return schedules
        }
    }

    private func buildNextEMI(
        loans: [ActiveLoan],
        applicationsById: [String: BorrowerLoanApplication],
        schedules: [String: [EmiScheduleItem]]
    ) -> NextEMIInfo? {
        let nextSchedule = loans.compactMap { loan -> (ActiveLoan, EmiScheduleItem)? in
            let upcoming = (schedules[loan.id] ?? [])
                .filter { $0.status == .upcoming || $0.status == .overdue }
                .sorted { parseDate($0.dueDate) < parseDate($1.dueDate) }
                .first
            guard let upcoming else { return nil }
            return (loan, upcoming)
        }
        .sorted { parseDate($0.1.dueDate) < parseDate($1.1.dueDate) }
        .first

        guard let (loan, schedule) = nextSchedule else { return nil }
        let application = applicationsById[loan.applicationId]

        let amount = Double(schedule.emiAmount) ?? 0
        let dueDate = parseDate(schedule.dueDate)
        return NextEMIInfo(
            amount: amount,
            dueDate: formatDate(dueDate),
            daysLeft: dueDateLabel(for: dueDate),
            isUrgent: schedule.status == .overdue || Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: dueDate)).day ?? 0 <= 3,
            loanId: loan.id,
            emiScheduleId: schedule.id,
            applicationId: application?.id ?? ""
        )
    }

    private func dueDateLabel(for dueDate: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let due = calendar.startOfDay(for: dueDate)
        let days = calendar.dateComponents([.day], from: today, to: due).day ?? 0

        if days < 0 { return "Overdue by \(abs(days)) day\(abs(days) == 1 ? "" : "s")" }
        if days == 0 { return "Due today" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }

    private func isLoanCompleted(_ loan: ActiveLoan, schedule: [EmiScheduleItem]) -> Bool {
        if loan.status == .closed {
            return true
        }

        let outstanding = Double(loan.outstandingBalance) ?? .greatestFiniteMagnitude
        if outstanding <= 0.01 {
            return true
        }

        if !schedule.isEmpty && schedule.allSatisfy({ $0.status == .paid }) {
            return true
        }

        return false
    }

    private func parseDate(_ raw: String) -> Date {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw) ?? .distantPast
    }

    private func formatDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
