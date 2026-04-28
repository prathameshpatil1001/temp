//
//  AdminViewModel.swift
//  lms_project
//

import SwiftUI
import Combine

enum RiskSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case actionRequired = "Action Required"
    case collections = "Collections"
    case npa = "NPA"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .actionRequired: return "exclamationmark.triangle.fill"
        case .collections: return "tray.full.fill"
        case .npa: return "exclamationmark.octagon.fill"
        }
    }
}

enum ActionRequiredFilter: String, CaseIterable, Identifiable {
    case slaBreach = "SLA Breaches"
    case fraudAlert = "Fraud Alerts"
    case policyViolation = "Policy Violations"
    case stuckApplication = "Stuck Applications"
    var id: String { rawValue }
}

@MainActor
class AdminViewModel: ObservableObject {
    private struct PolicyConfigurationsCache: Codable {
        let maxLoanAmount: Double
        let minCIBILScore: Int
        let maxDTIRatio: Double
        let requireDocVerification: Bool
        let autoAssignEnabled: Bool
        let updatedAt: Date
    }

    @Published var users: [User] = []
    @Published var dstUsers: [User] = []
    @Published var selectedUser: User? = nil
    @Published var isLoading = false
    @Published var requestError: String? = nil
    @Published var requestSuccess: String? = nil
    @Published var searchText = ""
    
    // Risk Navigation
    @Published var selectedRiskSection: RiskSection = .overview
    @Published var selectedRiskFilter: ActionRequiredFilter = .slaBreach
    
    // System Control Navigation
    @Published var selectedSystemSection: String = "User Management"
    
    // System Control
    @Published var maxLoanAmount: Double = 50_000_000
    @Published var minCIBILScore: Int = 600
    @Published var maxDTIRatio: Double = 0.50
    @Published var requireDocVerification: Bool = true
    @Published var autoAssignEnabled: Bool = true
    
    // Branches
    @Published var branches: [BranchModel] = []
    
    // Audit Logs
    @Published var auditLogs: [AuditLog] = []
    
    // Editable Policies
    @Published var eligibilityRules: [String] = [
        "Min income ₹25,000/month for Personal Loan",
        "Co-applicant required for loans > ₹15L",
        "Max 3 active loans per borrower",
        "Employment tenure ≥ 1 year"
    ]
    
    func deleteEligibilityRule(at index: Int) {
        if eligibilityRules.indices.contains(index) {
            eligibilityRules.remove(at: index)
        }
    }
    
    @Published var documentChecklist: [DocumentChecklistItem] = [
        DocumentChecklistItem(name: "PAN Card", isRequired: true),
        DocumentChecklistItem(name: "Aadhaar Card", isRequired: true),
        DocumentChecklistItem(name: "Bank Statements (6 months)", isRequired: true),
        DocumentChecklistItem(name: "Salary Slips (3 months)", isRequired: true),
        DocumentChecklistItem(name: "Address Proof", isRequired: false)
    ]
    
    // Notifications for Profile
    @Published var notifications: [AdminNotification] = [
        AdminNotification(title: "System Maintenance", message: "Scheduled for Sunday 2 AM", time: "2h ago", icon: "wrench.and.screwdriver", color: .orange),
        AdminNotification(title: "New Policy Update", message: "CIBIL threshold updated to 600", time: "5h ago", icon: "shield", color: Theme.Colors.primary),
        AdminNotification(title: "Critical Alert", message: "SLA breach spike detected in Mumbai", time: "1d ago", icon: "exclamationmark.triangle", color: .red)
    ]
    
    // Performance Trends
    @Published var slaBreachTrendData: [Double] = [8, 5, 12, 7, 4, 9, 3]
    @Published var slaBreachTrendLabels: [String] = [] 
    
    private let adminAPI = AdminAPI()
    private let branchAPI = BranchAPI()
    private let dstAPI = DstAPI()
    private let dstLocalStoreKey = "manager.dst.local.overrides.v1"
    private let policyConfigStoreKey = "admin.policy.configurations.v1"
    private var dstLocalState = DstLocalStateStore()
    
    init() {
        dstLocalState = Self.loadDstLocalState()
        restorePolicyConfigurationsFallback()
    }
    
