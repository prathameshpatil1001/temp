// MARK: - MessagesView.swift

import SwiftUI

struct MessagesView: View {

    @ObservedObject var vm: MessagesViewModel
    @State private var draftLead: LeadMessagingConnection?
    @State private var draftOfficer: ThreadParticipant?
    @State private var openingMessage: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading messages…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.threads.isEmpty {
                    emptyState
                } else {
                    threadList
                }
            }
            .background(Color.surfaceSecondary)
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        vm.showComposeSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $vm.showComposeSheet) {
                NewConversationSheet(
                    leads: vm.connectableLeads,
                    officers: vm.officerDirectory,
                    selectedLead: $draftLead,
                    selectedOfficer: $draftOfficer,
                    openingMessage: $openingMessage,
                    onCreate: {
                        guard let lead = draftLead, let officer = draftOfficer else { return }
                        vm.createThread(lead: lead, participant: officer, openingMessage: openingMessage)
                        draftLead = nil
                        draftOfficer = nil
                        openingMessage = ""
                        vm.showComposeSheet = false
                    }
                )
            }
        }
    }

    private var threadList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vm.threads) { thread in
                    NavigationLink {
                        ChatView(
                            vm: ChatViewModel(
                                thread: thread,
                                onMessagesUpdated: { messages in
                                    vm.updateThread(thread.id, messages: messages)
                                }
                            )
                        )
                        .onAppear { vm.selectThread(thread) }
                    } label: {
                        ThreadRow(thread: thread)
                    }
                    .buttonStyle(.plain)
                }

                Text("Messages are end-to-end monitored for compliance")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text("No Messages")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Connect a lead to a loan officer and the conversation will appear here.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ThreadRow: View {
    let thread: MessageThread

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                ThreadAvatar(participant: thread.participant)
                if thread.unreadCount > 0 {
                    ZStack {
                        Circle()
                            .fill(Color.brandBlue)
                            .frame(width: 20, height: 20)
                        Text("\(thread.unreadCount)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: -4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(thread.participant.name)
                        .font(.headline)
                        .fontWeight(thread.unreadCount > 0 ? .bold : .semibold)
                    Spacer()
                    Text(thread.lastMessageTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(thread.participant.role.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(thread.participant.role.color)

                if let lead = thread.linkedLeadName, let ref = thread.linkedApplicationRef {
                    Text("\(lead) · \(ref)")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                }

                if let last = thread.lastMessage {
                    Text(last.content)
                        .font(.subheadline)
                        .foregroundStyle(thread.unreadCount > 0 ? .primary : .secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct ConnectionHubCard: View {
    let pendingConnections: Int
    let onAddMessage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Connect Leads To Loan Officers")
                        .font(AppFont.headline())
                        .foregroundColor(Color.textPrimary)
                    Text(
                        pendingConnections > 0
                            ? "\(pendingConnections) leads still need a messaging connection."
                            : "All active leads already have a live officer connection."
                    )
                    .font(AppFont.subhead())
                    .foregroundColor(Color.textSecondary)
                }
                Spacer()
                Image(systemName: "person.2.wave.2.fill")
                    .foregroundColor(Color.brandBlue)
            }

            Button(action: onAddMessage) {
                HStack {
                    Image(systemName: "plus.bubble.fill")
                    Text("Add Message")
                        .font(AppFont.bodyMedium())
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.brandBlue)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.borderLight, lineWidth: 1)
        )
    }
}

struct NewConversationSheet: View {
    let leads: [LeadMessagingConnection]
    let officers: [ThreadParticipant]
    @Binding var selectedLead: LeadMessagingConnection?
    @Binding var selectedOfficer: ThreadParticipant?
    @Binding var openingMessage: String
    let onCreate: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Lead") {
                    Picker(
                        "Lead",
                        selection: Binding(
                            get: { selectedLead?.id },
                            set: { newID in selectedLead = leads.first(where: { $0.id == newID }) }
                        )
                    ) {
                        Text("Select Lead").tag(UUID?.none)
                        ForEach(leads) { lead in
                            Text("\(lead.leadName) · \(lead.applicationRef)")
                                .tag(Optional(lead.id))
                        }
                    }
                }

                Section("Loan Officer") {
                    Picker(
                        "Officer",
                        selection: Binding(
                            get: { selectedOfficer?.id },
                            set: { newID in selectedOfficer = officers.first(where: { $0.id == newID }) }
                        )
                    ) {
                        Text("Select Officer").tag(UUID?.none)
                        ForEach(officers) { officer in
                            Text("\(officer.name) · \(officer.role.rawValue)")
                                .tag(Optional(officer.id))
                        }
                    }
                }

                Section("Opening Message") {
                    TextField("Share context for the officer…", text: $openingMessage, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate()
                        dismiss()
                    }
                    .disabled(selectedLead == nil || selectedOfficer == nil)
                }
            }
        }
    }
}

struct ThreadAvatar: View {
    let participant: ThreadParticipant

    var bgColor: Color {
        switch participant.role {
        case .loanOfficer: return Color(red: 0.82, green: 0.87, blue: 0.97)
        case .manager: return Color(red: 0.9, green: 0.83, blue: 0.97)
        case .system: return Color(.secondarySystemFill)
        case .dstAgent: return Color(.secondarySystemFill)
        }
    }

    var fgColor: Color {
        switch participant.role {
        case .loanOfficer: return Color(red: 0.28, green: 0.4, blue: 0.78)
        case .manager: return .purple
        case .system: return .secondary
        case .dstAgent: return .secondary
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(bgColor).frame(width: 50, height: 50)
            Text(participant.initials)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(fgColor)
        }
    }
}
