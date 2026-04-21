import SwiftUI

struct PANResultView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject private var viewModel: KYCViewModel

    private var hasExactMatch: Bool {
        viewModel.panNameMatch && viewModel.panDOBMatch
    }

    var body: some View {
        List {
            Section {
                Text("PAN Verification Result")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.textPrimary)
                    .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
            }

            Section {
                if hasExactMatch {
                    statusCard(
                        title: "PAN details matched",
                        detail: "Name and date of birth matched successfully.",
                        tint: .green
                    )
                } else {
                    statusCard(
                        title: "Partial mismatch detected",
                        detail: mismatchSummary,
                        tint: .orange
                    )
                }
            }

            Section("Additional info") {
                HStack {
                    Text("Aadhaar-PAN linking status")
                    Spacer()
                    Text(viewModel.aadhaarSeedingStatus.isEmpty ? "Unknown" : viewModel.aadhaarSeedingStatus)
                        .foregroundStyle(DS.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("PAN Result")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                PrimaryBtn(title: "Continue") {
                    path.append(KYCRoute.incomeDocuments)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(.regularMaterial)
        }
    }

    private var mismatchSummary: String {
        var parts: [String] = []
        if !viewModel.panNameMatch { parts.append("Name does not match") }
        if !viewModel.panDOBMatch { parts.append("Date of birth does not match") }
        let joined = parts.isEmpty ? "Minor mismatch found." : parts.joined(separator: " • ")
        return "\(joined). Manual review may be required by the lender risk team."
    }

    private func statusCard(title: String, detail: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(DS.textPrimary)
        }
        .padding(12)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