    var filteredUsers: [User] {
        if searchText.isEmpty { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.role.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.branch.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var activeUsersCount: Int {
        users.filter { $0.isActive }.count
    }
    
    var usersByRole: [UserRole: Int] {
        Dictionary(grouping: users.filter { $0.isActive }, by: { $0.role })
            .mapValues { $0.count }
    }
    
    func loadData() {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        Task {
            do {
                async let employeesTask = adminAPI.listEmployeeAccounts(limit: 200, offset: 0)
                async let branchesTask = branchAPI.listBranches(limit: 200, offset: 0)

                let employees = try await employeesTask
                let backendBranches = try await branchesTask

                // Map ALL employee accounts from backend — admin, manager, officer.
                // Never substitute mock data. If backend is empty, show empty list.
                let mappedUsers = employees.compactMap(Self.mapEmployeeAccount)

                // Use backend branches; build a minimal set from user data only if
                // branches endpoint returned nothing (not as a user fallback).
                let mappedBranches: [BranchModel]
                let rawBranches = backendBranches.map(Self.mapBranch).sorted(by: { $0.name < $1.name })
                if rawBranches.isEmpty && !mappedUsers.isEmpty {
                    mappedBranches = Self.deriveBranches(from: mappedUsers)
                } else {
                    mappedBranches = rawBranches
                }

                withAnimation {
                    users = mappedUsers
                    branches = mappedBranches
                    if let selectedID = selectedUser?.id {
                        selectedUser = mappedUsers.first(where: { $0.id == selectedID })
                    }
                }
                auditLogs = Self.mockAuditLogs()
                slaBreachTrendLabels = Self.generateDayLabels()
            } catch {
                // On hard failure, leave lists empty and surface the error.
                // Do NOT substitute mock data — admin needs to see real state.
                withAnimation {
                    users = []
                    branches = []
                    selectedUser = nil
                }
                requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to load users from backend."
                auditLogs = Self.mockAuditLogs()
                slaBreachTrendLabels = Self.generateDayLabels()
            }
            isLoading = false
        }
    }

    func loadDstDataForManagerScope() async {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let dstAccounts = try await dstAPI.listDstAccounts(limit: 200, offset: 0)
            let backendMapped = dstAccounts.map(Self.mapDstAccount)
            // Apply any admin local-state overrides (edits/toggles) on top of
            // the real backend list. Never fall back to mock data.
            let mapped = applyDstLocalState(to: backendMapped)
            withAnimation {
                dstUsers = mapped
            }
            // No error banner needed — empty list is valid backend state.
        } catch {
            // On failure keep whatever was already loaded (e.g., from a previous
            // successful fetch) but surface the error. Don't inject mocks.
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to load DST accounts from backend."
        }
    }
    
    func toggleUserStatus(_ user: User) {
        if let index = dstUsers.firstIndex(where: { $0.id == user.id }) {
            withAnimation {
                dstUsers[index].isActive.toggle()
                selectedUser = dstUsers[index]
                requestSuccess = dstUsers[index].isActive ? "DST agent marked active." : "DST agent marked inactive."
            }
            dstLocalState.statusByUserID[user.id] = dstUsers[index].isActive
            persistDstLocalState()
            return
        }
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            withAnimation {
                users[index].isActive.toggle()
                selectedUser = users[index]
            }
        }
    }
    
    // Notification Actions
    func markNotificationRead(_ id: UUID) {
        if let idx = notifications.firstIndex(where: { $0.id == id }) {
            notifications[idx].isRead = true
        }
    }
    
    func markAllNotificationsRead() {
        for i in notifications.indices {
            notifications[i].isRead = true
        }
    }
    
    func deleteNotification(_ id: UUID) {
        notifications.removeAll(where: { $0.id == id })
    }

