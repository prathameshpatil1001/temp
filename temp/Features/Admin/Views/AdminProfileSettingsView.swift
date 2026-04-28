//
//  AdminProfileSettingsView.swift
//  lms_project
//

import SwiftUI

struct AdminProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var adminVM: AdminViewModel



    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Theme.Spacing.xl) {
                        // Header profile snippet
                        VStack(spacing: Theme.Spacing.sm) {
                            ZStack {
                                Circle().fill(Theme.Colors.adaptivePrimary(colorScheme).opacity(0.12)).frame(width: 80, height: 80)
                                Text(authVM.currentUser?.initials ?? "AD")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                            }
                            Text(authVM.currentUser?.name ?? "Admin")
                                .font(Theme.Typography.titleLarge)
                            GenericBadge(text: "System Administrator", color: Theme.Colors.adaptivePrimary(colorScheme))
                        }
                        .padding(.top, Theme.Spacing.xl)

                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            SectionHeader(title: "Basic Information", icon: "person.text.rectangle")
                            profileContent
                            
                            SectionHeader(title: "Appearance", icon: "paintbrush")
                            appearanceContent
                            
                            HStack {
                                SectionHeader(title: "Notifications", icon: "bell")
                                Spacer()
                                Button {
                                    adminVM.markAllNotificationsRead()
                                } label: {
                                    Text("Mark all as read")
                                        .font(Theme.Typography.caption)
                                        .foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
                                }
                            }
                            notificationsList
                        }
                        .padding(.horizontal, Theme.Spacing.lg)
                    }
                    .padding(.bottom, Theme.Spacing.xl)
                }
            }
            .navigationTitle("Admin Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout", role: .destructive) {
                        dismiss()
                        authVM.logout()
                    }
                    .foregroundStyle(Theme.Colors.critical)
                }
            }
        }
    }


    // MARK: - Content Sections (Mockups / Reusing existing concepts)

    private var profileContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            if let user = authVM.currentUser {
                VStack(spacing: 0) {
                    infoRow("Name", user.name)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Email", user.email)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Phone", user.phone)
                    Divider().padding(.leading, Theme.Spacing.md)
                    infoRow("Branch", user.branch)
                }
                .cardStyle(colorScheme: colorScheme)
            }
        }
    }
    
    private var appearanceContent: some View {
        VStack(spacing: 0) {
            toggleRow("Dark Mode", isOn: $authVM.isDarkMode)
        }
        .cardStyle(colorScheme: colorScheme)
    }

    private var notificationsList: some View {
        VStack(spacing: 0) {
            if adminVM.notifications.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No notifications").font(Theme.Typography.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(adminVM.notifications) { note in
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            Circle().fill(note.color.opacity(0.12)).frame(width: 40, height: 40)
                            Image(systemName: note.icon).font(.system(size: 16)).foregroundStyle(note.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.title)
                                .font(Theme.Typography.subheadline)
                                .fontWeight(note.isRead ? .medium : .bold)
                                .foregroundStyle(note.isRead ? .secondary : .primary)
                            Text(note.message).font(Theme.Typography.caption).foregroundStyle(.secondary)
                            Text(note.time).font(Theme.Typography.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        
                        if !note.isRead {
                            Button {
                                adminVM.markNotificationRead(note.id)
                            } label: {
                                Circle().fill(Theme.Colors.adaptivePrimary(colorScheme)).frame(width: 8, height: 8)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        
                        Button {
                            adminVM.deleteNotification(note.id)
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundStyle(.tertiary)
                        }
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                        .padding(.leading, 8)
                    }
                    .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        adminVM.markNotificationRead(note.id)
                    }
                    
                    if note.id != adminVM.notifications.last?.id {
                        Divider().padding(.leading, 64)
                    }
                }
            }
        }
        .cardStyle(colorScheme: colorScheme)
    }

    // MARK: - Helpers

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(Theme.Typography.subheadline)
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 14)
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(label).font(Theme.Typography.subheadline)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.Colors.adaptivePrimary(colorScheme))
        }
        .padding(.horizontal, Theme.Spacing.md).padding(.vertical, 10)
    }

    private func miniStat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(label).font(Theme.Typography.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md).cardStyle(colorScheme: colorScheme)
    }

    private func integrationCard(_ name: String, status: String, color: Color) -> some View {
        HStack {
            Image(systemName: "network").font(.system(size: 20)).foregroundStyle(Theme.Colors.adaptivePrimary(colorScheme))
            Text(name).font(Theme.Typography.subheadline).padding(.leading, 8)
            Spacer()
            GenericBadge(text: status, color: color)
        }
        .padding(Theme.Spacing.md).cardStyle(colorScheme: colorScheme)
    }
}
