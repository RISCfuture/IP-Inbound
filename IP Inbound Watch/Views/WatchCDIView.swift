import CoreLocation
import MeasurementKit
import MeasurementKitLocation
import SwiftUI

/// Airborne display: a simplified course-deviation indicator driven by the watch's GPS. A deviation
/// needle shows which way to steer onto the run-in course, with current/desired track, distance to
/// go, and how early or late the arrival is tracking.
struct WatchCDIView: View {
  var location: CLLocation
  var target: TargetSnapshot

  @ScaledMetric(relativeTo: .headline)
  private var nameFontSize = 16.0

  var body: some View {
    // A fix with no usable ground speed or course has no run-in geometry to draw; the countdown is
    // what the watch shows until one arrives.
    if let math = IPTargetMath(location: location, target: target, now: Date()) {
      VStack {
        Text(target.name)
          .font(.system(size: nameFontSize, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        DeviationScale(crossTrackDistance: math.crossTrackDistance)

        if let fromTo = math.pposToTarget {
          CDIReadouts(currentTrack: fromTo.trackMagnetic, fromTo: fromTo, target: target)
        }
      }
      .padding(.horizontal)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("watchCDI")
    } else {
      WatchCountdownView(target: target)
    }
  }
}

// MARK: - Deviation needle

private struct DeviationScale: View {
  private static let scale = Measurement(value: 4, unit: UnitLength.nauticalMiles)
  private static let maxOffset: CGFloat = 56

  var crossTrackDistance: Measurement<UnitLength>

  /// Signed deflection in `[-1, 1]`; positive means the aircraft is right of course.
  private var deflection: CGFloat {
    CGFloat(max(-1, min(1, crossTrackDistance / Self.scale)))
  }

  var body: some View {
    ZStack {
      HStack(spacing: 14) {
        ForEach(0..<5) { index in
          Circle()
            .fill(.secondary)
            .frame(width: index == 2 ? 6 : 4, height: index == 2 ? 6 : 4)
        }
      }
      // The course lies on the side the aircraft must steer toward, so the needle deflects opposite
      // the cross-track sign: right of course → needle left → fly left.
      Capsule()
        .fill(.tint)
        .frame(width: 4, height: 34)
        .offset(x: -deflection * Self.maxOffset)
        .animation(.easeOut(duration: 0.2), value: deflection)
    }
    .frame(height: 36)
    .accessibilityElement()
    .accessibilityLabel(Text("Course deviation"))
    .accessibilityValue(Text(deviationDescription))
  }

  private var deviationDescription: String {
    guard crossTrackDistance.magnitude > .zero else { return String(localized: "On course.") }
    let distance = crossTrackDistance.magnitude.converted(to: .nauticalMiles)
    let formatted = distance.formatted(distanceFormatStyle)
    return crossTrackDistance > .zero
      ? String(localized: "\(formatted) right of course.")
      : String(localized: "\(formatted) left of course.")
  }
}

// MARK: - Readouts

private struct CDIReadouts: View {
  var currentTrack: MagneticBearing
  var fromTo: FromToMath
  var target: TargetSnapshot

  @ScaledMetric(relativeTo: .caption)
  private var readoutFontSize = 14.0

  var body: some View {
    VStack(spacing: 2) {
      LabeledReadout(title: "Track", value: Text(currentTrack, format: .bearing))
      LabeledReadout(
        title: "DTK",
        value: Text(target.desiredTrackMagnetic, format: .bearing),
        accessory: TurnArrow(currentTrack: currentTrack, desiredTrack: target.desiredTrackMagnetic)
      )
      LabeledReadout(title: "ETE", value: TimingReadout(fromTo: fromTo))
      LabeledReadout(
        title: "DTG",
        value: Text(fromTo.distance.converted(to: .nauticalMiles), format: distanceFormatStyle)
      )
    }
    .font(.system(size: readoutFontSize))
  }
}

/// The early/late readout: the timing tier’s direction icon next to the magnitude of the time error as
/// a duration, tinted by tier — mirroring the Fly view’s timing display.
private struct TimingReadout: View {
  var fromTo: FromToMath

  private var tier: TimingTier {
    .init(fromTo: fromTo, timeOnTarget: fromTo.timeOnTarget)
  }

  var body: some View {
    Label {
      Text(
        fromTo.timeOfArrival,
        format: .offset(to: fromTo.timeOnTarget, maxFieldCount: 1, sign: .never)
      )
    } icon: {
      Image(systemName: tier.systemImage)
        .accessibilityHidden(true)
    }
    .foregroundStyle(tier.color)
  }
}

/// A small directional arrow hinting which way to turn from the current track onto the desired
/// track — right for a clockwise turn, left for counterclockwise — and nothing when already aligned.
private struct TurnArrow: View {
  private static let alignedThresholdDegrees = 1.0

  var currentTrack: MagneticBearing
  var desiredTrack: MagneticBearing

  private var turnDegrees: Double { currentTrack.shortestTurn(to: desiredTrack).degrees }

  var body: some View {
    if abs(turnDegrees) >= Self.alignedThresholdDegrees {
      Image(systemName: turnDegrees > 0 ? "arrow.right" : "arrow.left")
        .foregroundStyle(.secondary)
        .accessibilityLabel(turnDegrees > 0 ? Text("Turn right") : Text("Turn left"))
    }
  }
}

private struct LabeledReadout<Value: View, Accessory: View>: View {
  var title: LocalizedStringKey
  var value: Value
  var accessory: Accessory

  var body: some View {
    HStack {
      Text(title).foregroundStyle(.secondary)
      accessory
      Spacer()
      value.fontWeight(.semibold)
    }
  }

  init(title: LocalizedStringKey, value: Value, accessory: Accessory) {
    self.title = title
    self.value = value
    self.accessory = accessory
  }
}

extension LabeledReadout where Accessory == EmptyView {
  init(title: LocalizedStringKey, value: Value) {
    self.init(title: title, value: value, accessory: EmptyView())
  }
}

#Preview("On Course") {
  WatchCDIView(
    location: WatchPreviewData.location(speedKnots: 250, course: 0),
    target: WatchPreviewData.target
  )
}

#Preview("Right of Course") {
  WatchCDIView(
    location: WatchPreviewData.location(speedKnots: 250, course: 0, offsetEastNM: 2),
    target: WatchPreviewData.target
  )
}