    func createUser(
        name: String,
        email: String,
        password: String,
        phone: String,
        role: UserRole,
        branchID: String?,
        branchName: String,
        employeeId: String
    ) async -> Bool {
        requestError = nil
        requestSuccess = nil

        guard role == .loanOfficer || role == .manager else {
            requestError = "Only Manager and Loan Officer accounts can be created from this screen."
            return false
        }

        let resolvedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalEmail = resolvedEmail.isEmpty ? "\(name.lowercased().replacingOccurrences(of: " ", with: "."))@bank.com" : resolvedEmail
        let finalPhone = resolvedPhone.isEmpty ? "+91-0000000000" : resolvedPhone

        isLoading = true
        defer { isLoading = false }
        do {
            var userId = employeeId
            let response = try await adminAPI.createEmployeeAccount(
                name: name,
                email: finalEmail,
                phoneNumber: finalPhone,
                password: password,
                role: role,
                branchID: branchID
            )
            if !response.userID.isEmpty {
                userId = response.userID
            }

            if let branchID, !branchID.isEmpty, !userId.isEmpty {
                _ = try await adminAPI.assignEmployeeBranch(userID: userId, branchID: branchID)
            }

            requestSuccess = "User created successfully."
            loadData()
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create user"
            return false
        }
    }
    
    func updateUser(
        userId: String,
        name: String,
        email: String,
        phone: String,
        role: UserRole,
        branchID: String?,
        branchName: String
    ) async -> Bool {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }

