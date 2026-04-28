import SwiftUI

enum AdminTab: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case loans = "Loans"
    case risk = "Risk"
    case collections = "Collections"
    case reports = "Reports"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .loans: return "doc.text.fill"
        case .risk: return "exclamationmark.shield.fill"
        case .collections: return "indianrupeesign.circle.fill"
        case .reports: return "doc.richtext.fill"
        }
    }
}

struct AdminSidebarView: View {
    // Selection MUST be optional for the sidebar selection to bind correctly on iOS
    @Binding var selectedTab: AdminTab?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        List(selection: $selectedTab) {
            Section {
                ForEach(AdminTab.allCases) { tab in
                    // Using NavigationLink(value:) is the modern way to handle sidebar navigation
                    NavigationLink(value: tab) {
                        Label(tab.rawValue, systemImage: tab.icon)
                            .font(Theme.Typography.subheadline)
                    }
                }
            } header: {
                Text("LMS ADMIN")
                    .font(Theme.Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Menu")
    }
}
