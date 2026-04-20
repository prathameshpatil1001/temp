import SwiftUI
import Combine

// MARK: - View Model
class ReviewApplicationViewModel: ObservableObject {
    @Published var loanAmount: Double = 150000
    @Published var tenureMonths: Int = 24
    @Published var estimatedEMI: Double = 6961
    @Published var interestRate: Double = 10.5
    
    @Published var documents: [String] = ["PAN Card", "Aadhaar Card", "Bank Statement", "Salary Slip"]
    
    @Published var isConsentGiven = false
}

// MARK: - Main View
struct ReviewApplicationView: View {
    @StateObject var viewModel = ReviewApplicationViewModel()
    @EnvironmentObject var router: Router
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Text("Review Details")
                            .font(.largeTitle).bold()
                        Text("Please verify your information before final submission.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    // Loan Summary Card
                    ReviewSectionCard(title: "Loan Details", actionTitle: "Edit") {
                        VStack(spacing: 16) {
                            ReviewDataRow(label: "Loan Amount", value: "₹\(viewModel.loanAmount.formatted(.number.grouping(.automatic)))")
                            ReviewDataRow(label: "Tenure", value: "\(viewModel.tenureMonths) Months")
                            
                            ReviewDataRow(label: "Interest Rate", value: String(format: "%.1f%% p.a.", viewModel.interestRate))
                            
                            Divider()
                            ReviewDataRow(label: "Estimated EMI", value: "₹\(viewModel.estimatedEMI.formatted(.number.grouping(.automatic)))", isHighlight: true)
                        }
                    }
                    
                    // Documents Summary Card
                    ReviewSectionCard(title: "Documents", actionTitle: "Edit") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.documents, id: \.self) { doc in
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundColor(Color(hex: "#00C48C"))
                                    Text(doc)
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                    // Custom Centered Consent UI
                    HStack(alignment: .center, spacing: 12) {
                        Button {
                            viewModel.isConsentGiven.toggle()
                        } label: {
                            Image(systemName: viewModel.isConsentGiven ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundColor(viewModel.isConsentGiven ? .mainBlue : .secondary)
                        }
                        
                        Text("I hereby declare that the information provided is true and correct. I authorize the platform to pull my credit report for assessment purposes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100)
                }
            }
            
            // Sticky Submit Button
            VStack {
                Divider()
                Button {
                    router.push(.submitConfirmation)
                } label: {
                    Text("Confirm & Submit")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.isConsentGiven ? Color.mainBlue : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!viewModel.isConsentGiven)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents
struct ReviewSectionCard<Content: View>: View {
    let title: String
    let actionTitle: String
    let content: Content
    
    init(title: String, actionTitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.actionTitle = actionTitle
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(actionTitle) {
                    // Edit action
                }
                .font(.subheadline).bold()
                .foregroundColor(.mainBlue)
            }
            
            content
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

struct ReviewDataRow: View {
    let label: String
    let value: String
    var isHighlight: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(isHighlight ? .title3 : .subheadline)
                .fontWeight(isHighlight ? .bold : .semibold)
                .foregroundColor(isHighlight ? .mainBlue : .primary)
        }
    }
}

#Preview {
    NavigationStack {
        ReviewApplicationView()
            .environmentObject(Router())
    }
}
