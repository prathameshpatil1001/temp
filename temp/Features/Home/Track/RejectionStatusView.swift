import SwiftUI
import Combine

// MARK: - Models
enum RejectionTrackingStatus {
    case completed
    case rejected
    case pending
}

struct RejectionTimelineStep: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let status: RejectionTrackingStatus
}

// MARK: - View Model
class RejectionStatusViewModel: ObservableObject {
    @Published var loanID = "APP-4011-RX"
    
    @Published var steps: [RejectionTimelineStep] = [
        RejectionTimelineStep(title: "Application Submitted", description: "Documents received.", status: .completed),
        RejectionTimelineStep(title: "Credit Assessment", description: "Application halted during credit review.", status: .rejected),
        RejectionTimelineStep(title: "Loan Approval", description: "Pending approval.", status: .pending)
    ]
}

// MARK: - Main View
struct RejectionStatusView: View {
    @StateObject var viewModel = RejectionStatusViewModel()
    @EnvironmentObject var router: AppRouter // 1. Added AppRouter
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header Profile
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.alertRed)
                    Text("Application Unsuccessful")
                        .font(.title2).bold()
                    Text("ID: \(viewModel.loanID)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // Reason Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                        Text("Reason for Rejection")
                            .font(.headline)
                    }
                    .foregroundColor(.alertRed)
                    
                    Text("Unfortunately, your current credit score does not meet the minimum requirements for this specific loan product. We recommend improving your credit score and reapplying after 90 days.")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineSpacing(4)
                }
                .padding(20)
                .background(DS.danger.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DS.danger.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                
                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                        RejectionTimelineRow(
                            step: step,
                            isLast: index == viewModel.steps.count - 1
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Support Action
                Button {
                    // 2. Route to chat!
                    router.push(.chatConversation(agentName: "Support Agent"))
                } label: {
                    HStack {
                        Image(systemName: "headphones")
                        Text("Contact Support")
                    }
                    .font(.headline)
                    .foregroundColor(.mainBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Status Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents
struct RejectionTimelineRow: View {
    let step: RejectionTimelineStep
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // Left Column: Line & Dot
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(circleColor.opacity(step.status == .rejected ? 0.2 : 1.0))
                        .frame(width: 24, height: 24)
                    
                    if step.status == .rejected {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 12, height: 12)
                    } else if step.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2)
                        .frame(minHeight: 50)
                }
            }
            
            // Right Column: Content
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.headline)
                    .foregroundColor(step.status == .pending ? .secondary : (step.status == .rejected ? .alertRed : .primary))
                
                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer().frame(height: 20)
            }
            .padding(.top, 2)
        }
    }
    
    private var circleColor: Color {
        switch step.status {
        case .completed: return Color(hex: "#00C48C")
        case .rejected: return .alertRed
        case .pending: return Color.gray.opacity(0.3)
        }
    }
    
    private var lineColor: Color {
        switch step.status {
        case .completed: return Color(hex: "#00C48C")
        case .rejected, .pending: return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    NavigationStack {
        RejectionStatusView()
            .environmentObject(AppRouter())
    }
}
