import SwiftUI

@available(iOS 18.0, *)
struct DraftApplicationsView: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel = TrackViewModel()

    private var drafts: [BorrowerLoanApplication] {
        viewModel.applications.filter { $0.status == .draft }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if drafts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary)
                        Text("No draft applications")
                            .font(.headline)
                        Text("New borrower applications are currently submitted immediately after creation.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                } else {
                    ForEach(drafts) { application in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(application.loanProductName)
                                        .font(.headline)
                                    Text("Step: Document Upload")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(formatCurrency(application.requestedAmount))
                                    .font(.title3).bold()
                                    .foregroundColor(.mainBlue)
                            }

                            ProgressView(value: 0.5)
                                .tint(.secondaryBlue)

                            HStack {
                                Text("Resume from your saved branch and product configuration.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button {
                                    router.push(.documentUpload(application))
                                } label: {
                                    Text("Resume")
                                        .font(.subheadline).bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(DS.primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }
                    .padding(.top, 20)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Draft Applications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            viewModel.fetchApplications()
        }
    }

    private func formatCurrency(_ raw: String) -> String {
        guard let value = Double(raw) else { return raw }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_IN")
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? raw
    }
}
