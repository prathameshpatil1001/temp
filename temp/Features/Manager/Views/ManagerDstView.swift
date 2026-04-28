//
//  ManagerDstView.swift
//  lms_project
//

import SwiftUI

struct ManagerDstView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Binding var showProfile: Bool

    @State private var showAddDst    = false
    @State private var editingAgent  : User? = nil
    @State private var searchText    = ""
    @State private var agentToDelete : User? = nil
    @State private var isAnimating   = false

    private var primary:  Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var critical: Color { Theme.Colors.adaptiveCritical(colorScheme) }
    private var surface:  Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var bg:       Color { Theme.Colors.adaptiveBackground(colorScheme) }
    private var border:   Color { Theme.Colors.adaptiveBorder(colorScheme) }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        statsStrip
                        searchBar
                        dstList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Direct Sales Team")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 10) {
                        Button {
                            showAddDst = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text("Add Agent")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        ProfileNavButton(showProfile: $showProfile)
                    }
                }
            }
            .tint(primary)
            .sheet(isPresented: $showAddDst) {
                AddDstSheet(adminVM: adminVM, authVM: authVM)
            }
            .sheet(item: $editingAgent) { agent in
                EditDstSheet(agent: agent, adminVM: adminVM, authVM: authVM)
            }
            .alert("Delete Agent", isPresented: Binding(
                get: { agentToDelete != nil },
                set: { if !$0 { agentToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    if let agent = agentToDelete { adminVM.removeDstLocally(agent) }
                }
            } message: {
                Text("Remove \(agentToDelete?.name ?? "this agent") from this list? This is a frontend-only action.")
            }
            .onAppear {
                adminVM.loadData()
                Task { await adminVM.loadDstDataForManagerScope() }
                withAnimation(.easeOut(duration: 0.5)) { isAnimating = true }
            }
        }
    }

    // MARK: — Stats Strip

    private var statsStrip: some View {
        let branchDst = adminVM.dstUsers
        let activeCount = branchDst.filter { $0.isActive }.count
        let activeRatio = branchDst.isEmpty ? 0 : Int(Double(activeCount) / Double(branchDst.count) * 100)

        return VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "Overview", icon: "person.2.fill")
                .opacity(0.7)
                .scaleEffect(0.95, anchor: .leading)

            HStack(spacing: 10) {
                statCard(
                    label: "Total Agents",
                    value: "\(branchDst.count)",
                    icon: "person.2.fill",
                    color: primary
                )
                statCard(
                    label: "Portfolio",
                    value: "₹\(branchDst.count * 14)L",
                    icon: "indianrupeesign.circle.fill",
                    color: primary
                )
                statCard(
                    label: "Active Ratio",
                    value: "\(activeRatio)%",
                    icon: "chart.bar.fill",
                    color: activeRatio >= 70
                        ? Theme.Colors.adaptiveSuccess(colorScheme)
                        : activeRatio >= 40 ? Theme.Colors.adaptiveWarning(colorScheme)
                        : critical
                )
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 14)
    }

    private func statCard(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) { // Reduced spacing
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold)) // Smaller icon
                    .foregroundStyle(color.opacity(0.8))
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .semibold, design: .rounded)) // Reduced from 22 & Bold to 18 & Semibold
                    .foregroundStyle(.primary) // Use primary text color for a "lighter" look than the accent color
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium)) // Smaller label
                    .foregroundStyle(.tertiary) // Lighter gray
                    .textCase(.uppercase)
                    .tracking(0.2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10) // Tighter vertical padding
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface.opacity(0.5)) // Lighter surface appearance
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md)) // Smaller radius for smaller cards
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.md)
                .stroke(border.opacity(0.5), lineWidth: 0.5) // Thinner, lighter border
        )
    }

    // MARK: — Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.tertiary)
            TextField("Search by name, email or ID…", text: $searchText)
                .font(.system(size: 15))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1)
        )
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 10)
    }

    // MARK: — DST List

    private var dstList: some View {
        let branchDst = adminVM.dstUsers
        let filteredDst = branchDst.filter {
            searchText.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.email.localizedCaseInsensitiveContains(searchText) ||
            $0.id.localizedCaseInsensitiveContains(searchText)
        }

        return VStack(alignment: .leading, spacing: 10) {
            if !filteredDst.isEmpty {
                sectionHeader(
                    title: searchText.isEmpty ? "All Agents" : "Results",
                    icon: "list.bullet"
                )
            }

            if filteredDst.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 340), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(filteredDst) { agent in
                        DstCard(agent: agent, colorScheme: colorScheme) {
                            editingAgent = agent
                        } onToggle: {
                            adminVM.toggleUserStatus(agent)
                        } onDelete: {
                            agentToDelete = agent
                        }
                    }
                }
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(primary.opacity(0.06))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.2.slash")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(primary.opacity(0.4))
            }
            VStack(spacing: 4) {
                Text(searchText.isEmpty ? "No agents in this branch" : "No results found")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(searchText.isEmpty ? "Add your first DST agent to get started." : "Try a different name, email or ID.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: — Section Header (matches Dashboard)

    private func sectionHeader(title: String, icon: String?) -> some View {
        HStack(spacing: 6) {
            if icon! == nil {
                Image(systemName: icon ?? "person.2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(primary)
            }
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(0.7)
        }
    }
}

// MARK: — DST Card

private struct DstCard: View {
    let agent      : User
    let colorScheme: ColorScheme
    let onEdit     : () -> Void
    let onToggle   : () -> Void
    let onDelete   : () -> Void

    private var primary:  Color { Theme.Colors.adaptivePrimary(colorScheme) }
    private var surface:  Color { Theme.Colors.adaptiveSurface(colorScheme) }
    private var border:   Color { Theme.Colors.adaptiveBorder(colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: avatar + info + status
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(primary.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Text(agent.initials)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(agent.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(agent.email)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                statusBadge
            }
            .padding(16)

            Divider()
                .padding(.horizontal, 16)

            // Bottom: phone + actions
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text(agent.phone)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    iconButton(
                        icon: agent.isActive ? "person.fill.xmark" : "person.fill.checkmark",
                        color: agent.isActive ? Theme.Colors.adaptiveWarning(colorScheme) : Theme.Colors.adaptiveSuccess(colorScheme),
                        action: onToggle
                    )
                    iconButton(icon: "pencil",    color: primary,  action: onEdit)
                    iconButton(icon: "trash",     color: Theme.Colors.adaptiveCritical(colorScheme), action: onDelete)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemFill).opacity(0.4))
        }
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(border, lineWidth: 1)
        )
    }

    private var statusBadge: some View {
        let color: Color = agent.isActive ? Theme.Colors.adaptiveSuccess(colorScheme) : .gray
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(agent.isActive ? "Active" : "Inactive")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }

    private func iconButton(icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Add DST Sheet

private struct AddDstSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adminVM : AdminViewModel
    @ObservedObject var authVM  : AuthViewModel

    @State private var name     = ""
    @State private var email    = ""
    @State private var phone    = ""
    @State private var password = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Personal Details")
                }

                Section {
                    SecureField("Assign Password", text: $password)
                } header: {
                    Text("Login Credentials")
                } footer: {
                    Text("Agents will use their email and this password to sign in.")
                }
            }
            .navigationTitle("New DST Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Creating…" : "Create Account") { saveAgent() }
                        .disabled(name.isEmpty || email.isEmpty || password.isEmpty || isSaving)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func saveAgent() {
        isSaving = true
        Task {
            let success = await adminVM.createDstAccount(
                name: name, email: email, phone: phone, password: password
            )
            await MainActor.run {
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}

// MARK: — Edit DST Sheet

private struct EditDstSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adminVM: AdminViewModel
    @ObservedObject var authVM:  AuthViewModel

    let agent: User
    @State private var name:     String
    @State private var email:    String
    @State private var phone:    String
    @State private var isSaving = false

    init(agent: User, adminVM: AdminViewModel, authVM: AuthViewModel) {
        self.agent   = agent
        self.adminVM = adminVM
        self.authVM  = authVM
        _name  = State(initialValue: agent.name)
        _email = State(initialValue: agent.email)
        _phone = State(initialValue: agent.phone)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full Name", text: $name)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                } header: {
                    Text("Update Agent Details")
                }

                Section {
                    HStack {
                        Text("Branch")
                        Spacer()
                        Text(agent.branch).foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Account ID")
                        Spacer()
                        Text(agent.id)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Text("Account Info")
                }
            }
            .navigationTitle("Edit Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Update") { updateAgent() }
                        .disabled(name.isEmpty || email.isEmpty || isSaving)
                        .fontWeight(.bold)
                }
            }
        }
    }

    private func updateAgent() {
        isSaving = true
        Task {
            let success = await adminVM.updateDstAccount(
                userID: agent.id, name: name, email: email, phone: phone
            )
            await MainActor.run {
                isSaving = false
                if success { dismiss() }
            }
        }
    }
}
