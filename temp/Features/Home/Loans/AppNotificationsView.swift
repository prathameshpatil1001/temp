import SwiftUI

struct SystemNotification: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let time: String
    let isUnread: Bool
    let type: NotificationType
}

enum NotificationType {
    case alert, reminder, offer, general
    
    var icon: String {
        switch self {
        case .alert: return "exclamationmark.triangle.fill"
        case .reminder: return "calendar.badge.clock"
        case .offer: return "star.fill"
        case .general: return "bell.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .alert: return .alertRed
        case .reminder: return .mainBlue
        case .offer: return Color(hex: "#00C48C")
        case .general: return .secondary
        }
    }
}

struct AppNotificationsView: View {
    @State var notifications: [SystemNotification] = [
        SystemNotification(title: "EMI Due Soon", message: "Your next EMI of ₹14,200 is due in 6 days. Keep your account funded to avoid late fees.", time: "2 hours ago", isUnread: true, type: .alert),
        SystemNotification(title: "Statement Ready", message: "Your account statement for March 2026 is now available for download.", time: "1 day ago", isUnread: true, type: .general),
        SystemNotification(title: "Cashback Credited!", message: "Congratulations! ₹500 cashback has been credited to your loan account for timely payment.", time: "3 days ago", isUnread: false, type: .offer),
        SystemNotification(title: "Payment Received", message: "We have successfully received your payment of ₹14,200.", time: "18 Mar", isUnread: false, type: .reminder)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Notifications")
                            .font(.largeTitle).bold()
                        Text("You have \(notifications.filter { $0.isUnread }.count) unread messages.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Mark all read") {
                        // Mark all as read logic
                    }
                    .font(.subheadline).bold()
                    .foregroundColor(.mainBlue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 8)
                
                ForEach(notifications) { notif in
                    HStack(alignment: .top, spacing: 16) {
                        
                        // Icon
                        Image(systemName: notif.type.icon)
                            .font(.title3)
                            .foregroundColor(notif.type.color)
                            .frame(width: 44, height: 44)
                            .background(notif.type.color.opacity(0.1))
                            .clipShape(Circle())
                        
                        // Content
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(notif.title)
                                    .font(.headline)
                                Spacer()
                                Text(notif.time)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(notif.message)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                        
                        // Unread Dot
                        if notif.isUnread {
                            Circle()
                                .fill(DS.primary)
                                .frame(width: 8, height: 8)
                                .padding(.top, 6)
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, 20)
                }
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AppNotificationsView_Previews: PreviewProvider {
    static var previews: some View {
        AppNotificationsView()
    }
}
