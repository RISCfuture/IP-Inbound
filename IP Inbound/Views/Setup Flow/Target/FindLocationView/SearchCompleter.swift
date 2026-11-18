import MapKit
import Observation

@MainActor
@Observable
class SearchCompleter: NSObject, @preconcurrency MKLocalSearchCompleterDelegate {
  private(set) var suggestions: [MKLocalSearchCompletion] = []

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
  }

  func completer(_: MKLocalSearchCompleter, didFailWithError _: any Error) {
    suggestions = []
  }

  func lookupCoordinates(for completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
    let response = try? await MKLocalSearch(request: .init(completion: completion)).start()
    return response?.mapItems.first?.location.coordinate
  }
}
