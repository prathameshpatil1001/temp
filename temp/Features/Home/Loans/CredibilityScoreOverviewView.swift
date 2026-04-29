import SwiftUI

struct CredibilityScoreOverviewView: View {
    @EnvironmentObject var router: AppRouter
    let score: Int

    // Product guideline mapping:
    // 300-649: High Risk, 650-699: Bronze, 700-749: Silver, 750-799: Gold, 800-900: Platinum
    private var scoreTier: CreditTier {
        CreditTier.from(score: score)
    }

    private var scoreLabel: String {
        scoreTier.label
    }

    private var scoreColor: Color {
        scoreTier.color
    }

    private var headlineText: String {
        switch scoreTier {
        case .highRisk:
            return "Let's improve your score steadily."
        case .bronze:
            return "You are building strong credit momentum!"
        case .silver:
            return "You are in the top 20% of users!"
        case .gold:
            return "Excellent progress - you're among top borrowers!"
        case .platinum:
            return "Outstanding! You are a premium borrower."
        }
    }

    private var progressText: String {
        let next = scoreTier.nextTierMinimum
        let safeScore = max(300, min(900, score))
        guard let next else { return "You've unlocked the highest tier benefits." }
        let delta = max(next - safeScore, 0)
        return "Just \(delta) more points to unlock \(scoreTier.nextTierName ?? "next") tier."
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score Overview")
                        .font(.largeTitle).bold()
                    Text("Detailed snapshot of your financial health.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Immersive Gauge Card
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(DS.primaryLight.opacity(0.5), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                            .frame(width: 220, height: 220)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 900)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(-90))
                        
                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(scoreColor)
                            Text(scoreLabel)
                                .font(.headline)
                                .foregroundColor(scoreColor.opacity(0.9))
                        }
                    }
                    .padding(.top, 40) // FIX: Increased top padding from 20 to 40 to give it proper breathing room
                    
                    VStack(spacing: 8) {
                        Text(headlineText)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(progressText)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 40) // FIX: Matched bottom padding to 40 for perfect vertical balance
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                
                // Current Tier & Benefits Snapshot
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "medal.fill")
                            .font(.title2)
                            .foregroundColor(scoreTier.medalColor)
                        Text("\(scoreTier.tierName) Tier Active")
                            .font(.headline)
                        Spacer()
                        Button {
                            router.push(.benefitsUnlocked(score: score))
                        } label: {
                            Text("View All")
                                .font(.subheadline).bold()
                                .foregroundColor(.mainBlue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        QuickPerkRow(icon: "percent", title: scoreTier.quickPerkOne)
                        Divider().padding(.leading, 40)
                        QuickPerkRow(icon: "bolt.fill", title: scoreTier.quickPerkTwo)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
                
                // Quick Tip
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(Color(hex: "#00C48C"))
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keep it up!")
                            .font(.headline)
                        Text("Maintaining your current EMI schedule without missed payments will naturally boost your score over the next 3 months.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                }
                .padding(20)
                .background(Color(hex: "#00C48C").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#00C48C").opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct QuickPerkRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.mainBlue)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

struct CredibilityScoreOverviewView_Previews: PreviewProvider {
    static var previews: some View {
        CredibilityScoreOverviewView(score: 724)
    }
}

private enum CreditTier {
    case highRisk
    case bronze
    case silver
    case gold
    case platinum

    static func from(score: Int) -> CreditTier {
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

    var label: String {
        switch self {
        case .highRisk: return "Poor"
        case .bronze: return "Fair"
        case .silver: return "Good"
        case .gold: return "Very Good"
        case .platinum: return "Excellent"
        }
    }

    var color: Color {
        switch self {
        case .highRisk: return DS.danger
        default: return Color(hex: "#00C48C")
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

    var nextTierMinimum: Int? {
        switch self {
        case .highRisk: return 650
        case .bronze: return 700
        case .silver: return 750
        case .gold: return 800
        case .platinum: return nil
        }
    }

    var nextTierName: String? {
        switch self {
        case .highRisk: return "Bronze"
        case .bronze: return "Silver"
        case .silver: return "Gold"
        case .gold: return "Platinum"
        case .platinum: return nil
        }
    }

    var quickPerkOne: String {
        switch self {
        case .highRisk: return "Rate optimization tips available"
        case .bronze: return "Up to 0.5% lower interest rates"
        case .silver: return "1.0% Lower Interest Rates"
        case .gold: return "Up to 2.0% lower interest rates"
        case .platinum: return "Best-in-class interest rates"
        }
    }

    var quickPerkTwo: String {
        switch self {
        case .highRisk: return "Guided approval review support"
        case .bronze: return "Faster manual approvals"
        case .silver: return "Instant Auto-Approvals"
        case .gold: return "Instant approvals with higher limits"
        case .platinum: return "Priority instant approvals"
        }
    }
}
