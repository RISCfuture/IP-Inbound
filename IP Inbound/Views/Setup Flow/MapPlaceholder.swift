import SwiftUI

/// Stands in for a MapKit `Map` when the app is running under XCUITest.
///
/// MapKit's continuous tile loading and camera callbacks prevent XCTest's
/// `waitForQuiescenceIncludingAnimationsIdle` from returning on slower
/// simulators, adding a 60-second stall to every simulated tap. This view
/// keeps the surrounding layout intact while the real map is suppressed.
struct MapPlaceholder: View {
  var body: some View {
    Rectangle()
      .fill(.gray.opacity(0.15))
      .padding()
      .accessibilityHidden(true)
  }
}

#Preview {
  MapPlaceholder()
}
