import SwiftUI

struct ReviewDocumentView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    var body: some View {
        List {
            Section("Review") {
                row("Aadhaar", value: viewModel.isAadhaarVerified ? "Verified" : "Pending")
                row("PAN", value: viewModel.isPanVerified ? "Verified" : "Pending")
                row("Selfie", value: viewModel.selfieImageData == nil ? "Pending backend" : "Captured")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Review & Submit")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryBtn(title: "Continue") {
                    path.append(KYCRoute.submissionSummary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(DS.textSecondary)
        }
    }
}
