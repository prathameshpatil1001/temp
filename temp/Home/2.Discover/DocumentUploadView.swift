import SwiftUI
import Combine

// MARK: - Models
enum UploadState: Equatable {
    case pending
    case uploading(progress: Double)
    case completed
}

struct DocumentItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    var state: UploadState = .pending
}

// MARK: - View Model
class DocumentUploadViewModel: ObservableObject {
    @Published var documents: [DocumentItem] = [
        DocumentItem(title: "PAN Card", subtitle: "Front side of your PAN", icon: "person.text.rectangle"),
        DocumentItem(title: "Aadhaar Card", subtitle: "Front & Back combined PDF/Image", icon: "building.columns.fill"),
        DocumentItem(title: "Bank Statement", subtitle: "Last 6 months (PDF)", icon: "doc.text.fill"),
        DocumentItem(title: "Salary Slip", subtitle: "Most recent month", icon: "dollarsign.square.fill")
    ]
    
    var allDocumentsUploaded: Bool {
        documents.allSatisfy { $0.state == .completed }
    }
    
    // Simulates a network upload
    func simulateUpload(for id: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else { return }
        
        documents[index].state = .uploading(progress: 0.1)
        
        // Timer to simulate progress
        var currentProgress = 0.1
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            currentProgress += Double.random(in: 0.1...0.3)
            
            if currentProgress >= 1.0 {
                self.documents[index].state = .completed
                timer.invalidate()
            } else {
                self.documents[index].state = .uploading(progress: currentProgress)
            }
        }
    }
}

// MARK: - Main View
struct DocumentUploadView: View {
    @StateObject var viewModel = DocumentUploadViewModel()
    @EnvironmentObject var router: Router // Added Router here
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Upload Documents")
                            .font(.largeTitle).bold()
                        Text("We need a few documents to verify your identity and process your loan.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 20)
                    
                    // Document List
                    VStack(spacing: 16) {
                        ForEach(viewModel.documents) { doc in
                            DocumentCardView(document: doc) {
                                viewModel.simulateUpload(for: doc.id)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100) // Padding for sticky button
                }
            }
            
            // Sticky Footer Button
            VStack {
                Divider()
                Button {
                    router.push(.reviewApplication) // Routing to Review Application
                } label: {
                    Text("Submit Application")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(viewModel.allDocumentsUploaded ? Color.mainBlue : Color.secondary.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!viewModel.allDocumentsUploaded)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGroupedBackground))
            }
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Subcomponents
struct DocumentCardView: View {
    let document: DocumentItem
    let uploadAction: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            
            // Icon
            ZStack {
                Circle()
                    .fill(document.state == .completed ? Color(hex: "#00C48C").opacity(0.15) : Color.lightBlue)
                    .frame(width: 50, height: 50)
                
                if document.state == .completed {
                    Image(systemName: "checkmark")
                        .font(.title3).bold()
                        .foregroundColor(Color(hex: "#00C48C"))
                } else {
                    Image(systemName: document.icon)
                        .font(.title3)
                        .foregroundColor(.mainBlue)
                }
            }
            
            // Text Info
            VStack(alignment: .leading, spacing: 4) {
                Text(document.title)
                    .font(.headline)
                Text(document.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Button / Progress
            switch document.state {
            case .pending:
                Button(action: uploadAction) {
                    Image(systemName: "icloud.and.arrow.up")
                        .font(.title2)
                        .foregroundColor(.secondaryBlue)
                        .padding(10)
                        .background(Color.lightBlue)
                        .clipShape(Circle())
                }
            case .uploading(let progress):
                CircularProgressView(progress: progress)
                    .frame(width: 32, height: 32)
            case .completed:
                Text("Done")
                    .font(.subheadline).bold()
                    .foregroundColor(Color(hex: "#00C48C"))
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// Custom Progress Spinner
struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.lightBlue, lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.secondaryBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.3), value: progress)
        }
    }
}

#Preview {
    NavigationStack {
        DocumentUploadView()
    }
}
