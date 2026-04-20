import SwiftUI

struct ActiveLoanDetailsView: View {
    @EnvironmentObject var router: Router
    
    let totalLoan: Double = 500000
    let paidAmount: Double = 188000
    var outstandingBalance: Double { totalLoan - paidAmount }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loan Details")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                    Text("Personal Loan • APP-9824-XT")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Main Balance Card
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text("Outstanding Balance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(outstandingBalance.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.mainBlue)
                    }
                    
                    // Progress
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 6).fill(Color.lightBlue).frame(height: 12)
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(LinearGradient(colors: [.mainBlue, .secondaryBlue], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * (paidAmount / totalLoan), height: 12)
                            }
                        }
                        .frame(height: 12)
                        
                        HStack {
                            Text("₹\(paidAmount.formatted(.number.notation(.compactName))) Paid")
                                .font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("₹\(totalLoan.formatted(.number.notation(.compactName))) Total")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(24)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Action Grid
                HStack(spacing: 16) {
                    LoanActionTile(icon: "chart.bar.doc.horizontal", title: "Amortisation\nSchedule") {
                        router.push(.amortisationSchedule)
                    }
                    LoanActionTile(icon: "indianrupeesign.circle", title: "Outstanding\nBreakdown") {
                        router.push(.outstandingBalance)
                    }
                }
                .padding(.horizontal, 20)
                
                // NEW: Smart Financial Tools Section
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
                
                // Detailed Info List
                VStack(spacing: 0) {
                    InfoListRow(title: "Interest Rate", value: "10.5% p.a.")
                    Divider().padding(.leading, 20)
                    InfoListRow(title: "Monthly EMI", value: "₹14,200")
                    Divider().padding(.leading, 20)
                    InfoListRow(title: "Tenure Remaining", value: "18 Months")
                    Divider().padding(.leading, 20)
                    InfoListRow(title: "Next EMI Date", value: "20 Apr 2026")
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Chat with Loan Officer Button
                Button {
                    router.push(.chatConversation(agentName: "Rajesh K."))
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Chat with Loan Officer")
                    }
                    .font(.headline)
                    .foregroundColor(.mainBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.lightBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
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
                    .background(Color.lightBlue)
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
