import SwiftUI

struct LoanHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // Closed Loan Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Education Loan")
                                .font(.headline)
                            Text("Closed on 10 Oct 2025")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("Closed")
                            .font(.caption).bold()
                            .foregroundColor(Color(hex: "#00C48C"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#00C48C").opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total Amount").font(.caption).foregroundColor(.secondary)
                            Text("₹8,00,000").font(.subheadline).bold()
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Tenure").font(.caption).foregroundColor(.secondary)
                            Text("36 Months").font(.subheadline).bold()
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        // Download NDC Action
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Download No Dues Certificate")
                        }
                        .font(.subheadline).bold()
                        .foregroundColor(.mainBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.lightBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        .navigationTitle("Loan History")
        .navigationBarTitleDisplayMode(.inline)
    }
}
