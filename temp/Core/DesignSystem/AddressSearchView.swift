import SwiftUI
import MapKit
import Combine

@available(iOS 18.0, *)
class AddressSearchViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    
    private var completer: MKLocalSearchCompleter
    
    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }
    
    func search() {
        if searchQuery.isEmpty {
            completions = []
        } else {
            completer.queryFragment = searchQuery
        }
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.completions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error
    }
    
    func fetchDetails(for completion: MKLocalSearchCompletion, result: @escaping (MKPlacemark?) -> Void) {
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            guard let placemark = response?.mapItems.first?.placemark else {
                result(nil)
                return
            }
            
            // If we have a postal code, return immediately
            if placemark.postalCode != nil {
                result(placemark)
            } else {
                // Fallback: Reverse geocode the coordinate for more details
                let geocoder = CLGeocoder()
                let location = CLLocation(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
                geocoder.reverseGeocodeLocation(location) { placemarks, _ in
                    if let reversePlace = placemarks?.first {
                        // Create a new MKPlacemark with the better data
                        let detailedPlacemark = MKPlacemark(placemark: reversePlace)
                        result(detailedPlacemark)
                    } else {
                        result(placemark)
                    }
                }
            }
        }
    }
}

@available(iOS 18.0, *)
struct AddressSearchView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = AddressSearchViewModel()
    
    var onSelect: (String, String, String) -> Void // City, State, Pincode
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.completions, id: \.self) { completion in
                    Button {
                        viewModel.fetchDetails(for: completion) { placemark in
                            if let placemark = placemark {
                                let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                                let state = placemark.administrativeArea ?? ""
                                
                                // Fallback: Try to extract pincode from title/subtitle if MapKit doesn't provide it
                                var pincode = placemark.postalCode ?? ""
                                if pincode.isEmpty {
                                    let combinedText = "\(completion.title) \(completion.subtitle)"
                                    // Look for 6 consecutive digits (standard Indian Pincode)
                                    if let range = combinedText.range(of: "\\b\\d{6}\\b", options: .regularExpression) {
                                        pincode = String(combinedText[range])
                                    }
                                }
                                
                                onSelect(city, state, pincode)
                                dismiss()
                            }
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title2)
                                .foregroundColor(DS.primary)
                                .frame(width: 40, height: 40)
                                .background(DS.primary.opacity(0.1))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(.headline)
                                    .foregroundColor(DS.textPrimary)
                                
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(DS.textSecondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundColor(DS.textSecondary.opacity(0.5))
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $viewModel.searchQuery, prompt: "Search for area, city, or pincode")
            .onChange(of: viewModel.searchQuery) { _, _ in
                viewModel.search()
            }
            .navigationTitle("Search Address")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
