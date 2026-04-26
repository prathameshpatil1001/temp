import Foundation
import Combine

// MARK: - Protocol
protocol ApplicationServiceProtocol {
    func fetchApplications() -> AnyPublisher<[LoanApplication], Error>
    func updateStatus(id: UUID, status: ApplicationStatus) -> AnyPublisher<LoanApplication, Error>
}

// MARK: - Mock Service
final class MockApplicationService: ApplicationServiceProtocol {

    static let shared = MockApplicationService()

    private let mockData: [LoanApplication] = [
        LoanApplication(
            id: UUID(),
            leadId: nil,
            name: "Rohit Verma",
            phone: "9900112233",
            loanType: .business,
            loanAmount: 5_000_000,
            status: .underReview,
            createdAt: Date().addingTimeInterval(-172_800),
            updatedAt: Date().addingTimeInterval(-3_600),
            slaDays: 2,
            statusLabel: "2 days left",
            bankName: "HDFC Bank",
            sanctionedAmount: nil,
            disbursedAmount: nil,
            rmName: "Vikram R"
        ),
        LoanApplication(
            id: UUID(),
            leadId: nil,
            name: "Arjun Mehta",
            phone: "9876543210",
            loanType: .home,
            loanAmount: 3_500_000,
            status: .approved,
            createdAt: Date().addingTimeInterval(-432_000),
            updatedAt: Date().addingTimeInterval(-7_200),
            slaDays: nil,
            statusLabel: "Disbursement pending",
            bankName: "SBI",
            sanctionedAmount: 3_500_000,
            disbursedAmount: nil,
            rmName: "Priya S"
        ),
        LoanApplication(
            id: UUID(),
            leadId: nil,
            name: "Kavitha Nair",
            phone: "9844556677",
            loanType: .home,
            loanAmount: 6_000_000,
            status: .rejected,
            createdAt: Date().addingTimeInterval(-604_800),
            updatedAt: Date().addingTimeInterval(-86_400),
            slaDays: nil,
            statusLabel: "Closed",
            bankName: "ICICI Bank",
            sanctionedAmount: nil,
            disbursedAmount: nil,
            rmName: "Priya S"
        ),
        LoanApplication(
            id: UUID(),
            leadId: nil,
            name: "Priya Sharma",
            phone: "9845001234",
            loanType: .personal,
            loanAmount: 800_000,
            status: .disbursed,
            createdAt: Date().addingTimeInterval(-864_000),
            updatedAt: Date().addingTimeInterval(-172_800),
            slaDays: nil,
            statusLabel: "Completed",
            bankName: "Axis Bank",
            sanctionedAmount: 800_000,
            disbursedAmount: 800_000,
            rmName: "Vikram R"
        ),
    ]

    func fetchApplications() -> AnyPublisher<[LoanApplication], Error> {
        Just(mockData)
            .delay(for: .milliseconds(400), scheduler: RunLoop.main)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func updateStatus(id: UUID, status: ApplicationStatus) -> AnyPublisher<LoanApplication, Error> {
        guard var app = mockData.first(where: { $0.id == id }) else {
            return Fail(error: URLError(.badURL)).eraseToAnyPublisher()
        }
        app.status = status
        return Just(app)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}
