import SwiftUI

struct CredibilityScoreOverviewView: View {
    @EnvironmentObject var router: AppRouter
    let score: Int = 724
    
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
                            .trim(from: 0, to: 0.75)
                            .stroke(DS.primaryLight.opacity(0.5), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(135))
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(score) / 900 * 0.75)
                            .stroke(DS.primary, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                            .frame(width: 220, height: 220)
                            .rotationEffect(.degrees(135))
                        
                        VStack(spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(.mainBlue)
                            Text("Good")
                                .font(.headline)
                                .foregroundColor(.secondaryBlue)
                        }
                        .offset(y: -10)
                    }
                    .padding(.top, 40) // FIX: Increased top padding from 20 to 40 to give it proper breathing room
                    
                    VStack(spacing: 8) {
                        Text("You are in the top 20% of users!")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Just 26 more points to unlock Excellent tier.")
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
                            .foregroundColor(Color(hex: "#C0C0C0"))
                        Text("Silver Tier Active")
                            .font(.headline)
                        Spacer()
                        Button {
                            router.push(.benefitsUnlocked)
                        } label: {
                            Text("View All")
                                .font(.subheadline).bold()
                                .foregroundColor(.mainBlue)
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    VStack(spacing: 12) {
                        QuickPerkRow(icon: "percent", title: "1.0% Lower Interest Rates")
                        Divider().padding(.leading, 40)
                        QuickPerkRow(icon: "bolt.fill", title: "Instant Auto-Approvals")
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
        CredibilityScoreOverviewView()
    }
}
