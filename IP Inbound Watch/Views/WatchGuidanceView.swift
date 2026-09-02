import CoreLocation
import SwiftUI

/// Drives run-in guidance for the flown target from the watch's own GPS: a countdown while on the
/// ground, a course-deviation indicator once moving. Gates on location availability.
struct WatchGuidanceView: View {
  var target: TargetSnapshot

  @Environment(WatchLocationModel.self)
  private var locationModel

  var body: some View {
    if locationModel.authorizationDenied {
      WatchLocationUnavailableView()
    } else if let location = locationModel.location {
      WatchLocatedGuidance(location: location, target: target)
    } else {
      WatchAcquiringFixView()
    }
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

/// Chooses between the airborne indicator and the countdown for a fix, and hands the indicator the
/// run-in geometry and the deviation its phase calls for. A fix carrying no usable ground speed or
/// course has no geometry to solve, so the countdown stands until one arrives.
private struct WatchLocatedGuidance: View {
  var location: CLLocation
  var target: TargetSnapshot

  var body: some View {
    if let math = IPTargetMath(location: location, target: target, now: Date()) {
      let helper = GuidanceHelper(math: math, location: location, target: target)
      if helper.isMoving {
        WatchCDIView(math: math, deviation: helper.courseDeviation)
      } else {
        WatchCountdownView(target: target)
      }
    } else {
      WatchCountdownView(target: target)
    }
  }
}

#Preview("On Ground") {
  WatchGuidanceView(target: WatchPreviewData.target)
    .environment(WatchLocationModel())
}
