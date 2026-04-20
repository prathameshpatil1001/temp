import SwiftUI

struct BenefitsUnlockedView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlocked Benefits")
                        .font(.largeTitle).bold()
                    Text("Your Good score (724) earns you these perks.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Tier Card
                HStack(spacing: 20) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#C0C0C0")) // Silver color
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Silver Tier")
                            .font(.title3).bold()
                        Text("Reach 750 for Gold Tier")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
                // Perks List
                VStack(spacing: 16) {
                    BenefitCard(icon: "percent", title: "Reduced Interest Rates", desc: "Enjoy 1.0% lower interest rates on all new personal loans.", isUnlocked: true)
                    BenefitCard(icon: "bolt.fill", title: "Instant Approvals", desc: "Loans up to ₹5,00,000 are auto-approved without manual checks.", isUnlocked: true)
                    BenefitCard(icon: "airplane.departure", title: "Zero Processing Fees", desc: "Pay absolutely zero processing fees on auto loans.", isUnlocked: false) // Locked perk to tease them
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BenefitCard: View {
    let icon: String
    let title: String
    let desc: String
    let isUnlocked: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: isUnlocked ? icon : "lock.fill")
                .font(.title2)
                .foregroundColor(isUnlocked ? .mainBlue : .secondary)
                .frame(width: 48, height: 48)
                .background(isUnlocked ? Color.lightBlue : Color.secondary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline).bold()
                    .foregroundColor(isUnlocked ? .primary : .secondary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? Color.mainBlue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}
