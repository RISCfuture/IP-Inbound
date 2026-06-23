import MapKit
import Observation

@MainActor
@Observable
class SearchCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
  private(set) var suggestions: [MKLocalSearchCompletion] = []
  private(set) var error: Error?

  private let completer: MKLocalSearchCompleter = {
    let completer = MKLocalSearchCompleter()
    completer.resultTypes = [.address, .pointOfInterest, .physicalFeature]
    return completer
  }()

  var queryFragment: String = "" {
    didSet {
      completer.queryFragment = queryFragment
    }
  }

  override init() {
    super.init()
    completer.delegate = self
  }

  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    suggestions = completer.results
    error = nil
  }

  func completer(_: MKLocalSearchCompleter, didFailWithError error: Error) {
    suggestions = []
    self.error = error
  }

  func lookupCoordinates(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
    let search = MKLocalSearch(request: .init(completion: completion))
    do {
      let response = try await search.start()
      guard let coordinate = response.mapItems.first?.placemark.coordinate else {
        error = LocationSearchError.noResults
        return nil
      }
      return coordinate
    } catch {
      self.error = error
      return nil
    }
  }
}

enum LocationSearchError: LocalizedError {
  case noResults

  var errorDescription: String? {
    String(localized: "Couldn’t find that location.")
  }

  var failureReason: String? {
    switch self {
      case .noResults:
        return String(localized: "No matching place was found for the selected suggestion.")
    }
  }

  var recoverySuggestion: String? {
    String(localized: "Try a different search term.")
  }
}
