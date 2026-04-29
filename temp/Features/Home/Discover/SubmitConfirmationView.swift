import SwiftUI

struct SubmitConfirmationView: View {
    let application: BorrowerLoanApplication

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color(hex: "#00C48C").opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(Color(hex: "#00C48C"))
            }

            VStack(spacing: 12) {
                Text("Application Submitted!")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)

                Text("Your loan request is now running against live backend data, and the latest status will appear in tracking.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 6) {
                Text("Application ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(application.referenceNumber)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 40)
            .background(DS.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Spacer()

            VStack(spacing: 16) {
                Button {
                    router.push(.detailedTracking(application))
                } label: {
                    Text("Track Application Status")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DS.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    router.push(.chatList)
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Talk to Support")
                    }
                    .font(.headline)
                    .foregroundColor(.mainBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    router.popToRoot()
                } label: {
                    Text("Back to Home")
                        .font(.headline)
                        .foregroundColor(.mainBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
