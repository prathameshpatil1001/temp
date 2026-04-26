import Foundation

struct BorrowerBranch: Identifiable, Hashable {
    let id: String
    let name: String
    let region: String
    let city: String

    var locationLabel: String {
        let parts = [city, region]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? "Location unavailable" : parts.joined(separator: ", ")
    }
}
