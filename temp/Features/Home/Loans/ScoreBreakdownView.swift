import SwiftUI

struct ScoreBreakdownView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score Breakdown")
                        .font(.largeTitle).bold()
                    Text("The key factors influencing your 724 score.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Factors
                VStack(spacing: 20) {
                    FactorRow(title: "Repayment History", impact: "High Impact", value: "100%", color: Color(hex: "#00C48C"), progress: 1.0)
                    FactorRow(title: "Credit Utilization", impact: "High Impact", value: "28%", color: Color(hex: "#00C48C"), progress: 0.8)
                    FactorRow(title: "Credit Age", impact: "Medium Impact", value: "2.4 Yrs", color: .secondaryBlue, progress: 0.6)
                    FactorRow(title: "Recent Enquiries", impact: "Low Impact", value: "3", color: .alertRed, progress: 0.3)
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Improvement Tips Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(Color(hex: "#00C48C"))
                        Text("Improvement Tips")
                            .font(.headline)
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 16) {
                        TipCard(icon: "creditcard.trianglebadge.exclamationmark", title: "Limit Recent Enquiries", desc: "You have 3 recent hard inquiries. Avoid applying for new credit for the next 6 months to see a bump in your score.")
                        TipCard(icon: "arrow.down.circle.fill", title: "Keep Utilization Below 30%", desc: "You are currently at 28%. Keeping this under 30% is excellent for maintaining a high score.")
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FactorRow: View {
    let title: String
    let impact: String
    let value: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(impact).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Text(value).font(.subheadline).bold().foregroundColor(color)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.1)).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4).fill(color).frame(width: geo.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

struct TipCard: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondaryBlue)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline).bold()
                Text(desc).font(.caption).foregroundColor(.secondary).lineSpacing(4)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
