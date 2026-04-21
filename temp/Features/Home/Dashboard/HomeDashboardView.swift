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
                    .frame(height: 300 + topInset)
                    .ignoresSafeArea(edges: .top)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        HeaderScrollTracker()
                            .frame(height: 0)

                        HeaderView(userName: displayName, collapseProgress: collapseProgress)
                            .padding(.top, topInset + 18)

                        // ── 2. LOAN SUMMARY CARDS (Paging Scroll) ──────
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 16) {
                                ForEach(viewModel.activeLoans) { loan in
                                    Button {
                                        router.push(.activeLoanDetails)
                                    } label: {
                                        LoanSummaryCardView(loan: loan)
                                            .frame(width: UIScreen.main.bounds.width * 0.85)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .safeAreaPadding(.horizontal, 20)
                        .padding(.top, 18)

                        // ── 3. NEXT EMI BANNER ─────────────────────────
                        NextEMIBannerView(emi: viewModel.nextEMI)
                            .padding(.horizontal, 20)
                            .padding(.top, 18)

                        // ── 4. QUICK ACTIONS ───────────────────────────
                        QuickActionsGridView(actions: viewModel.quickActions)
                            .padding(.horizontal, 20)
                            .padding(.top, 24)

                        // ── 5. CREDIBILITY SCORE (With Inner Buttons) ──
                        Button {
                            router.push(.credibilityOverview)
                        } label: {
                            CredibilityScoreCardView(score: viewModel.credibilityScore)
                        }
                        .buttonStyle(PlainButtonStyle())
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
                    DS.primaryLight
                ],
                startPoint: UnitPoint(x: 0.15, y: 0.0),
                endPoint: UnitPoint(x: 0.95, y: 0.88)
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
                    DS.surface.opacity(0.35),
                    DS.surface
                ],
                startPoint: .top,
                endPoint: .bottom
            )
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
                    .font(.subheadline).bold()
                    .foregroundColor(.secondaryBlue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(DS.primaryLight)
                    .clipShape(Capsule())
                Spacer()
                Text("Manage →").font(.subheadline).foregroundColor(.mainBlue)
            }
            .padding(.bottom, 18)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Outstanding Balance").font(.subheadline).foregroundColor(.secondary)
                    Text("₹\(loan.outstandingBalance, specifier: "%.0f")").font(.system(size: 34, weight: .bold)).foregroundColor(.mainBlue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total Loan").font(.subheadline).foregroundColor(.secondary)
                    Text("₹\(loan.totalAmount, specifier: "%.0f")").font(.title3).bold().foregroundColor(.primary)
                }
            }
            .padding(.bottom, 18)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(DS.primaryLight).frame(height: 12)
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
        .background(.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(DS.primary.opacity(0.3), lineWidth: 1.5))
        .shadow(color: DS.primary.opacity(0.15), radius: 15, x: 0, y: 8)
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
                router.push(.paymentCheckout(amount: emi.amount))
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
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions").font(.title3).bold().foregroundColor(.primary)
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(actions) { action in QuickActionItemView(action: action) }
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
    @EnvironmentObject var router: AppRouter

    var body: some View {
        Button {
            if action.label == String(localized: "AutoPay") { router.push(.autoPaySetup) }
            else if action.label == String(localized: "Pay EMI") { router.push(.repaymentDashboard) }
            else if action.label == String(localized: "History") { router.push(.repaymentsList(initialTab: 1)) }
            else if action.label == String(localized: "Support") { router.push(.chatList) }
            else if action.label == String(localized: "Schedule") { router.push(.amortisationSchedule) }
            else if action.label == String(localized: "Foreclose") { router.push(.outstandingBalance) }
            else if action.label == String(localized: "Statement") { router.push(.statementDownload) }
            else if action.label == String(localized: "Analytics") { router.push(.costBreakdown) }
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

// MARK: - Models & ViewModel
struct LoanSummary: Identifiable {
    let id: String
    let title: String
    let totalAmount: Double
    let outstandingBalance: Double
    var repaidFraction: Double { 1 - (outstandingBalance / totalAmount) }
    let remainingEMIs: Int
}
struct NextEMIInfo { let amount: Double; let dueDate: String; let daysLeft: String; let isUrgent: Bool }
struct QuickAction: Identifiable { let id = UUID(); let icon: String; let label: String }

class HomeDashboardViewModel: ObservableObject {
    // Localization added to arrays
    let activeLoans: [LoanSummary] = [
        LoanSummary(id: "1", title: String(localized: "Personal Loan"), totalAmount: 500000, outstandingBalance: 312000, remainingEMIs: 18),
        LoanSummary(id: "2", title: String(localized: "Auto Loan"), totalAmount: 850000, outstandingBalance: 720000, remainingEMIs: 48)
    ]
    
    let nextEMI = NextEMIInfo(amount: 14200, dueDate: String(localized: "20 Apr 2026"), daysLeft: String(localized: "6 days left"), isUrgent: true)
    let credibilityScore = 724
    
    let quickActions: [QuickAction] = [
        QuickAction(icon: "arrow.triangle.2.circlepath", label: String(localized: "AutoPay")),
        QuickAction(icon: "indianrupeesign.circle.fill", label: String(localized: "Pay EMI")),
        QuickAction(icon: "clock.arrow.circlepath", label: String(localized: "History")),
        QuickAction(icon: "headset", label: String(localized: "Support")),
        QuickAction(icon: "calendar", label: String(localized: "Schedule")),
        QuickAction(icon: "arrow.left.arrow.right", label: String(localized: "Foreclose")),
        QuickAction(icon: "doc.plaintext.fill", label: String(localized: "Statement")),
        QuickAction(icon: "chart.bar.fill", label: String(localized: "Analytics"))
    ]
}
