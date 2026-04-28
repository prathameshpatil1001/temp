import Foundation

@available(iOS 18.0, *)
struct AdminAPI {
    func listEmployeeAccounts(limit: Int32 = 200, offset: Int32 = 0) async throws -> [Admin_V1_EmployeeAccount] {
        let request: Admin_V1_ListEmployeeAccountsRequest = {
            var req = Admin_V1_ListEmployeeAccountsRequest()
            req.limit = limit
            req.offset = offset
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                let response = try await admin.listEmployeeAccounts(request, metadata: await CoreAPIClient.authorizedMetadata())
                return response.employees
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func createEmployeeAccount(
        name: String,
        email: String,
        phoneNumber: String,
        password: String,
        role: UserRole,
        branchID: String?
    ) async throws -> Admin_V1_CreateEmployeeAccountResponse {
        let request: Admin_V1_CreateEmployeeAccountRequest = {
            var req = Admin_V1_CreateEmployeeAccountRequest()
            req.name = name
            req.email = email
            req.phoneNumber = phoneNumber
            req.password = password
            req.employeeType = mapRole(role)
            if let branchID, !branchID.isEmpty {
                req.branchID = branchID
            }
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.createEmployeeAccount(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func createBankBranch(name: String, region: String, city: String) async throws -> Admin_V1_CreateBankBranchResponse {
        let request: Admin_V1_CreateBankBranchRequest = {
            var req = Admin_V1_CreateBankBranchRequest()
            req.name = name
            req.region = region
            req.city = city
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.createBankBranch(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func updateBankBranch(
        branchID: String,
        name: String?,
        region: String?,
        city: String?
    ) async throws -> Admin_V1_UpdateBankBranchResponse {
        let request: Admin_V1_UpdateBankBranchRequest = {
            var req = Admin_V1_UpdateBankBranchRequest()
            req.branchID = branchID
            if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                req.name = name
            }
            if let region, !region.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                req.region = region
            }
            if let city, !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                req.city = city
            }
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.updateBankBranch(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func deleteBankBranch(branchID: String) async throws -> Admin_V1_DeleteBankBranchResponse {
        let request: Admin_V1_DeleteBankBranchRequest = {
            var req = Admin_V1_DeleteBankBranchRequest()
            req.branchID = branchID
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.deleteBankBranch(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func updateEmployeeAccount(
        userID: String,
        email: String?,
        phoneNumber: String?,
        newPassword: String?
    ) async throws -> Admin_V1_UpdateEmployeeAccountResponse {
        let request: Admin_V1_UpdateEmployeeAccountRequest = {
            var req = Admin_V1_UpdateEmployeeAccountRequest()
            req.userID = userID
            if let email, !email.isEmpty {
                req.email = email
            }
            if let phoneNumber, !phoneNumber.isEmpty {
                req.phoneNumber = phoneNumber
            }
            if let newPassword, !newPassword.isEmpty {
                req.newPassword = newPassword
            }
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.updateEmployeeAccount(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func deleteEmployeeAccount(userID: String) async throws -> Admin_V1_DeleteEmployeeAccountResponse {
        let request: Admin_V1_DeleteEmployeeAccountRequest = {
            var req = Admin_V1_DeleteEmployeeAccountRequest()
            req.userID = userID
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.deleteEmployeeAccount(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }


    func assignEmployeeBranch(userID: String, branchID: String, clearBranch: Bool = false) async throws -> Admin_V1_AssignEmployeeBranchResponse {
        let request: Admin_V1_AssignEmployeeBranchRequest = {
            var req = Admin_V1_AssignEmployeeBranchRequest()
            req.userID = userID
            req.branchID = branchID
            req.clearBranch_p = clearBranch
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.assignEmployeeBranch(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func createDstAccount(name: String, email: String, phoneNumber: String, password: String) async throws -> Admin_V1_CreateDstAccountResponse {
        let request: Admin_V1_CreateDstAccountRequest = {
            var req = Admin_V1_CreateDstAccountRequest()
            req.name = name
            req.email = email
            req.phoneNumber = phoneNumber
            req.password = password
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.createDstAccount(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    func updateBranchDstCommission(branchID: String, dstCommission: String) async throws -> Admin_V1_UpdateBranchDstCommissionResponse {
        let request: Admin_V1_UpdateBranchDstCommissionRequest = {
            var req = Admin_V1_UpdateBranchDstCommissionRequest()
            req.branchID = branchID
            req.dstCommission = dstCommission
            return req
        }()

        do {
            return try await CoreAPIClient.withClient { client in
                let admin = Admin_V1_AdminService.Client(wrapping: client)
                return try await admin.updateBranchDstCommission(request, metadata: await CoreAPIClient.authorizedMetadata())
            }
        } catch {
            throw APIError.from(error)
        }
    }

    private func mapRole(_ role: UserRole) -> Admin_V1_EmployeeType {
        switch role {
        case .manager:
            return .manager
        case .loanOfficer:
            return .officer
        case .admin:
            return .unspecified
        case .dst:
            return .unspecified
        }
    }
}
