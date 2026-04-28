import Foundation
import Combine

@MainActor
final class ApplicationsViewModel: ObservableObject {

    // MARK: - Published State
    @Published var applications: [LoanApplication]       = []
    @Published var filteredApplications: [LoanApplication] = []
    @Published var selectedStatus: ApplicationStatus?    = nil   // nil = All
    @Published var searchText: String                    = ""
    @Published var isLoading: Bool                       = false
    @Published var errorMessage: String?                 = nil
    @Published var selectedApplication: LoanApplication? = nil   // kept for backward compat; unused by view (NavigationLink used instead)
    
    // MARK: - Scroll Tracking
    @Published var scrollOffset: CGFloat = 0
    @Published var contentWidth: CGFloat = 0
    @Published var viewWidth: CGFloat = 0
    
    var canScrollLeft: Bool { scrollOffset < -5 }
    var canScrollRight: Bool { viewWidth > 0 && contentWidth > viewWidth && scrollOffset > -(contentWidth - viewWidth + 5) }

    // MARK: - Filter Options
    let statusFilters: [ApplicationStatus?] = [nil] + ApplicationStatus.allCases

    // MARK: - Private
    private let service: ApplicationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(service: ApplicationServiceProtocol = BackendApplicationService()) {
        self.service = service
        setupBindings()
        loadApplications()
    }

    // MARK: - Bindings
    private func setupBindings() {
        Publishers.CombineLatest3($applications, $selectedStatus, $searchText)
            .map { apps, status, search in
                var filtered = apps
                if let status = status {
                    filtered = filtered.filter { $0.status == status }
                }
                if !search.isEmpty {
                    filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.phone.localizedCaseInsensitiveContains(search) }
                }
                return filtered
            }
            .assign(to: &$filteredApplications)
    }

    // MARK: - Load
    func loadApplications() {
        isLoading = true
        errorMessage = nil
        service.fetchApplications()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] apps in
                self?.applications = apps
            }
            .store(in: &cancellables)
    }

    func selectStatus(_ status: ApplicationStatus?) {
        selectedStatus = status
    }

    // MARK: - Computed Stats
    var stats: ApplicationStats {
        ApplicationStats(
            total:       applications.count,
            underReview: applications.filter { $0.status == .underReview }.count,
            approved:    applications.filter { $0.status == .approved }.count,
            disbursed:   applications.filter { $0.status == .disbursed }.count
        )
    }

    func filterLabel(for status: ApplicationStatus?) -> String {
        status?.rawValue ?? "All"
    }

    func isSelected(_ status: ApplicationStatus?) -> Bool {
        selectedStatus == status
    }
}
