//
//  ManagerMessagesView.swift
//  lms_project
//

import SwiftUI

struct ManagerMessagesView: View {
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Binding var showProfile: Bool
    
    var body: some View {
        LOMessagesView(showProfile: $showProfile)
            .environmentObject(messagesVM)
    }
}
