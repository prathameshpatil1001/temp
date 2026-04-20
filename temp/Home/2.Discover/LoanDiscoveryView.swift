import SwiftUI
import Combine

// MARK: - Models
struct LoanProduct: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let maxAmount: Double
    let interestRate: String
    let minTenure: Int
    let maxTenure: Int
    let tags: [String]
}

// MARK: - View Model
class LoanMarketplaceViewModel: ObservableObject {
    @Published var availableLoans: [LoanProduct] = [
        LoanProduct(title: "Personal Loan", icon: "person.text.rectangle", maxAmount: 500000, interestRate: "10.5%", minTenure: 6, maxTenure: 60, tags: ["Instant Approval", "No Collateral"]),
        LoanProduct(title: "Home Renovation", icon: "house.and.flag", maxAmount: 1500000, interestRate: "8.5%", minTenure: 12, maxTenure: 120, tags: ["Low Interest", "Tax Benefits"]),
        LoanProduct(title: "Education Loan", icon: "graduationcap", maxAmount: 2000000, interestRate: "9.0%", minTenure: 12, maxTenure: 84, tags: ["Flexible Repayment"]),
        LoanProduct(title: "Auto Loan", icon: "car", maxAmount: 1000000, interestRate: "9.5%", minTenure: 12, maxTenure: 60, tags: ["Quick Disbursal"])
    ]
}

// MARK: - Marketplace Screen (Feature 4.1)
struct LoanMarketplaceView: View {
    @StateObject var viewModel = LoanMarketplaceViewModel()
    @EnvironmentObject var router: Router
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loan Marketplace")
                        .font(.largeTitle).bold()
                        .foregroundColor(.primary)
                    Text("Find the perfect loan for your needs.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Loan Cards List
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.availableLoans) { loan in
                        Button {
                            router.push(.loanDetail(loan))
                        } label: {
                            LoanProductCard(loan: loan)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

// MARK: - Loan Product Card
struct LoanProductCard: View {
    let loan: LoanProduct
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Icon
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.lightBlue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: loan.icon)
                            .font(.title2)
                            .foregroundColor(.mainBlue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.title)
                        .font(.headline)
                    Text("Starting at \(loan.interestRate) p.a.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary.opacity(0.5))
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Up to")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("₹\(loan.maxAmount.formatted(.number.grouping(.automatic)))")
                        .font(.subheadline).bold()
                        .foregroundColor(.mainBlue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tenure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(loan.minTenure)-\(loan.maxTenure) months")
                        .font(.subheadline).bold()
                }
            }
            
            // Tags
            HStack(spacing: 8) {
                ForEach(loan.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2).bold()
                        .foregroundColor(.secondaryBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.lightBlue.opacity(0.5))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Loan Detail Screen (Feature 4.2 & 4.4)
struct LoanDetailScreen: View {
    let loan: LoanProduct
    @EnvironmentObject var router: Router
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Top Hero Section
                    VStack(spacing: 16) {
                        Circle()
                            .fill(Color.lightBlue)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: loan.icon)
                                    .font(.system(size: 36))
                                    .foregroundColor(.mainBlue)
                            )
                        
                        Text(loan.title)
                            .font(.title).bold()
                        
                        HStack(spacing: 24) {
                            DetailHighlight(title: "Max Amount", value: "₹\(loan.maxAmount.formatted(.number.grouping(.automatic)))")
                            DetailHighlight(title: "Interest", value: "From \(loan.interestRate)")
                        }
                    }
                    .padding(.top, 20)
                    
                    // Comparison & Eligibility Buttons
                    HStack(spacing: 16) {
                        Button {
                            router.push(.loanComparison(loan))
                        } label: {
                            HStack {
                                Image(systemName: "arrow.left.arrow.right")
                                Text("Compare Options")
                            }
                            .font(.subheadline).bold()
                            .foregroundColor(.mainBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.lightBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Button {
                            router.push(.eligibilityChecker(loan))
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.shield")
                                Text("Check Eligibility")
                            }
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondaryBlue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Features List Placeholder
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features & Benefits")
                            .font(.headline)
                        
                        FeatureRow(icon: "clock.fill", title: "Quick Disbursal", subtitle: "Money in your account within 24 hours of approval.")
                        FeatureRow(icon: "doc.text.fill", title: "Minimal Documentation", subtitle: "100% paperless process.")
                        FeatureRow(icon: "percent", title: "Flexible Repayment", subtitle: "Choose an EMI that fits your budget.")
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100) // Padding for sticky bottom button
                }
            }
            
            // Sticky Bottom Button
            VStack {
                Divider()
                Button {
                    router.push(.startApplication(loan)) // Pushes the selected loan type into the application
                } label: {
                    Text("Apply Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.mainBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Subcomponents for Detail Screen
struct DetailHighlight: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(.mainBlue)
        }
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.secondaryBlue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline).bold()
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    ContentView()
}
