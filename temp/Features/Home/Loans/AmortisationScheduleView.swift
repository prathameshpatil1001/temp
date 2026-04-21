import SwiftUI
import Charts
import Combine

struct AmortisationMonth: Identifiable {
    let id = UUID()
    let monthIndex: Int
    let date: Date
    let principalPaid: Double
    let interestPaid: Double
    let balance: Double
    var isPaid: Bool
}

class AmortisationViewModel: ObservableObject {
    @Published var schedule: [AmortisationMonth] = []
    @Published var selectedMonth: AmortisationMonth? = nil

    init() { generateSchedule() }

    func generateSchedule() {
        var bal = 312000.0
        let emi = 14200.0
        var temp: [AmortisationMonth] = []
        let calendar = Calendar.current
        // Start from May 2026 (next EMI after April 20 2026)
        let startComponents = DateComponents(year: 2026, month: 5, day: 20)
        let startDate = calendar.date(from: startComponents)!

        for i in 0..<18 {
            let interest = bal * (10.5 / 12 / 100)
            let principal = emi - interest
            bal -= principal
            if bal < 0 { bal = 0 }
            let date = calendar.date(byAdding: .month, value: i, to: startDate)!
            temp.append(AmortisationMonth(
                monthIndex: i + 1,
                date: date,
                principalPaid: principal,
                interestPaid: interest,
                balance: max(bal, 0),
                isPaid: i < 2 // first 2 already paid for demo
            ))
        }
        self.schedule = temp
        self.selectedMonth = temp.first
    }

    var totalInterest: Double { schedule.reduce(0) { $0 + $1.interestPaid } }
    var totalPrincipal: Double { schedule.reduce(0) { $0 + $1.principalPaid } }
}

struct AmortisationScheduleView: View {
    @StateObject var viewModel = AmortisationViewModel()

    // Group months by year
    var groupedByYear: [(Int, [AmortisationMonth])] {
        let dict = Dictionary(grouping: viewModel.schedule) { month -> Int in
            Calendar.current.component(.year, from: month.date)
        }
        return dict.keys.sorted().map { ($0, dict[$0]!) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amortisation Schedule")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                    Text("18 monthly payments ending Oct 2027")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)

                // Summary strip
                HStack(spacing: 0) {
                    SummaryPill(label: "Total Principal", value: "₹\(viewModel.totalPrincipal.formatted(.number.notation(.compactName).precision(.fractionLength(2))))", color: .mainBlue)
                    Divider().frame(height: 40)
                    SummaryPill(label: "Total Interest", value: "₹\(viewModel.totalInterest.formatted(.number.notation(.compactName).precision(.fractionLength(2))))", color: .alertRed)
                    Divider().frame(height: 40)
                    SummaryPill(label: "EMI", value: "₹14,200", color: Color(hex: "#00C48C"))
                }
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)

                // Selected month detail card
                if let sel = viewModel.selectedMonth {
                    SelectedMonthCard(month: sel)
                        .padding(.horizontal, 20)
                }

                // Calendar-style grid per year
                ForEach(groupedByYear, id: \.0) { year, months in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(year))
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        CalendarYearGrid(months: months, selectedMonth: $viewModel.selectedMonth)
                            .padding(.horizontal, 20)
                    }
                }

                // Payoff balance chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Balance Over Time")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    Chart {
                        ForEach(viewModel.schedule) { item in
                            AreaMark(
                                x: .value("Month", item.monthIndex),
                                y: .value("Balance", item.balance)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.mainBlue.opacity(0.35), .lightBlue.opacity(0.05)], startPoint: .top, endPoint: .bottom)
                            )
                            LineMark(
                                x: .value("Month", item.monthIndex),
                                y: .value("Balance", item.balance)
                            )
                            .foregroundStyle(DS.primary)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                        }
                    }
                    .frame(height: 180)
                    .chartXAxis {
                        AxisMarks(values: .stride(by: 3))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("₹\(v.formatted(.number.notation(.compactName).precision(.fractionLength(2))))")
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)

            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Calendar Year Grid
