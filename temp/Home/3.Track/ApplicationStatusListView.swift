import SwiftUI

struct ApplicationStatusListView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Applications")
                        .font(.largeTitle).bold()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Track and manage all your loan requests.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                // Active Application Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Active")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    Button {
                        router.push(.detailedTracking)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.lightBlue)
                                    .frame(width: 50, height: 50)
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.mainBlue)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Personal Loan")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("App ID: APP-9824-XT")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("In Progress")
                                    .font(.caption).bold()
                                    .foregroundColor(.mainBlue)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.lightBlue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }
                }
                
                // Draft Applications Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Drafts")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    Button {
                        router.push(.draftApplications)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.secondary)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Home Renovation")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Last saved 2 days ago")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }
                }
                
                // Past/Rejected
                VStack(alignment: .leading, spacing: 16) {
                    Text("Past Applications")
                        .font(.headline)
                        .padding(.horizontal, 20)
                    
                    Button {
                        router.push(.rejectionReason)
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(Color.alertRed.opacity(0.1))
                                    .frame(width: 50, height: 50)
                                Image(systemName: "xmark")
                                    .foregroundColor(.alertRed)
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Loan")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("App ID: APP-4011-RX")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("Unsuccessful")
                                .font(.caption).bold()
                                .foregroundColor(.alertRed)
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}
