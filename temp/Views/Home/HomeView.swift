// Views/Home/HomeView.swift
// LoanOS — Borrower App
// Signed-in shell using the Home1 post-login experience.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        ContentView()
            .navigationBarBackButtonHidden(true)
            .onAppear {
                session.justLoggedIn = false
            }
    }
}