struct CalendarYearGrid: View {
    let months: [AmortisationMonth]
    @Binding var selectedMonth: AmortisationMonth?

    private let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                               "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private func calendarMonth(_ m: AmortisationMonth) -> String {
        let cal = Calendar.current
        let idx = cal.component(.month, from: m.date) - 1
        return monthNames[idx]
    }

    // Progress fraction: how much of this month is principal vs interest
    private func principalFraction(_ m: AmortisationMonth) -> CGFloat {
        let total = m.principalPaid + m.interestPaid
        return total > 0 ? CGFloat(m.principalPaid / total) : 0
    }

    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        LazyVGrid(columns: cols, spacing: 10) {
            ForEach(months) { month in
                let isSelected = selectedMonth?.id == month.id
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedMonth = month
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(calendarMonth(month))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(isSelected ? .white : (month.isPaid ? .secondary : .primary))

                        // Mini donut / progress ring
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                                .frame(width: 34, height: 34)
                            Circle()
                                .trim(from: 0, to: principalFraction(month))
                                .stroke(isSelected ? Color.white : DS.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .frame(width: 34, height: 34)
                                .rotationEffect(.degrees(-90))
                            Circle()
                                .trim(from: principalFraction(month), to: 1)
                                .stroke(isSelected ? Color.white.opacity(0.5) : DS.danger.opacity(0.7), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                                .frame(width: 34, height: 34)
                                .rotationEffect(.degrees(-90))

                            if month.isPaid {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isSelected ? .white : Color(hex: "#00C48C"))
                            }
                        }

                        Text("M\(month.monthIndex)")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? DS.primary : (month.isPaid ? DS.primaryLight.opacity(0.5) : Color.white))
                    )
                    .shadow(color: isSelected ? DS.primary.opacity(0.3) : .black.opacity(0.04), radius: isSelected ? 8 : 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Selected Month Detail Card
struct SelectedMonthCard: View {
    let month: AmortisationMonth

    private var dateStr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month.date)
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dateStr)
                        .font(.headline)
                    Text("EMI #\(month.monthIndex) of 18")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if month.isPaid {
                    Label("Paid", systemImage: "checkmark.seal.fill")
                        .font(.caption).bold()
                        .foregroundColor(Color(hex: "#00C48C"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#00C48C").opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Label("Upcoming", systemImage: "clock.fill")
                        .font(.caption).bold()
                        .foregroundColor(.secondaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.primaryLight)
                        .clipShape(Capsule())
                }
            }

            // Breakdown bar
            GeometryReader { geo in
                let total = month.principalPaid + month.interestPaid
                let principalW = geo.size.width * CGFloat(month.principalPaid / total)
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DS.primary)
                        .frame(width: principalW, height: 10)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(DS.danger.opacity(0.7))
                        .frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
                }
            }
            .frame(height: 10)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(DS.primary).frame(width: 8, height: 8)
                        Text("Principal")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    Text("₹\(month.principalPaid.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                        .font(.subheadline).bold().foregroundColor(.mainBlue)
                }
                Spacer()
                VStack(alignment: .center, spacing: 4) {
                    Text("Total EMI")
                        .font(.caption).foregroundColor(.secondary)
                    Text("₹14,200")
                        .font(.subheadline).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Interest")
                            .font(.caption).foregroundColor(.secondary)
                        Circle().fill(DS.danger.opacity(0.7)).frame(width: 8, height: 8)
                    }
                    Text("₹\(month.interestPaid.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                        .font(.subheadline).bold().foregroundColor(.alertRed)
                }
            }

            Divider()

            HStack {
                Text("Remaining Balance")
                    .font(.subheadline).foregroundColor(.secondary)
                Spacer()
                Text("₹\(month.balance.formatted(.number.grouping(.automatic).precision(.fractionLength(2))))")
                    .font(.subheadline).bold()
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Summary Pill
struct SummaryPill: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline).bold()
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct AmortisationScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        AmortisationScheduleView()
    }
}
