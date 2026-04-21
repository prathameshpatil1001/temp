// Features/Home/Shell/HomeView.swift
// LoanOS — Borrower App
// Signed-in shell using the home post-login experience.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showKYCFlow = false

    var body: some View {
        MainTabView()
            .navigationBarBackButtonHidden(true)
            .fullScreenCover(isPresented: $showKYCFlow) {
                if #available(iOS 18.0, *) {
                    KYCFlowController(fullName: session.userName)
                } else {
                    // KYC requires iOS 18. Show a message for older devices.
                    Text("KYC verification requires iOS 18 or later.")
                        .padding()
                }
            }
            .onAppear {
                session.justLoggedIn = false
                openPendingKYCRouteIfNeeded()
            }
            .onChange(of: session.pendingKYCRoute) { _, _ in
                openPendingKYCRouteIfNeeded()
            }
    }

    private func openPendingKYCRouteIfNeeded() {
        guard session.pendingKYCRoute != nil,
              session.kycStatus != .approved,
              !showKYCFlow else { return }
        showKYCFlow = true
    }
}
