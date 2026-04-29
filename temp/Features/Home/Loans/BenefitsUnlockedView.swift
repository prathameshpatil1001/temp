import SwiftUI

struct BenefitsUnlockedView: View {
    let score: Int

    private var tier: BenefitTier {
        BenefitTier.from(score: score)
    }

    private var subtitle: String {
        "Your \(tier.scoreLabel) score (\(score)) earns you these perks."
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlocked Benefits")
                        .font(.largeTitle).bold()
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Tier Card
                HStack(spacing: 20) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 56))
                        .foregroundColor(tier.medalColor)
                        .shadow(color: tier.medalColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(tier.tierName) Tier")
                            .font(.title2).bold()
                            .foregroundColor(.primary)
                        Text(tier.nextTierText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                .background(
                    ZStack {
                        Color.white
                        LinearGradient(
                            colors: [tier.medalColor.opacity(0.15), Color.white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [tier.medalColor.opacity(0.6), tier.medalColor.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: tier.medalColor.opacity(0.15), radius: 12, x: 0, y: 6)
                .padding(.horizontal, 20)
                
                // Perks List
                VStack(spacing: 16) {
                    ForEach(tier.benefits) { benefit in
                        BenefitCard(
                            icon: benefit.icon,
                            title: benefit.title,
                            desc: benefit.description,
                            isUnlocked: benefit.isUnlocked
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TierBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let isUnlocked: Bool
}

private enum BenefitTier {
    case highRisk
    case bronze
    case silver
    case gold
    case platinum

    static func from(score: Int) -> BenefitTier {
        switch score {
        case 800...: return .platinum
        case 750..<800: return .gold
        case 700..<750: return .silver
        case 650..<700: return .bronze
        default: return .highRisk
        }
    }

    var tierName: String {
        switch self {
        case .highRisk: return "High Risk"
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var scoreLabel: String {
        switch self {
        case .highRisk: return "Poor"
        case .bronze: return "Fair"
        case .silver: return "Good"
        case .gold: return "Very Good"
        case .platinum: return "Excellent"
        }
    }

    var medalColor: Color {
        switch self {
        case .highRisk: return DS.danger
        case .bronze: return Color(hex: "#CD7F32")
        case .silver: return Color(hex: "#C0C0C0")
        case .gold: return Color(hex: "#D4AF37")
        case .platinum: return Color(hex: "#B9F2FF")
        }
    }

    var nextTierText: String {
        switch self {
        case .highRisk: return "Reach 650 for Bronze Tier"
        case .bronze: return "Reach 700 for Silver Tier"
        case .silver: return "Reach 750 for Gold Tier"
        case .gold: return "Reach 800 for Platinum Tier"
        case .platinum: return "You have unlocked all tiers"
        }
    }

    // Product guideline mapping:
    // Bronze 650-699, Silver 700-749, Gold 750-799, Platinum 800+, else High Risk
    var benefits: [TierBenefit] {
        switch self {
        case .highRisk:
            return [
                TierBenefit(icon: "book.fill", title: "Credit Improvement Plan", description: "Get tailored repayment and utilization tips to improve approval chances.", isUnlocked: true),
                TierBenefit(icon: "person.text.rectangle", title: "Guided Manual Review", description: "Applications are reviewed manually with additional support.", isUnlocked: true),
                TierBenefit(icon: "percent", title: "Reduced Interest Rates", description: "Upgrade to Bronze tier to unlock better pricing.", isUnlocked: false)
            ]
        case .bronze:
            return [
                TierBenefit(icon: "percent", title: "Reduced Interest Rates", description: "Enjoy up to 0.5% lower rates on select products.", isUnlocked: true),
                TierBenefit(icon: "clock.badge.checkmark", title: "Faster Approvals", description: "Priority in manual underwriting queues.", isUnlocked: true),
                TierBenefit(icon: "bolt.fill", title: "Instant Approvals", description: "Reach Silver to unlock instant approvals.", isUnlocked: false)
            ]
        case .silver:
            return [
                TierBenefit(icon: "percent", title: "Reduced Interest Rates", description: "Enjoy 1.0% lower interest rates on all new personal loans.", isUnlocked: true),
                TierBenefit(icon: "bolt.fill", title: "Instant Approvals", description: "Loans up to ₹5,00,000 are auto-approved without manual checks.", isUnlocked: true),
                TierBenefit(icon: "airplane.departure", title: "Zero Processing Fees", description: "Reach Gold to unlock lower or zero processing fees on select products.", isUnlocked: false)
            ]
        case .gold:
            return [
                TierBenefit(icon: "percent", title: "Reduced Interest Rates", description: "Enjoy up to 2.0% lower rates on eligible loans.", isUnlocked: true),
                TierBenefit(icon: "bolt.fill", title: "Higher Instant Approval Limit", description: "Auto-approvals available at higher ticket sizes.", isUnlocked: true),
                TierBenefit(icon: "creditcard.fill", title: "Lower Processing Fees", description: "Processing fees are reduced for most products.", isUnlocked: true)
            ]
        case .platinum:
            return [
                TierBenefit(icon: "percent", title: "Best Interest Rates", description: "Get top-tier pricing across eligible products.", isUnlocked: true),
                TierBenefit(icon: "bolt.fill", title: "Priority Instant Approvals", description: "Fastest sanction turnaround with highest limits.", isUnlocked: true),
                TierBenefit(icon: "star.fill", title: "Zero Processing Fees", description: "Enjoy zero processing fees on selected loan categories.", isUnlocked: true)
            ]
        }
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
                .background(isUnlocked ? DS.primaryLight : Color.secondary.opacity(0.1))
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
            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isUnlocked ? DS.primary.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .opacity(isUnlocked ? 1.0 : 0.6)
    }
}

#Preview {
    BenefitsUnlockedView(score: 724)
}
