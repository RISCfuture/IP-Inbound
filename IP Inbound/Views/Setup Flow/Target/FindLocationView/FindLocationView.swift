import CoreLocation
import MapKit
import SwiftUI

struct FindLocationView: View {
  var onLocationSelected: (CLLocationCoordinate2D, String) -> Void

  @State private var searchText = ""
  @State private var searchCompleter = SearchCompleter()

  var body: some View {
    NavigationStack {
      List(searchCompleter.suggestions, id: \.self) { suggestion in
        SuggestionRow(suggestion: suggestion)
          .contentShape(Rectangle())
          .onTapGesture { select(suggestion) }
          .accessibilityAddTraits(.isButton)
          .accessibilityHint("Use this location")
      }
      .accessibilityIdentifier("findLocationView")
    }
    .searchable(text: $searchText)
    .onChange(of: searchText) {
      searchCompleter.queryFragment = searchText
    }
  }

  private func select(_ suggestion: MKLocalSearchCompletion) {
    Task {
      if let coordinate = await searchCompleter.lookupCoordinates(for: suggestion) {
        onLocationSelected(coordinate, suggestion.title)
      }
    }
  }
}

#Preview {
  FindLocationView { _, _ in }
}