        do {
            if let existingUser = users.first(where: { $0.id == userId }), existingUser.role != role {
                requestError = "Role change is not supported by backend yet. Create a new user with the desired role."
                return false
            }

            _ = try await adminAPI.updateEmployeeAccount(
                userID: userId,
                email: email,
                phoneNumber: phone,
                newPassword: nil
            )

            if let branchID, !branchID.isEmpty {
                _ = try await adminAPI.assignEmployeeBranch(userID: userId, branchID: branchID)
            } else {
                _ = try await adminAPI.assignEmployeeBranch(userID: userId, branchID: "", clearBranch: true)
            }

            if let index = users.firstIndex(where: { $0.id == userId }) {
                withAnimation {
                    users[index].email = email
                    users[index].phone = phone
                    users[index].role = role
                    users[index].branchID = branchID
                    users[index].branch = branchName
                    selectedUser = users[index]
                }
            }

            requestSuccess = "User updated successfully."
            loadData()
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to update user"
            return false
        }
    }

    func deleteUser(_ user: User) async -> Bool {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await adminAPI.deleteEmployeeAccount(userID: user.id)
            withAnimation {
                users.removeAll { $0.id == user.id }
                if selectedUser?.id == user.id {
                    selectedUser = nil
                }
            }
            requestSuccess = "User deleted successfully."
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to delete user"
            return false
        }
    }
    
    func removeDstLocally(_ user: User) {
        withAnimation {
            dstUsers.removeAll { $0.id == user.id }
        }
        dstLocalState.removedUserIDs.insert(user.id)
        dstLocalState.overridesByUserID[user.id] = nil
        dstLocalState.statusByUserID[user.id] = nil
        persistDstLocalState()
        requestError = nil
        requestSuccess = "DST agent removed from current list."
    }
    
    func savePolicyConfigurations(
        maxLoanAmount: Double,
        minCIBILScore: Int,
        maxDTIRatio: Double,
        requireDocVerification: Bool,
        autoAssignEnabled: Bool
    ) async -> Bool {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }

        // Persist immediately in-memory so UI reflects latest settings.
        self.maxLoanAmount = maxLoanAmount
        self.minCIBILScore = minCIBILScore
        self.maxDTIRatio = maxDTIRatio
        self.requireDocVerification = requireDocVerification
        self.autoAssignEnabled = autoAssignEnabled

        // No dedicated backend API exists yet for policy configuration writes.
        // Keep a resilient fallback store until backend endpoint becomes available.
        persistPolicyConfigurationsFallback()
        requestSuccess = "Policy configurations saved. Using local fallback until backend sync endpoint is available."
        return true
    }
    
    func createBranch(_ branchName: String, region: String, city: String) async -> String? {
        let trimmed = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            requestError = "Branch name is required."
            return nil
        }
        guard !trimmedRegion.isEmpty else {
            requestError = "Region is required."
            return nil
        }
        guard !trimmedCity.isEmpty else {
            requestError = "City is required."
            return nil
        }

        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await adminAPI.createBankBranch(name: trimmed, region: trimmedRegion, city: trimmedCity)
            let backendBranches = try await branchAPI.listBranches(limit: 200, offset: 0)
            branches = backendBranches.map(Self.mapBranch).sorted(by: { $0.name < $1.name })
            requestSuccess = "Branch created successfully."
            return response.branchID.isEmpty ? nil : response.branchID
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create branch"
            return nil
        }
    }

    func updateBranch(branchID: String, newName: String, region: String, city: String) async -> Bool {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            requestError = "Branch name is required."
            return false
        }
        guard !trimmedRegion.isEmpty else {
            requestError = "Region is required."
            return false
        }
        guard !trimmedCity.isEmpty else {
            requestError = "City is required."
            return false
        }

        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await adminAPI.updateBankBranch(
                branchID: branchID,
                name: trimmedName,
                region: trimmedRegion,
                city: trimmedCity
            )
            let backendBranches = try await branchAPI.listBranches(limit: 200, offset: 0)
            branches = backendBranches.map(Self.mapBranch).sorted(by: { $0.name < $1.name })
            requestSuccess = "Branch updated successfully."
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to update branch"
            return false
        }
    }

    func deleteBranch(branchID: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await adminAPI.deleteBankBranch(branchID: branchID)
            withAnimation {
                branches.removeAll { $0.id == branchID }
                users = users.map { user in
                    var value = user
                    if value.branchID == branchID {
                        value.branchID = nil
                        value.branch = "Unassigned"
                    }
                    return value
                }
            }
            requestSuccess = "Branch deleted successfully."
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to delete branch"
            return false
        }
    }

    func createDstAccount(name: String, email: String, phone: String, password: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        do {
            _ = try await adminAPI.createDstAccount(name: name, email: email, phoneNumber: phone, password: password)
            requestSuccess = "DST account created successfully."
            await loadDstDataForManagerScope()
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to create DST account"
            return false
        }
    }

    func addDstLocally(name: String, email: String, phone: String, branch: String) {
        let newUser = User(
            id: "DST-\(UUID().uuidString.prefix(4))",
            name: name,
            email: email,
            role: .dst,
            branchID: nil,
            branch: branch,
            phone: phone,
            isActive: true,
            joinedAt: Date(),
            employeeCode: nil
        )
        withAnimation {
            users.insert(newUser, at: 0)
        }
    }

    func updateDstAccount(userID: String, name: String, email: String, phone: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        do {
            _ = try await adminAPI.updateEmployeeAccount(
                userID: userID,
                email: email,
                phoneNumber: phone,
                newPassword: nil
            )
            if let index = dstUsers.firstIndex(where: { $0.id == userID }) {
                withAnimation {
                    dstUsers[index].name = name
                    dstUsers[index].email = email
                    dstUsers[index].phone = phone
                }
            }
            requestSuccess = "DST account updated successfully."
            dstLocalState.overridesByUserID[userID] = DstLocalOverride(name: name, email: email, phone: phone)
            dstLocalState.removedUserIDs.remove(userID)
            persistDstLocalState()
            return true
        } catch {
            if case APIError.permissionDenied = error {
                // Manager fallback path: keep DST management functional on device.
                if let index = dstUsers.firstIndex(where: { $0.id == userID }) {
                    withAnimation {
                        dstUsers[index].name = name
                        dstUsers[index].email = email
                        dstUsers[index].phone = phone
                    }
                }
                dstLocalState.overridesByUserID[userID] = DstLocalOverride(name: name, email: email, phone: phone)
                dstLocalState.removedUserIDs.remove(userID)
                persistDstLocalState()
                requestSuccess = "Saved on this device. Backend denied this role for DST update."
                return true
            }
            if let index = dstUsers.firstIndex(where: { $0.id == userID }) {
                withAnimation {
                    dstUsers[index].name = name
                    dstUsers[index].email = email
                    dstUsers[index].phone = phone
                }
                dstLocalState.overridesByUserID[userID] = DstLocalOverride(name: name, email: email, phone: phone)
                dstLocalState.removedUserIDs.remove(userID)
                persistDstLocalState()
                requestSuccess = "Saved on this device. Backend update is currently unavailable."
                return true
            }
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to update DST account"
            return false
        }
    }
    
    func renameDstLocally(userID: String, name: String) {
        guard let index = dstUsers.firstIndex(where: { $0.id == userID }) else { return }
        withAnimation {
            dstUsers[index].name = name
        }
        let existing = dstLocalState.overridesByUserID[userID]
        dstLocalState.overridesByUserID[userID] = DstLocalOverride(
            name: name,
            email: existing?.email ?? dstUsers[index].email,
            phone: existing?.phone ?? dstUsers[index].phone
        )
        persistDstLocalState()
    }

    private func applyDstLocalState(to users: [User]) -> [User] {
        users
            .filter { !dstLocalState.removedUserIDs.contains($0.id) }
            .map { user in
                var value = user
                if let override = dstLocalState.overridesByUserID[user.id] {
                    value.name = override.name
                    value.email = override.email
                    value.phone = override.phone
                }
                if let status = dstLocalState.statusByUserID[user.id] {
                    value.isActive = status
                }
                return value
            }
    }
    
    private func persistDstLocalState() {
        if let data = try? JSONEncoder().encode(dstLocalState) {
            UserDefaults.standard.set(data, forKey: dstLocalStoreKey)
        }
    }

    private func persistPolicyConfigurationsFallback() {
        let payload = PolicyConfigurationsCache(
            maxLoanAmount: maxLoanAmount,
            minCIBILScore: minCIBILScore,
            maxDTIRatio: maxDTIRatio,
            requireDocVerification: requireDocVerification,
            autoAssignEnabled: autoAssignEnabled,
            updatedAt: Date()
        )
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: policyConfigStoreKey)
        }
    }

    private func restorePolicyConfigurationsFallback() {
        guard let data = UserDefaults.standard.data(forKey: policyConfigStoreKey),
              let payload = try? JSONDecoder().decode(PolicyConfigurationsCache.self, from: data) else {
            return
        }
        maxLoanAmount = payload.maxLoanAmount
        minCIBILScore = payload.minCIBILScore
        maxDTIRatio = payload.maxDTIRatio
        requireDocVerification = payload.requireDocVerification
        autoAssignEnabled = payload.autoAssignEnabled
    }
    
    private static func loadDstLocalState() -> DstLocalStateStore {
        guard let data = UserDefaults.standard.data(forKey: "manager.dst.local.overrides.v1"),
              let state = try? JSONDecoder().decode(DstLocalStateStore.self, from: data) else {
            return DstLocalStateStore()
        }
        return state
    }

    func updateDstCommission(branchID: String, commission: String) async -> Bool {
        requestError = nil
        requestSuccess = nil
        do {
            _ = try await adminAPI.updateBranchDstCommission(branchID: branchID, dstCommission: commission)
            requestSuccess = "DST commission updated successfully."
            return true
        } catch {
            requestError = (error as? LocalizedError)?.errorDescription ?? "Failed to update commission"
            return false
        }
    }
    
    // MARK: - Mock Audit Logs
    
    static func mockAuditLogs() -> [AuditLog] {
        [
            AuditLog(id: "AUD-001", action: "APP-2024-006 approved", user: "Deepak Mehta", detail: "Loan approved after credit verification",
                     timestamp: Date().addingTimeInterval(-720)), // 12m ago
            AuditLog(id: "AUD-002", action: "Policy Update: Min CIBIL Score matched", user: "System Rule", detail: "Automated policy check passed",
                     timestamp: Date().addingTimeInterval(-3600)), // 1h ago
            AuditLog(id: "AUD-003", action: "APP-2024-009 escalated to Admin", user: "Sunita Patel", detail: "Manual review required for high-value asset",
                     timestamp: Date().addingTimeInterval(-7200)), // 2h ago
            AuditLog(id: "AUD-004", action: "Suspicious Application detected", user: "Fraud Engine", detail: "Fraud flag raised for loan APP-2024-021",
                     timestamp: Date().addingTimeInterval(-10800)), // 3h ago
            AuditLog(id: "AUD-005", action: "Config Updated", user: "Sunita Patel", detail: "Max DTI ratio changed to 0.50",
                     timestamp: Date().addingTimeInterval(-86400))
        ]
    }

    private static func mapEmployeeAccount(_ account: Admin_V1_EmployeeAccount) -> User? {
        // Map ALL known staff roles so admin sees the complete employee directory.
        guard let role = mapStaffRole(account.role) else {
            return nil // Skip unspecified/unknown proto roles only
        }

        let joinedAt: Date = {
            guard !account.createdAt.isEmpty else { return Date() }
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: account.createdAt) ?? Date()
        }()

        let resolvedName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = resolvedName.isEmpty
            ? account.email.components(separatedBy: "@").first?.replacingOccurrences(of: ".", with: " ").capitalized ?? "Unknown"
            : resolvedName

        // Keep branch labels aligned with the editable admin UI, while still
        // surfacing missing contact fields clearly.
        let branchName = account.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Unassigned" : account.branchName
        let phone = account.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "N/A" : account.phoneNumber

        return User(
            id: account.userID,
            name: name,
            email: account.email.isEmpty ? "N/A" : account.email,
            role: role,
            branchID: account.branchID.isEmpty ? nil : account.branchID,
            branch: branchName,
            phone: phone,
            isActive: account.isActive,
            joinedAt: joinedAt,
            employeeCode: account.employeeCode.isEmpty ? nil : account.employeeCode
        )
    }

    private static func mapStaffRole(_ role: Admin_V1_StaffRole) -> UserRole? {
        switch role {
        case .admin:
            return .admin
        case .manager:
            return .manager
        case .officer:
            return .loanOfficer
        default:
            return nil // .unspecified and unknown raw values are silently dropped
        }
    }

    /// Derives a minimal branch list from mapped user data when the branches
    /// endpoint returns nothing. This is NOT a mock — it is derived from live data.
    private static func deriveBranches(from users: [User]) -> [BranchModel] {
        Set(
            users
                .map(\.branch)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "Unassigned" }
        )
        .sorted()
        .map { branchName in
            BranchModel(
                id: branchName.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: branchName,
                region: "",
                city: "",
                location: branchName
            )
        }
    }

    // Note: fallbackDstUsers() and fallbackEmployeeUsers() have been removed.
    // Admin always sees live backend data. Empty lists are the correct empty state.

    private static func generateDayLabels() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE" // e.g., MON, TUE
        let calendar = Calendar.current
        return (0..<7).reversed().map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            return formatter.string(from: date).uppercased()
        }
    }

    private static func mapBranch(_ branch: Branch_V1_BankBranch) -> BranchModel {
        let location = [branch.city, branch.region]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return BranchModel(
            id: branch.id,
            name: branch.name,
            region: branch.region,
            city: branch.city,
            location: location
        )
    }

    private static func mapDstAccount(_ account: Dst_V1_DstAccount) -> User {
        let joinedAt: Date = {
            guard !account.createdAt.isEmpty else { return Date() }
            return ISO8601DateFormatter().date(from: account.createdAt) ?? Date()
        }()

        let resolvedName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = account.email.components(separatedBy: "@").first?
            .replacingOccurrences(of: ".", with: " ")
            .capitalized ?? "DST Agent"

        let branchName = account.branchName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Unassigned" : account.branchName
        let phone = account.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "N/A" : account.phoneNumber

        return User(
            id: account.userID,
            name: resolvedName.isEmpty ? fallbackName : resolvedName,
            email: account.email.isEmpty ? "N/A" : account.email,
            role: .dst,
            branchID: account.branchID.isEmpty ? nil : account.branchID,
            branch: branchName,
            phone: phone,
            isActive: account.isActive,
            joinedAt: joinedAt,
            employeeCode: nil
        )
    }
}

private struct DstLocalOverride: Codable {
    let name: String
    let email: String
    let phone: String
}

private struct DstLocalStateStore: Codable {
    var overridesByUserID: [String: DstLocalOverride] = [:]
    var statusByUserID: [String: Bool] = [:]
    var removedUserIDs: Set<String> = []
}

// MARK: - Audit Log

struct AuditLog: Identifiable, Hashable {
    let id: String
    let action: String
    let user: String
    let detail: String
    let timestamp: Date
}

// MARK: - Branch Model

struct BranchModel: Identifiable, Hashable {
    let id: String
    var name: String
    var region: String
    var city: String
    var location: String
}

// MARK: - Document Checklist Item

struct DocumentChecklistItem: Identifiable {
    let id = UUID()
    var name: String
    var isRequired: Bool
}

// MARK: - Admin Notification

struct AdminNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let time: String
    let icon: String
    let color: Color
    var isRead: Bool = false
}
