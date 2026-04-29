import SwiftUI
import Combine

@MainActor
@available(iOS 18.0, *)
final class TrackViewModel: ObservableObject {
    @Published var applications: [BorrowerLoanApplication] = []
    @Published var selectedApplication: BorrowerLoanApplication? = nil
    @Published var isLoading: Bool = false
    @Published var isAcceptingSanctionLetter: Bool = false
    @Published var errorMessage: String? = nil

    private let service: LoanServiceProtocol

    init(service: LoanServiceProtocol = ServiceContainer.loanService) {
        self.service = service
    }

    func fetchApplications() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let fetched = try await service.listLoanApplications(limit: 50, offset: 0)
                applications = try await reconcileSanctionLetterStates(in: fetched)
                if selectedApplication == nil {
                    selectedApplication = applications.first
                }
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to load"
            }
            isLoading = false
        }
    }

    func fetchApplicationDetail(applicationId: String) {
        Task {
            do {
                let fetched = try await service.getLoanApplication(applicationId: applicationId)
                let detail = try await reconcileSanctionLetterState(fetched)
                applyUpdatedApplication(detail)
            } catch {
                errorMessage = "Failed to load application detail"
            }
        }
    }

    func acceptSanctionLetter(for application: BorrowerLoanApplication) async throws -> BorrowerLoanApplication {
        isAcceptingSanctionLetter = true
        errorMessage = nil
        defer { isAcceptingSanctionLetter = false }

        do {
            _ = try await service.createLoan(
                applicationId: application.id,
                principalAmount: application.requestedAmount
            )
        } catch let error as LoanError {
            switch error {
            case .preconditionFailed(let message) where message.localizedCaseInsensitiveContains("loan already exists"):
                break
            default:
                throw error
            }
        } catch {
            throw error
        }

        var refreshed = try await service.getLoanApplication(applicationId: application.id)
        if refreshed.status != .disbursed {
            try await service.updateLoanApplicationStatus(
                applicationId: application.id,
                status: .disbursed,
                escalationReason: nil
            )
            refreshed = try await service.getLoanApplication(applicationId: application.id)
        }

        applyUpdatedApplication(refreshed)
        return refreshed
    }

    private func applyUpdatedApplication(_ application: BorrowerLoanApplication) {
        if let idx = applications.firstIndex(where: { $0.id == application.id }) {
            applications[idx] = application
        }
        selectedApplication = application
    }

    private func reconcileSanctionLetterStates(
        in applications: [BorrowerLoanApplication]
    ) async throws -> [BorrowerLoanApplication] {
        try await withThrowingTaskGroup(of: (Int, BorrowerLoanApplication).self) { group in
            for (index, application) in applications.enumerated() {
                group.addTask { [service] in
                    if application.status != .disbursed {
                        return (index, application)
                    }

                    do {
                        _ = try await service.getLoan(loanId: nil, applicationId: application.id)
                        return (index, application)
                    } catch let error as LoanError {
                        if case .notFound = error {
                            return (index, application.withStatus(.managerApproved))
                        }
                        throw error
                    }
                }
            }

            var reconciled = applications
            for try await (index, application) in group {
                reconciled[index] = application
            }
            return reconciled
        }
    }

    private func reconcileSanctionLetterState(
        _ application: BorrowerLoanApplication
    ) async throws -> BorrowerLoanApplication {
        guard application.status == .disbursed else { return application }

        do {
            _ = try await service.getLoan(loanId: nil, applicationId: application.id)
            return application
        } catch let error as LoanError {
            if case .notFound = error {
                return application.withStatus(.managerApproved)
            }
            throw error
        }
    }

    var statusDisplayItems: [(app: BorrowerLoanApplication, statusLabel: String, statusColor: Color)] {
        applications.map { ($0, $0.status.displayName, $0.status.color) }
    }
}
