import SwiftUI

struct OutstandingBalanceView: View {
    let principalRemaining: Double = 312000
    let accruedInterest: Double = 2730
    let lateFees: Double = 0
    let foreclosurePenaltyPercent: Double = 2.0
    
    var totalDuesToday: Double { principalRemaining + accruedInterest + lateFees }
    var foreclosureAmount: Double { totalDuesToday + (principalRemaining * (foreclosurePenaltyPercent/100)) }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Outstanding Balance")
                        .font(.largeTitle).bold()
                    Text("Detailed breakdown of your current dues.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Current Dues Card
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("Total Due As of Today")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("₹\(totalDuesToday.formatted(.number.grouping(.automatic)))")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.alertRed)
                    }
                    .padding(24)
                    
                    Divider()
                    
                    VStack(spacing: 16) {
                        OutstandingRow(title: "Principal Remaining", value: principalRemaining)
                        OutstandingRow(title: "Interest Accrued (This month)", value: accruedInterest)
                        OutstandingRow(title: "Late Fees & Charges", value: lateFees)
                    }
                    .padding(20)
                    .background(DS.primaryLight.opacity(0.3))
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Foreclosure Box
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lock.open.fill")
                            .foregroundColor(.mainBlue)
                        Text("Foreclosure Quote")
                            .font(.headline)
                    }
                    
                    Text("If you wish to close this loan entirely today, a \(foreclosurePenaltyPercent, specifier: "%.1f")% foreclosure charge applies to the remaining principal.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Final Settlement Amount")
                            .font(.subheadline).bold()
                        Spacer()
                        Text("₹\(foreclosureAmount.formatted(.number.grouping(.automatic)))")
                            .font(.title3).bold()
                            .foregroundColor(.mainBlue)
                    }
                    .padding(16)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    Button {
                        // Action to initiate foreclosure
                    } label: {
                        Text("Initiate Foreclosure")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(DS.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
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

struct OutstandingRow: View {
    let title: String
    let value: Double
    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text("₹\(value.formatted(.number.grouping(.automatic)))").font(.subheadline).bold()
        }
    }
}
