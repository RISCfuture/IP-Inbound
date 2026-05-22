import MapKit
import Observation

@Observable
class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate {
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

  @MainActor
  func lookupCoordinates(
    for completion: MKLocalSearchCompletion,
    completionHandler: @MainActor @escaping (CLLocationCoordinate2D?) -> Void
  ) {
    let searchRequest = MKLocalSearch.Request(completion: completion)
    let search = MKLocalSearch(request: searchRequest)

    search.start { response, error in
      if let coordinate = response?.mapItems.first?.placemark.coordinate {
        completionHandler(coordinate)
      } else {
        self.error = error ?? LocationSearchError.noResults
        completionHandler(nil)
      }
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
