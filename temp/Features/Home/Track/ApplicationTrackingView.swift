import SwiftUI
import Combine

// MARK: - Models
enum TrackingStatus {
    case completed
    case current
    case pending
}

struct TimelineStepItem: Identifiable {
    let id = UUID()
    let title: String
    let date: String?
    let description: String
    let status: TrackingStatus
}

// MARK: - View Model
class ApplicationTrackingViewModel: ObservableObject {
    @Published var loanID = "APP-9824-XT"
    @Published var amount = 150000.0
    
    @Published var steps: [TimelineStepItem] = [
        TimelineStepItem(title: "Application Submitted", date: "14 Apr, 10:30 AM", description: "Your application and documents have been received.", status: .completed),
        TimelineStepItem(title: "Document Verification", date: "14 Apr, 02:15 PM", description: "Our team has successfully verified your identity and income.", status: .completed),
        TimelineStepItem(title: "Credit Assessment", date: "In Progress", description: "We are currently evaluating your credit profile.", status: .current),
        TimelineStepItem(title: "Loan Approval", date: nil, description: "Final approval pending from the underwriting team.", status: .pending),
        TimelineStepItem(title: "Amount Disbursed", date: nil, description: "Funds will be transferred to your registered bank account.", status: .pending)
    ]
}

// MARK: - Main View
struct ApplicationTrackingView: View {
    @StateObject var viewModel = ApplicationTrackingViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Summary Card
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Application ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.loanID)
                            .font(.headline)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("Applied Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("₹\(viewModel.amount.formatted(.number.grouping(.automatic)))")
                            .font(.headline)
                            .foregroundColor(.mainBlue)
                    }
                }
                .padding(20)
                .background(DS.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DS.primary.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Timeline
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                        TimelineRow(
                            step: step,
                            isLast: index == viewModel.steps.count - 1
                        )
                    }
                }
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationTitle("Track Status")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents
struct TimelineRow: View {
    let step: TimelineStepItem
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // Left Column: Line & Dot
            VStack(spacing: 0) {
                // Circle Indicator
                ZStack {
                    Circle()
                        .fill(circleColor.opacity(step.status == .current ? 0.2 : 1.0))
                        .frame(width: 24, height: 24)
                    
                    if step.status == .current {
                        Circle()
                            .fill(circleColor)
                            .frame(width: 12, height: 12)
                    } else if step.status == .completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                // Vertical Line (Hide if last item)
                if !isLast {
                    Rectangle()
                        .fill(lineColor)
                        .frame(width: 2)
                        .frame(minHeight: 60) // Adjusts spacing between steps
                }
            }
            
            // Right Column: Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(step.title)
                        .font(.headline)
                        .foregroundColor(step.status == .pending ? .secondary : .primary)
                    Spacer()
                    if let date = step.date {
                        Text(date)
                            .font(.caption2).bold()
                            .foregroundColor(step.status == .current ? .secondaryBlue : .secondary)
                    }
                }
                
                Text(step.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Extra padding at the bottom of the text block to match the line height
                Spacer().frame(height: 20)
            }
            .padding(.top, 2) // Aligns text slightly down with the circle
        }
    }
    
    // Computed colors based on status
    private var circleColor: Color {
        switch step.status {
        case .completed: return Color(hex: "#00C48C") // Success Green
        case .current: return .mainBlue
        case .pending: return Color.gray.opacity(0.3)
        }
    }
    
    private var lineColor: Color {
        switch step.status {
        case .completed: return Color(hex: "#00C48C")
        case .current, .pending: return Color.gray.opacity(0.2)
        }
    }
}

#Preview {
    NavigationStack {
        ApplicationTrackingView()
    }
}
