import CoreLocation
import SwiftUI

struct FindLocationView: View {
    @State private var searchText = ""
    @State private var searchCompleter = SearchCompleter()

    var onLocationSelected: (CLLocationCoordinate2D, String) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                List(searchCompleter.suggestions, id: \.self) { suggestion in
                    VStack(alignment: .leading) {
                        Text(suggestion.title).bold()
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        searchCompleter.lookupCoordinates(for: suggestion) { coordinate in
                            if let coordinate {
                                onLocationSelected(coordinate, suggestion.title)
                            }
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Use this location")
                }
            }
        }
        .searchable(text: $searchText)
        .onChange(of: searchText) {
            searchCompleter.queryFragment = searchText
        }
    }
}

#Preview {
    FindLocationView { _, _ in }
}
