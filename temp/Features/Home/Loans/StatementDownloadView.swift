import SwiftUI

struct StatementDocument: Identifiable {
    let id = UUID()
    let month: String
    let year: String
    let fileSize: String
}

struct StatementDownloadView: View {
    let statements: [StatementDocument] = [
            StatementDocument(month: String(localized: "March"), year: "2026", fileSize: "1.2 MB"),
            StatementDocument(month: String(localized: "February"), year: "2026", fileSize: "1.1 MB"),
            StatementDocument(month: String(localized: "January"), year: "2026", fileSize: "1.3 MB"),
            StatementDocument(month: String(localized: "December"), year: "2025", fileSize: "1.2 MB")
    ]
    
    @State private var showDownloadAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account Statements")
                        .font(.largeTitle).bold()
                    Text("Download your monthly loan and transaction statements in PDF format.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                VStack(spacing: 0) {
                    ForEach(Array(statements.enumerated()), id: \.element.id) { index, doc in
                        HStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.title2)
                                .foregroundColor(.mainBlue)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(doc.month) \(doc.year)")
                                    .font(.headline)
                                Text("PDF • \(doc.fileSize)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                showDownloadAlert = true
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.mainBlue)
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        
                        if index != statements.count - 1 {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 20)
                
            }
            .padding(.bottom, 40)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .alert("Download Complete", isPresented: $showDownloadAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The statement has been saved to your device.")
        }
    }
}

struct StatementDownloadView_Previews: PreviewProvider {
    static var previews: some View {
        StatementDownloadView()
    }
}
