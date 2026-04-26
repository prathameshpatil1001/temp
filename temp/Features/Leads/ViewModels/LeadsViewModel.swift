import Foundation
import Combine
import SwiftUI

@MainActor
final class LeadsViewModel: ObservableObject {

    // MARK: - Published State
    @Published var leads: [Lead]           = []
    @Published var filteredLeads: [Lead]   = []
    @Published var selectedFilter: LeadFilter = .all
    @Published var searchText: String      = ""
    @Published var isLoading: Bool         = false
    @Published var errorMessage: String?   = nil
    @Published var showAddLead: Bool       = false
    
    // MARK: - Scroll Tracking
    @Published var scrollOffset: CGFloat = 0
    @Published var contentWidth: CGFloat = 0
    @Published var viewWidth: CGFloat = 0
    
    var canScrollLeft: Bool { scrollOffset < -5 }
    var canScrollRight: Bool { viewWidth > 0 && contentWidth > viewWidth && scrollOffset > -(contentWidth - viewWidth + 5) }

    // MARK: - Filters
    let filters: [LeadFilter] = LeadFilter.allFilters

    // MARK: - Private
    private let service: LeadServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(service: LeadServiceProtocol = BackendLeadService()) {
        self.service = service
        setupBindings()
        loadLeads()
    }

    // MARK: - Bindings
    private func setupBindings() {
        // Re-filter whenever search text or selected filter changes
        Publishers.CombineLatest3($leads, $searchText, $selectedFilter)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .map { leads, search, filter in
                leads
                    .filter { lead in
                        // Status filter
                        guard filter.status == nil || lead.status == filter.status else { return false }
                        // Search filter
                        guard !search.isEmpty else { return true }
                        let q = search.lowercased()
                        return lead.name.lowercased().contains(q)
                            || lead.phone.contains(q)
                            || lead.loanType.rawValue.lowercased().contains(q)
                    }
                    .sorted { $0.createdAt > $1.createdAt }
            }
            .assign(to: &$filteredLeads)
    }

    // MARK: - Actions
    func loadLeads() {
        isLoading = true
        errorMessage = nil
        service.fetchLeads()
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] leads in
                self?.leads = leads
            }
            .store(in: &cancellables)
    }

    func selectFilter(_ filter: LeadFilter) {
        selectedFilter = filter
    }

    func addLead(_ lead: Lead) {
        service.addLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] newLead in
                self?.leads.insert(newLead, at: 0)
            }
            .store(in: &cancellables)
    }

    func updateLeadStatus(id: String, status: LeadStatus) {
        guard var lead = leads.first(where: { $0.id == id }) else { return }
        lead.status = status
        lead.updatedAt = Date()
        updateLead(lead)
    }

    func updateLead(_ lead: Lead) {
        service.updateLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                }
            } receiveValue: { [weak self] updatedLead in
                guard let self = self else { return }
                if let idx = self.leads.firstIndex(where: { $0.id == updatedLead.id }) {
                    self.leads[idx] = updatedLead
                }
            }
            .store(in: &cancellables)
    }

    func deleteLead(_ lead: Lead) {
        // Allow deletion if it's a local lead or if it's a submitted backend lead
        let isLocal = lead.applicationID == nil || lead.applicationID?.isEmpty == true
        guard isLocal || lead.status == .submitted else {
            errorMessage = "Only submitted or local leads can be deleted."
            return
        }

        isLoading = true
        errorMessage = nil

        service.deleteLead(lead)
            .receive(on: RunLoop.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let err) = completion {
                    self?.errorMessage = err.localizedDescription
                    // If backend fails, we should probably re-add it or reload to be safe
                    self?.loadLeads()
                }
            } receiveValue: { [weak self] _ in
                guard let self = self else { return }
                withAnimation {
                    self.leads.removeAll { $0.id == lead.id }
                    self.filteredLeads.removeAll { $0.id == lead.id }
                }
                // Re-sync from backend to ensure cancelled leads never reappear.
                // We add a slight delay to allow backend to process the cancellation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadLeads()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed
    var leadCountText: String {
        let count = filteredLeads.count
        return count == 1 ? "1 lead" : "\(count) leads"
    }

    func count(for filter: LeadFilter) -> Int {
        if filter.status == nil { return leads.count }
        return leads.filter { $0.status == filter.status }.count
    }
}
