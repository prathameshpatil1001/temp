//
//  AdminUsersView.swift
//  lms_project
//

import SwiftUI

struct AdminUsersView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool
    
    @State private var showCreateUser = false
    @State private var isEditing = false

    private enum UserScope: String, CaseIterable, Identifiable {
        case staff = "Staff"
        case dst = "DST"
        var id: String { rawValue }
    }
    @State private var scope: UserScope = .staff
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    requestBanner

                    GeometryReader { geometry in
                        HStack(spacing: 1) {
                            userListPanel
                                .frame(width: geometry.size.width * Theme.Layout.splitLeftRatio)
                            Divider()
                            userDetailPanel
                                .frame(width: geometry.size.width * Theme.Layout.splitRightRatio - 1)
                        }
                    }
                }
            }
            .navigationTitle("Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if scope == .staff {
                            showCreateUser = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(scope != .staff)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ProfileNavButton(showProfile: $showProfile)
                }
            }
            .onAppear {
                adminVM.loadData()
                Task { await adminVM.loadDstDataForManagerScope() }
            }
            .sheet(isPresented: $showCreateUser) {
                CreateUserSheet(adminVM: adminVM)
            }
        }
    }

    @ViewBuilder
    private var requestBanner: some View {
        if let error = adminVM.requestError {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.critical)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.critical.opacity(0.10))
        } else if let success = adminVM.requestSuccess {
            Label(success, systemImage: "checkmark.circle.fill")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Theme.Colors.success.opacity(0.10))
        }
    }
    
    // MARK: - User List Panel
    
    private var userListPanel: some View {
        VStack(spacing: 0) {
            Picker("Scope", selection: $scope) {
                ForEach(UserScope.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.md)
            .onChange(of: scope) { _, _ in
                withAnimation(.easeInOut(duration: 0.2)) {
                    adminVM.selectedUser = nil
                    isEditing = false
                }
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search users...", text: $adminVM.searchText)
                    .font(Theme.Typography.subheadline)
            }
            .padding(10)
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.sm))
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.top, Theme.Spacing.sm)
            
            HStack {
                Text("\(activeCount) active")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(totalCount) total")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    if filteredList.isEmpty {
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: scope == .dst ? "person.badge.key" : "person.2.slash")
                                .font(.system(size: 36))
                                .foregroundStyle(.tertiary)
                            Text(scope == .dst
                                 ? "No DST accounts found in backend."
                                 : "No staff accounts found in backend.")
                                .font(Theme.Typography.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xl)
                        .padding(.horizontal, Theme.Spacing.md)
                    } else {
                        ForEach(filteredList) { user in
                            UserRow(user: user, isSelected: adminVM.selectedUser?.id == user.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        adminVM.selectedUser = user
                                        isEditing = false
                                    }
                                }
                            Divider().padding(.leading, 64)
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveSurface(colorScheme))
    }
    
    // MARK: - User Detail Panel
    
    private var userDetailPanel: some View {
        Group {
            if let user = adminVM.selectedUser {
                if isEditing {
                    if scope == .dst {
                        InlineEditDstUserView(adminVM: adminVM, user: user, isEditing: $isEditing)
                    } else {
                        InlineEditUserView(adminVM: adminVM, user: user, isEditing: $isEditing)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: Theme.Spacing.xl) {
                            HStack {
                                Spacer()
                                Button("Edit") {
                                    withAnimation { isEditing = true }
                                }
                                .font(Theme.Typography.subheadline.weight(.medium))
                                .foregroundStyle(Theme.Colors.primary)
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                            }
                            
                            VStack(spacing: Theme.Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12))
                                        .frame(width: 80, height: 80)
                                    Text(user.initials)
                                        .font(.system(size: 28, weight: .semibold))
                                        .foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
                                }
                                
                                Text(user.name)
                                    .font(Theme.Typography.title)
                                
                                HStack(spacing: Theme.Spacing.sm) {
                                    GenericBadge(text: user.role.displayName, color: Theme.Colors.primary)
                                    GenericBadge(text: user.isActive ? "Active" : "Inactive",
                                                 color: user.isActive ? Theme.Colors.success : Theme.Colors.neutral)
                                }
                            }
                            
                            VStack(spacing: 0) {
                                detailRow(icon: "envelope", label: "Email", value: user.email)
                                Divider().padding(.leading, 48)
                                detailRow(icon: "phone", label: "Phone", value: user.phone)
                                Divider().padding(.leading, 48)
                                detailRow(icon: "building.2", label: "Branch", value: user.branch)
                                Divider().padding(.leading, 48)
                                if let employeeCode = user.employeeCode, !employeeCode.isEmpty {
                                    detailRow(icon: "number", label: "Employee Code", value: employeeCode)
                                    Divider().padding(.leading, 48)
                                }
                                detailRow(icon: "calendar", label: "Joined", value: user.joinedAt.shortFormatted)
                            }
                            .cardStyle(colorScheme: colorScheme)
                            
                            HStack(spacing: Theme.Spacing.md) {
                                Button {
                                    adminVM.toggleUserStatus(user)
                                } label: {
                                    Label(
                                        user.isActive ? "Deactivate" : "Activate",
                                        systemImage: user.isActive ? "person.slash" : "person.badge.plus"
                                    )
                                    .font(Theme.Typography.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(user.isActive ? Theme.Colors.critical : Theme.Colors.success)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: Theme.Layout.buttonHeight)
                                    .background((user.isActive ? Theme.Colors.critical : Theme.Colors.success).opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.Spacing.lg)
                    }
                    .background(Theme.Colors.adaptiveBackground(colorScheme))
                }
            } else {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "person.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text(scope == .dst ? "Select a DST agent to view details" : "Select a user to view details")
                        .font(Theme.Typography.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var filteredList: [User] {
        switch scope {
        case .staff:
            return adminVM.filteredUsers
        case .dst:
            if adminVM.searchText.isEmpty { return adminVM.dstUsers }
            let q = adminVM.searchText
            return adminVM.dstUsers.filter {
                $0.name.localizedCaseInsensitiveContains(q) ||
                $0.email.localizedCaseInsensitiveContains(q) ||
                $0.branch.localizedCaseInsensitiveContains(q) ||
                $0.id.localizedCaseInsensitiveContains(q)
            }
        }
    }

    private var activeCount: Int {
        filteredList.filter { $0.isActive }.count
    }

    private var totalCount: Int {
        switch scope {
        case .staff: return adminVM.users.count
        case .dst: return adminVM.dstUsers.count
        }
    }
    
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 14)
    }
}

