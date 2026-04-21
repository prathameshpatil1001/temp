import SwiftUI

struct ESignatureView: View {
    @Binding var path: NavigationPath

    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("E-Signature")
                    .font(.title2.bold())
                Text("Capture your signature to proceed.")
                    .foregroundStyle(DS.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .frame(height: 220)
                .overlay(Text("Signature pad placeholder"))

            Spacer()

            PrimaryBtn(title: "Continue") {
                path.append(KYCRoute.review)
            }
        }
        .padding(20)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("E-Signature")
        .navigationBarTitleDisplayMode(.inline)
    }
}
