import CoreLocation
import SwiftUI

/// Drives run-in guidance for the flown target from the watch's own GPS: a countdown while on the
/// ground, a course-deviation indicator once moving. Gates on location availability.
struct WatchGuidanceView: View {
  var target: TargetSnapshot

  @Environment(WatchLocationModel.self)
  private var locationModel

  var body: some View {
    Group {
      if locationModel.authorizationDenied {
        WatchLocationUnavailableView()
      } else if let location = locationModel.location {
        let helper = GuidanceHelper(location: location, target: target, now: Date())
        if helper.isMoving {
          WatchCDIView(location: location, target: target)
        } else {
          WatchCountdownView(target: target)
        }
      } else {
        WatchAcquiringFixView()
      }
    }
    .onAppear { locationModel.start() }
    .onDisappear { locationModel.stop() }
  }
}

private struct WatchAcquiringFixView: View {
  @ScaledMetric(relativeTo: .footnote)
  private var helpFontSize = 14.0

  var body: some View {
    VStack {
      ProgressView()
      Text("Acquiring GPS…")
        .font(.system(size: helpFontSize))
        .foregroundStyle(.secondary)
    }
  }
}

private struct WatchLocationUnavailableView: View {
  var body: some View {
    ContentUnavailableView {
      Label("Location Off", systemImage: "location.slash")
    } description: {
      Text("Allow location access for IP Inbound in Settings to see guidance.")
    }
  }
}

#Preview("On Ground") {
  WatchGuidanceView(target: WatchPreviewData.target)
    .environment(WatchLocationModel())
}
