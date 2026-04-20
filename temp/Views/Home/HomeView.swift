// Views/Home/HomeView.swift
// LoanOS — Borrower App
// Signed-in shell using the Home1 post-login experience.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showKYCFlow = false

    var body: some View {
        ContentView()
            .navigationBarBackButtonHidden(true)
            .fullScreenCover(isPresented: $showKYCFlow) {
                KYCFlowController()
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
        if session.pendingKYCRoute != nil {
            showKYCFlow = true
        }
    }
}