// MARK: - User Row

struct UserRow: View {
    let user: User
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(user.isActive ? Theme.Colors.primary.opacity(0.12) : Theme.Colors.neutral.opacity(0.12))
                    .frame(width: 40, height: 40)
                Text(user.initials)
                    .font(Theme.Typography.caption2)
                    .foregroundStyle(user.isActive ? Theme.Colors.primary : Theme.Colors.neutral)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(user.name)
                        .font(Theme.Typography.headline)
                        .foregroundStyle(user.isActive ? .primary : .secondary)
                    Spacer()
                    GenericBadge(text: user.role.displayName, color: Theme.Colors.primary)
                }
                HStack {
                    Text(user.branch)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !user.isActive {
                        Text("Inactive")
                            .font(Theme.Typography.caption2)
                            .foregroundStyle(Theme.Colors.neutral)
                    }
                }
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
        .background(isSelected ? Theme.Colors.primaryLight.opacity(colorScheme == .dark ? 0.2 : 1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Inline Edit DST User View

struct InlineEditDstUserView: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Binding var isEditing: Bool
    @Environment(\.colorScheme) private var colorScheme

    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var isSaving = false

    init(adminVM: AdminViewModel, user: User, isEditing: Binding<Bool>) {
        self.adminVM = adminVM
        self.user = user
        self._isEditing = isEditing
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    withAnimation { isEditing = false }
                }
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.critical)

                Spacer()
                Text("Edit DST")
                    .font(Theme.Typography.headline)
                Spacer()

                Button("Save") {
                    isSaving = true
                    Task {
                        let success = await adminVM.updateDstAccount(
                            userID: user.id,
                            name: name,
                            email: email,
                            phone: phone
                        )
                        await MainActor.run {
                            isSaving = false
                            if success {
                                withAnimation { isEditing = false }
                            }
                        }
                    }
                }
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.primary)
                .disabled(isSaving)
            }
            .padding()
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))

            Form {
                Section("Edit Information") {
                    TextField("Full Name", text: $name)
                        .disabled(true)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section("Account (Read-only)") {
                    HStack {
                        Text("User ID").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.id).foregroundStyle(.primary)
                    }
                    HStack {
                        Text("Branch").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.branch).foregroundStyle(.primary)
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
    }
}

