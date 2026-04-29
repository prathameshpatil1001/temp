import SwiftUI

@available(iOS 18.0, *)
struct ActiveLoanDetailsView: View {
    let application: BorrowerLoanApplication

    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = ActiveLoanViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection

                if viewModel.isLoading && viewModel.activeLoan == nil {
                    ProgressView()
                        .padding(.top, 20)
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                } else if let loan = viewModel.activeLoan {
                    balanceCard(loan)
                    actionGrid
                    smartToolsSection
                    detailList(loan)
                    supportButton
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchAll(applicationId: application.id)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loan Details")
                .font(.largeTitle).bold()
                .foregroundColor(.primary)
            Text("\(application.loanProductName) • \(application.referenceNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func balanceCard(_ loan: ActiveLoan) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Outstanding Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(formatCurrency(loan.outstandingBalance))
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.mainBlue)
            }

            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(DS.primaryLight)
                            .frame(height: 12)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.mainBlue, .secondaryBlue], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * viewModel.repaymentProgress, height: 12)
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("\(Int(viewModel.repaymentProgress * 100))% repaid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatCurrency(loan.principalAmount) + " total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .padding(.horizontal, 20)
    }

    private var actionGrid: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                LoanActionTile(icon: "chart.bar.doc.horizontal", title: "Amortisation\nSchedule") {
                    router.push(.amortisationSchedule(loanId: viewModel.activeLoan?.id))
                }
                LoanActionTile(icon: "indianrupeesign.circle", title: "Outstanding\nBreakdown") {
                    if let loan = viewModel.activeLoan {
                        router.push(.outstandingBalance(loanId: loan.id, applicationId: loan.applicationId))
                    }
                }
            }
            // Foreclosure tile — full width, danger accent
            if let loan = viewModel.activeLoan {
                ForeClosureTile {
                    router.push(.outstandingBalance(loanId: loan.id, applicationId: loan.applicationId))
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var smartToolsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Financial Tools")
                .font(.headline)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    SmartToolCardView(icon: "bolt.fill", title: "Prepayment\nCalculator", bgColor: .mainBlue) {
                        router.push(.prepaymentCalculator)
                    }
                    SmartToolCardView(icon: "slider.horizontal.3", title: "What-If\nSimulator", bgColor: .secondaryBlue) {
                        router.push(.whatIfSimulator)
                    }
                    SmartToolCardView(icon: "star.fill", title: "Savings\nInsights", bgColor: Color(hex: "#00C48C")) {
                        router.push(.savingsInsight)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
    }

    private func detailList(_ loan: ActiveLoan) -> some View {
        VStack(spacing: 0) {
            InfoListRow(title: "Interest Rate", value: "\(loan.interestRate)% p.a.")
            Divider().padding(.leading, 20)
            InfoListRow(title: "Monthly EMI", value: formatCurrency(loan.emiAmount))
            Divider().padding(.leading, 20)
            InfoListRow(title: "Tenure Remaining", value: "\(viewModel.upcomingEMIs.count) EMIs")
            Divider().padding(.leading, 20)
            InfoListRow(title: "Next EMI Date", value: nextEmiDateText)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    private var supportButton: some View {
        Button {
            router.push(.chatList)
        } label: {
            HStack {
                Image(systemName: "message.fill")
                Text("Chat with Loan Support")
            }
            .font(.headline)
            .foregroundColor(.mainBlue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DS.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 20)
    }

    private var nextEmiDateText: String {
        if let upcoming = viewModel.upcomingEMIs.first {
            return formattedDate(upcoming.dueDate)
        }
        return "No upcoming EMI"
    }

    private func formattedDate(_ raw: String) -> String {
        if let date = ISO8601DateFormatter().date(from: raw) {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return raw
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

struct LoanActionTile: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.mainBlue)
                    .padding(12)
                    .background(DS.primaryLight)
                    .clipShape(Circle())

                Text(title)
                    .font(.subheadline).bold()
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
    }
}

// MARK: - Foreclosure Tile
struct ForeClosureTile: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "lock.open.trianglebadge.exclamationmark.fill")
                    .font(.title2)
                    .foregroundColor(DS.danger)
                    .padding(12)
                    .background(DS.danger.opacity(0.10))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Foreclose Loan")
                        .font(.subheadline).bold()
                        .foregroundColor(DS.danger)
                    Text("View settlement quote & initiate early closure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DS.danger.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DS.danger.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: DS.danger.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
}

struct SmartToolCardView: View {
    let icon: String
    let title: String
    let bgColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Spacer()
                Text(title)
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 140, alignment: .leading)
            .padding(16)
            .frame(minHeight: 110)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: bgColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}

struct InfoListRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.subheadline).bold().foregroundColor(.primary)
        }
        .padding(20)
    }
}
