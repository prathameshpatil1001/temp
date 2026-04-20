// Views/Welcome/WelcomeView.swift
// LoanOS — Borrower App
// Unauthenticated entry screen.

import SwiftUI

struct WelcomeView: View {
    var bannerMessage: String? = nil
    var onDismissBanner: () -> Void = {}
    let onGoToLogin: () -> Void
    let onGoToSignup: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Brand Logo
            Image(systemName: "building.columns.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(DS.primary)
            
            Text("Karz")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(DS.textPrimary)
            
            Text("Your loans, sorted.")
                .font(.system(size: 16))
                .foregroundColor(DS.textSecondary)

            if let bannerMessage {
                InfoCard(icon: "exclamationmark.triangle.fill", color: DS.warning, text: bannerMessage)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
                    .onTapGesture(perform: onDismissBanner)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: onGoToSignup) {
                    Text("Sign Up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DS.primary)
                        .cornerRadius(14)
                }
                .buttonStyle(TapScale())
                
                Button(action: onGoToLogin) {
                    Text("Log In")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DS.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(DS.primary, lineWidth: 1.5)
                        )
                }
                .buttonStyle(TapScale())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
        .background(
            LinearGradient(
                colors: [Color.white, DS.surface],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
}

#Preview {
    WelcomeView(onGoToLogin: {}, onGoToSignup: {})
}