// MARK: - Create User Sheet

struct CreateUserSheet: View {
    @ObservedObject var adminVM: AdminViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var name         = ""
    @State private var email        = ""
    @State private var password     = ""
    @State private var phone        = ""
    @State private var selectedRole: UserRole = .loanOfficer
    @State private var branchID     = ""
    @State private var newBranchName = ""
    @State private var newBranchRegion = ""
    @State private var newBranchCity = ""
    @State private var employeeId   = ""
    @State private var showPassword = false
    @State private var emailError: String? = nil
    @State private var isSubmitting = false

    private var isFormValid: Bool {
        let branchValid: Bool = if branchID == "+ Create New Branch" {
            !newBranchName.trimmingCharacters(in: .whitespaces).isEmpty &&
            !newBranchRegion.trimmingCharacters(in: .whitespaces).isEmpty &&
            !newBranchCity.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            !branchID.isEmpty
        }
        return !name.isEmpty && !email.isEmpty && !password.isEmpty &&
        branchValid && !employeeId.isEmpty
    }
    
    private var creatableRoles: [UserRole] {
        [.loanOfficer, .manager]
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    TextField("Full Name", text: $name)
                    Picker("Role", selection: $selectedRole) {
                        ForEach(creatableRoles) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    Picker("Branch", selection: $branchID) {
                        Text("Unassigned").tag("__UNASSIGNED__")
                        ForEach(adminVM.branches) { b in
                            Text(b.name).tag(b.id)
                        }
                        Text("+ Create New Branch").tag("+ Create New Branch")
                    }
                    if branchID == "+ Create New Branch" {
                        TextField("New Branch Name", text: $newBranchName)
                        TextField("Region", text: $newBranchRegion)
                        TextField("City", text: $newBranchCity)
                    }
                    TextField("Employee ID", text: $employeeId)
                }

                Section {
                    TextField("Email address", text: $email)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    TextField("Phone number", text: $phone)
                        .keyboardType(.phonePad)

                    HStack {
                        Group {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                            } else {
                                SecureField("Password", text: $password)
                            }
                        }
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    if let err = emailError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Login Credentials")
                } footer: {
                    Text("The user will sign in with these credentials.")
                }
            }
            .navigationTitle("Create User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        isSubmitting = true
                        Task {
                            var finalBranchID = branchID
                            if branchID == "+ Create New Branch" {
                                finalBranchID = await adminVM.createBranch(
                                    newBranchName,
                                    region: newBranchRegion,
                                    city: newBranchCity
                                ) ?? ""
                            } else if branchID == "__UNASSIGNED__" {
                                finalBranchID = ""
                            }
                            let finalBranchName = finalBranchID.isEmpty
                                ? "Unassigned"
                                : (adminVM.branches.first(where: { $0.id == finalBranchID })?.name ?? newBranchName)
                            let success = await adminVM.createUser(
                                name: name,
                                email: email,
                                password: password,
                                phone: phone,
                                role: selectedRole,
                                branchID: finalBranchID.isEmpty ? nil : finalBranchID,
                                branchName: finalBranchName,
                                employeeId: employeeId
                            )
                            await MainActor.run {
                                isSubmitting = false
                                if success {
                                    dismiss()
                                } else {
                                    emailError = adminVM.requestError
                                }
                            }
                        }
                    }
                    .disabled(!isFormValid || isSubmitting)
                }
            }
        }
        .onAppear {
            if branchID.isEmpty {
                branchID = adminVM.branches.first?.id ?? "__UNASSIGNED__"
            }
        }
    }
}

