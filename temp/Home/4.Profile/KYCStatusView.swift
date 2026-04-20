import SwiftUI

struct KYCStatusView: View {
    @EnvironmentObject private var session: SessionStore
    @State private var showKYCFlow = false

    private var bannerIcon: String {
        switch session.kycStatus {
        case .approved:
            return "checkmark.seal.fill"
        case .pending:
            return "clock.badge.checkmark.fill"
        case .rejected:
            return "xmark.octagon.fill"
        case .notStarted:
            return "shield.lefthalf.filled"
        }
    }

    private var bannerColor: Color {
        switch session.kycStatus {
        case .approved:
            return Color(hex: "#00C48C")
        case .pending:
            return .secondaryBlue
        case .rejected:
            return .alertRed
        case .notStarted:
            return .mainBlue
        }
    }

    private var bannerTitle: String {
        switch session.kycStatus {
        case .approved:
            return "KYC Verified"
        case .pending:
            return "Verification In Progress"
        case .rejected:
            return "Verification Needs Attention"
        case .notStarted:
            return "Complete Your Profile"
        }
    }

    private var bannerMessage: String {
        switch session.kycStatus {
        case .approved:
            return "Your identity has been fully verified. You are eligible for instant loan disbursals."
        case .pending:
            return "We are reviewing your details. You can reopen the flow to continue from the latest verification step."
        case .rejected:
            return "A part of your verification could not be completed. Reopen the flow to review your details and try again."
        case .notStarted:
            return "Finish identity verification to unlock the full post-login experience and loan journey."
        }
    }

    private var actionTitle: String? {
        switch session.kycStatus {
        case .approved:
            return nil
        case .pending:
            return "Continue Verification"
        case .rejected:
            return "Retry Verification"
        case .notStarted:
            return "Start Verification"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusBanner
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                if session.kycStatus == .approved {
                    documentsSection
                } else {
                    nextStepSection
                        .padding(.horizontal, 20)
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("KYC Status")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showKYCFlow) {
            KYCFlowController()
        }
    }

    private var statusBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: bannerIcon)
                .font(.system(size: 60))
                .foregroundColor(bannerColor)

            Text(bannerTitle)
                .font(.title2)
                .bold()

            Text(bannerMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if let actionTitle {
                Button {
                    showKYCFlow = true
                } label: {
                    Text(actionTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(bannerColor)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 30)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Verified Documents")
                .font(.headline)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                KYCDocRow(title: "PAN Card", docID: "ABCDE1234F", date: "Verified on 12 Jan 2025")
                Divider().padding(.leading, 20)
                KYCDocRow(title: "Aadhaar Card", docID: "XXXX XXXX 1234", date: "Verified on 12 Jan 2025")
                Divider().padding(.leading, 20)
                KYCDocRow(title: "Bank Account", docID: "HDFC Bank •••• 4567", date: "Verified on 14 Jan 2025")
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 20)
        }
    }

    private var nextStepSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What happens next")
                .font(.headline)

            Text(nextStepDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }

    private var nextStepDescription: String {
        switch session.kycStatus {
        case .approved:
            return ""
        case .pending:
            return "Keep your documents handy. The verification screens will resume from the latest available state."
        case .rejected:
            return "Review the submitted details, retake any missing proofs, and submit again for approval."
        case .notStarted:
            return "You will be guided through profile details, address proof, income details, e-signature, and identity verification."
        }
    }
}

struct KYCDocRow: View {
    let title: String
    let docID: String
    let date: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "doc.text.viewfinder")
                .font(.title2)
                .foregroundColor(.mainBlue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(docID).font(.subheadline).foregroundColor(.secondary)
                Text(date).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(Color(hex: "#00C48C"))
                Text("Verified").font(.caption2).bold().foregroundColor(Color(hex: "#00C48C"))
            }
        }
        .padding(16)
    }
}
