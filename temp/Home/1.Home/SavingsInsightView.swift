import SwiftUI

struct SavingsInsightView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Savings Insights")
                        .font(.largeTitle).bold()
                    Text("You're making great financial decisions.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Hero Graphic
                ZStack {
                    Circle()
                        .fill(Color(hex: "#00C48C").opacity(0.15))
                        .frame(width: 180, height: 180)
                    
                    VStack(spacing: 4) {
                        Text("₹12,450")
                            .font(.system(size: 34, weight: .heavy))
                            .foregroundColor(Color(hex: "#00C48C"))
                        Text("Total Saved")
                            .font(.subheadline).bold()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 20)
                
                // Stats Grid
                VStack(spacing: 16) {
                    InsightRow(icon: "clock.fill", title: "No Late Fees", description: "Paid on time for 14 months.", color: .mainBlue)
                    InsightRow(icon: "arrow.down.right.circle.fill", title: "Prepayment Savings", description: "Saved ₹9,200 by paying extra.", color: Color(hex: "#00C48C"))
                    InsightRow(icon: "percent", title: "Low Rate Secured", description: "You locked in 1.5% below market avg.", color: .secondaryBlue)
                }
                .padding(.horizontal, 20)
                
                // Call to Action
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keep it up!")
                        .font(.headline)
                    Text("Maintaining this streak will unlock lower interest rates for your next loan application.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.lightBlue)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

struct SavingsInsightView_Previews: PreviewProvider {
    static var previews: some View {
        SavingsInsightView()
    }
}
