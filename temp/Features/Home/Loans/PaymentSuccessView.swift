import SwiftUI

struct PaymentSuccessView: View {
    let transactionID: String
    @EnvironmentObject var router: AppRouter
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "#00C48C").opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .foregroundColor(Color(hex: "#00C48C"))
            }
            
            VStack(spacing: 12) {
                Text("Payment Successful!")
                    .font(.largeTitle).bold()
                    .multilineTextAlignment(.center)
                
                Text("Your Razorpay payment was verified successfully and your EMI has been recorded against the loan.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(spacing: 6) {
                Text("Transaction ID")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(transactionID)
                    .font(.title3).bold()
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 40)
            .background(DS.primaryLight.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            Button {
                router.popToRoot() // Takes them back to the Home Dashboard
            } label: {
                Text("Back to Home")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(DS.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemBackground).ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
