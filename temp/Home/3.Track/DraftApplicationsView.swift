import SwiftUI

struct DraftApplicationsView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Draft Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Home Renovation Loan")
                                .font(.headline)
                            Text("Step: Document Upload")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("₹15,00,000")
                            .font(.title3).bold()
                            .foregroundColor(.mainBlue)
                    }
                    
                    ProgressView(value: 0.6)
                        .tint(.secondaryBlue)
                    
                    HStack {
                        Text("60% Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            router.push(.documentUpload) // Resume from where they left off
                        } label: {
                            Text("Resume Application")
                                .font(.subheadline).bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.mainBlue)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(20)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Draft Applications")
        .navigationBarTitleDisplayMode(.inline)
    }
}
