import SwiftUI

struct SubmitConfirmationView: View {
    let applicationID = "APP-9824-XT"
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success Icon
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
            
            // Text Content
            VStack(spacing: 12) {
                Text("Application Submitted!")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                
                Text("We've successfully received your loan application. Our team is currently reviewing your documents.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            // Application ID Box
            VStack(spacing: 6) {
                Text("Application ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(applicationID)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 40)
            .background(DS.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Actions
            VStack(spacing: 16) {
                Button {
                    router.push(.detailedTracking)
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
                    router.push(.chatConversation(agentName: "Loan Officer"))
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Talk to your Loan Officer")
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

#Preview {
    SubmitConfirmationView()
        .environmentObject(AppRouter())
}