// MARK: - Inline Edit User View

struct InlineEditUserView: View {
    @ObservedObject var adminVM: AdminViewModel
    let user: User
    @Binding var isEditing: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name: String
    @State private var email: String
    @State private var phone: String
    @State private var selectedRole: UserRole
    @State private var branchID: String
    @State private var newBranchName = ""
    @State private var newBranchRegion = ""
    @State private var newBranchCity = ""
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    
    private var editableRoles: [UserRole] {
        [.loanOfficer, .manager]
    }
    
    init(adminVM: AdminViewModel, user: User, isEditing: Binding<Bool>) {
        self.adminVM = adminVM
        self.user = user
        self._isEditing = isEditing
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _phone = State(initialValue: user.phone)
        _selectedRole = State(initialValue: user.role)
        _branchID = State(initialValue: user.branchID ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") {
                    withAnimation { isEditing = false }
                }
                .font(Theme.Typography.subheadline)
                .foregroundStyle(Theme.Colors.critical)
                
                Spacer()
                Text("Edit User")
                    .font(Theme.Typography.headline)
                Spacer()
                
                Button("Save") {
                    isSaving = true
                    Task {
                        var finalBranchID = branchID
                        if branchID == "+ Create New Branch" {
                            finalBranchID = await adminVM.createBranch(
                                newBranchName,
                                region: newBranchRegion,
                                city: newBranchCity
                            ) ?? ""
                        } else if branchID == "__UNASSIGNED__" {
                            finalBranchID = ""
                        }
                        let finalBranchName = finalBranchID.isEmpty
                            ? "Unassigned"
                            : (adminVM.branches.first(where: { $0.id == finalBranchID })?.name ?? user.branch)
                        let success = await adminVM.updateUser(
                            userId: user.id,
                            name: name,
                            email: email,
                            phone: phone,
                            role: selectedRole,
                            branchID: finalBranchID.isEmpty ? nil : finalBranchID,
                            branchName: finalBranchName
                        )
                        await MainActor.run {
                            isSaving = false
                            if success {
                                withAnimation { isEditing = false }
                            }
                        }
                    }
                }
                .font(Theme.Typography.subheadline.weight(.semibold))
                .foregroundStyle(Theme.Colors.primary)
                .disabled(isSaving)
            }
            .padding()
            .background(Theme.Colors.adaptiveSurfaceSecondary(colorScheme))
            
            Form {
                Section("Edit Information") {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    
                    Picker("Role", selection: $selectedRole) {
                        ForEach(editableRoles) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .disabled(true)
                    Picker("Branch", selection: $branchID) {
                        Text("Unassigned").tag("__UNASSIGNED__")
                        ForEach(adminVM.branches) { b in
                            Text(b.name).tag(b.id)
                        }
                        Text("+ Create New Branch").tag("+ Create New Branch")
                    }
                    if branchID == "+ Create New Branch" {
                        TextField("New Branch Name", text: $newBranchName)
                        TextField("Region", text: $newBranchRegion)
                        TextField("City", text: $newBranchCity)
                    }
                    Text("Name changes are not supported by the current backend employee update API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Account (Read-only)") {
                    HStack {
                        Text("Employee ID").foregroundStyle(.secondary)
                        Spacer()
                        Text(user.id).foregroundStyle(.primary)
                    }
                    if let employeeCode = user.employeeCode, !employeeCode.isEmpty {
                        HStack {
                            Text("Employee Code").foregroundStyle(.secondary)
                            Spacer()
                            Text(employeeCode).foregroundStyle(.primary)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete User")
                            Spacer()
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.adaptiveBackground(colorScheme))
        .confirmationDialog("Delete User", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    let success = await adminVM.deleteUser(user)
                    await MainActor.run {
                        if success {
                            withAnimation { isEditing = false }
                        }
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will deactivate the selected employee account in the backend.")
        }
    }
}
