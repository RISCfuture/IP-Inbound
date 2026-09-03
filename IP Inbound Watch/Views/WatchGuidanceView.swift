import CoreLocation
import IP_Inbound_Shared
import SwiftUI

/// Drives run-in guidance for the flown target from the watch's own GPS: a countdown while on the
/// ground, a course-deviation indicator once moving. Gates on location availability.
struct WatchGuidanceView: View {
  var target: TargetSnapshot

  @Environment(WatchLocationModel.self)
  private var locationModel

  var body: some View {
    // Tested before the fix, because `accuracyLimited` arrives with one and the CDI must not be
    // drawn from a deliberately coarsened position.
    if let impediment = locationModel.diagnostics.impediment {
      WatchLocationUnavailableView(impediment: impediment)
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
  var impediment: LocationImpediment

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: "location.slash")
    } description: {
      Text(explanation)
    }
    .accessibilityIdentifier(identifier)
  }

  private var title: LocalizedStringKey {
    switch impediment {
      case .locationServicesOff: "Location Services Off"
      case .denied, .restricted: "Location Off"
      case .accuracyLimited: "Precise Location Off"
      case .unavailable: "No GPS"
      case .serviceSessionRequired, .insufficientlyInUse: "Location Paused"
    }
  }

  /// Every remedy is on the iPhone: the watch app has no Settings deep link, and the temporary
  /// full-accuracy prompt is not documented for watchOS.
  private var explanation: LocalizedStringKey {
    switch impediment {
      case .locationServicesOff: "Turn on Location Services in Settings to see guidance."
      case .denied, .restricted: "Allow location access for IP Inbound in Settings to see guidance."
      case .accuracyLimited: "Turn on Precise Location for IP Inbound to see guidance."
      case .unavailable: "Waiting for a GPS fix."
      case .serviceSessionRequired, .insufficientlyInUse: "Raise your wrist to resume guidance."
    }
  }

  private var identifier: String {
    switch impediment {
      case .locationServicesOff, .denied, .restricted: "watchLocationOff"
      case .accuracyLimited: "watchAccuracyLimited"
      case .unavailable: "watchNoGPS"
      case .serviceSessionRequired, .insufficientlyInUse: "watchLocationPaused"
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
