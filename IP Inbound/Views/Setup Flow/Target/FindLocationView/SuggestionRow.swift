import MapKit
import SwiftUI

struct SuggestionRow: View {
  let suggestion: MKLocalSearchCompletion

  var body: some View {
    VStack(alignment: .leading) {
      Text(suggestion.title).bold()
      if !suggestion.subtitle.isEmpty {
        Text(suggestion.subtitle).font(.subheadline).foregroundStyle(.secondary)
      }
    }
  }
}

#Preview {
  List {
    SuggestionRow(suggestion: MKLocalSearchCompletion())
  }
}
