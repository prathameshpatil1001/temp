//
//  AdminMessagesView.swift
//  lms_project
//

import SwiftUI

struct AdminMessagesView: View {
    @EnvironmentObject var messagesVM: MessagesViewModel
    @Binding var showProfile: Bool
    
    var body: some View {
        LOMessagesView(showProfile: $showProfile)
            .environmentObject(messagesVM)
    }
}
