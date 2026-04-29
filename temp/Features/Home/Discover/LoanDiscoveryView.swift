import SwiftUI

@available(iOS 18.0, *)
struct LoanMarketplaceView: View {
    @StateObject private var viewModel = DiscoverViewModel(service: ServiceContainer.loanService)
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Apply for Loan")
                        .font(.largeTitle).bold()
                    Text("Find the right loan product from live backend data.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                if viewModel.isLoading && viewModel.products.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                } else if let error = viewModel.errorMessage, viewModel.products.isEmpty {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            viewModel.fetchProducts()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.products) { product in
                            Button {
                                router.push(.loanDetail(product))
                            } label: {
                                LoanProductCard(product: product)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .task {
            if viewModel.products.isEmpty {
                viewModel.fetchProducts()
            }
        }
    }
}

@available(iOS 18.0, *)
struct LoanProductCard: View {
    let product: LoanProduct

    private var rateText: String {
        let rate = Double(product.baseInterestRate) ?? 0
        return String(format: "%.2f%%", rate)
    }

    private var amountText: String {
        formatCurrency(product.maxAmount)
    }

    private var tenureText: String {
        "Flexible"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(DS.primaryLight)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: product.category.icon)
                            .font(.title2)
                            .foregroundColor(.mainBlue)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Starting at \(rateText) p.a.")
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
                    Text(amountText)
                        .font(.subheadline).bold()
                        .foregroundColor(.mainBlue)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Tenure")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(tenureText)
                        .font(.subheadline).bold()
                }
            }

            HStack(spacing: 8) {
                Text(product.category.displayName)
                    .font(.caption2).bold()
                    .foregroundColor(.secondaryBlue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DS.primaryLight.opacity(0.5))
                    .clipShape(Capsule())

                if product.isRequiringCollateral {
                    Text("Collateral")
                        .font(.caption2).bold()
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}

@available(iOS 18.0, *)
struct LoanDetailScreen: View {
    let loan: LoanProduct
    @EnvironmentObject private var router: AppRouter

    private var maxAmountText: String {
        formatCurrency(loan.maxAmount)
    }

    private var rateText: String {
        let rate = Double(loan.baseInterestRate) ?? 0
        return String(format: "%.2f%%", rate)
    }

    private var processingFeeText: String {
        guard let fee = loan.fees.first(where: { $0.type == .processing }) else {
            return "N/A"
        }
        
        switch fee.calcMethod {
        case .flat:
            return formatCurrency(fee.value)
        case .percentage:
            return "\(fee.value)%"
        default:
            return "N/A"
        }
    }

    private var eligibilityTitle: String {
        loan.isActive ? "Eligible" : "Not Eligible"
    }

    private var eligibilityIcon: String {
        loan.isActive ? "checkmark.shield.fill" : "xmark.shield.fill"
    }

    private var eligibilityBackground: Color {
        loan.isActive ? Color(hex: "#00C48C").opacity(0.14) : DS.danger.opacity(0.12)
    }

    private var eligibilityForeground: Color {
        loan.isActive ? Color(hex: "#00A86B") : DS.danger
    }

    private var primaryCTAButtonTitle: String {
        loan.name == "Home" ? "Ask Query" : "Apply Now"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Circle()
                            .fill(DS.primaryLight)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: loan.category.icon)
                                    .font(.system(size: 36))
                                    .foregroundColor(.mainBlue)
                            )

                        Text(loan.name)
                            .font(.title).bold()

                        HStack(spacing: 12) {
                            DetailHighlight(title: "Max Amount", value: maxAmountText)
                            DetailHighlight(title: "Interest", value: "From \(rateText)")
                            DetailHighlight(title: "Proc. Fee", value: processingFeeText)
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)

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
                            .background(DS.primaryLight)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        HStack(spacing: 8) {
                            Image(systemName: eligibilityIcon)
                            Text(eligibilityTitle)
                        }
                        .font(.subheadline).bold()
                        .foregroundColor(eligibilityForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(eligibilityBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Features & Benefits")
                            .font(.headline)

                        FeatureRow(icon: "clock.fill", title: "Fast Processing", subtitle: "Application moves to review as soon as your docs are uploaded.")
                        FeatureRow(icon: "doc.text.fill", title: "Product-Based Documents", subtitle: "Required documents are loaded from this product's backend configuration.")
                        FeatureRow(icon: "percent", title: "Transparent Pricing", subtitle: "Rate and fee settings are fetched from backend product terms.")
                    }
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 100)
                }
            }

            VStack {
                Divider()
                Button {
                    router.push(.startApplication(loan))
                } label: {
                    Text(primaryCTAButtonTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}

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
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
