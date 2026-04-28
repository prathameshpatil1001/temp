//
//  LOProfileView.swift
//  lms_project
//

import SwiftUI

struct LOProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var notificationsEnabled = true
    @State private var biometricEnabled = false
    @State private var showLogoutConfirmation = false
    
    var isModal: Bool = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.adaptiveBackground(colorScheme)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.lg) {
                        // Profile Card
                        profileCard
                        
                        // Account Details
                        accountDetailsSection
                        
                        // Settings
                        settingsSection
                        
                        // Sign Out
                        signOutButton
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.md)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if isModal {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .alert("Sign Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        authVM.logout()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        VStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.12))
                    .frame(width: 88, height: 88)
                Text(authVM.currentUser?.initials ?? "")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
            }
            
            Text(authVM.currentUser?.name ?? "User")
                .font(Theme.Typography.titleLarge)
            
            GenericBadge(text: authVM.currentUser?.role.displayName ?? "", color: Theme.Colors.primary)
            
            Text(authVM.currentUser?.email ?? "")
                .font(Theme.Typography.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.adaptiveSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg)
                .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
        )
    }
    
    // MARK: - Account Details
    
    private var accountDetailsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Account Details")
                .font(Theme.Typography.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                profileRow(icon: "building.2", label: "Branch", value: authVM.currentUser?.branch ?? "")
                Divider().padding(.leading, 48)
                profileRow(icon: "phone", label: "Phone", value: authVM.currentUser?.phone ?? "")
                Divider().padding(.leading, 48)
                profileRow(icon: "number", label: "Employee ID", value: authVM.currentUser?.id ?? "")
                Divider().padding(.leading, 48)
                profileRow(icon: "calendar", label: "Joined", value: authVM.currentUser?.joinedAt.shortFormatted ?? "")
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Settings
    
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Settings")
                .font(Theme.Typography.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                settingsToggle(icon: "bell", label: "Notifications", isOn: $notificationsEnabled)
                Divider().padding(.leading, 48)
                settingsToggle(icon: "faceid", label: "Biometric Login", isOn: $biometricEnabled)
                Divider().padding(.leading, 48)
                settingsToggle(icon: "moon", label: "Dark Mode", isOn: $authVM.isDarkMode)
            }
            .background(Theme.Colors.adaptiveSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg)
                    .stroke(Theme.Colors.adaptiveBorder(colorScheme), lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Sign Out
    
    private var signOutButton: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.critical)
                .frame(maxWidth: .infinity)
                .frame(height: Theme.Layout.buttonHeight)
                .background(Theme.Colors.critical.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
        }
        .buttonStyle(.plain)
        .padding(.top, Theme.Spacing.sm)
    }
    
    // MARK: - Helpers
    
    private func profileRow(icon: String, label: String, value: String) -> some View {
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
    
    private func settingsToggle(icon: String, label: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.primary)
                .frame(width: 24)
            Text(label)
                .font(Theme.Typography.subheadline)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.Colors.primary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 10)
    }
}

// MARK: - Profile Nav Button (Reusable)

struct ProfileNavButton: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Binding var showProfile: Bool
    
    var body: some View {
        Button {
            showProfile = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.Colors.primary.opacity(0.14))
                    .frame(width: 36, height: 36)
                Circle()
                    .strokeBorder(Theme.Colors.primary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 36, height: 36)
                Text(authVM.currentUser?.initials ?? "U")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.Colors.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
