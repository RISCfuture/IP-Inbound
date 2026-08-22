import MeasurementKit
import MeasurementKitLocation
import SwiftUI

/// Airborne display: a simplified course-deviation indicator driven by the watch's GPS. A deviation
/// needle shows which way to steer onto the run-in course — in the phases that fly one — with
/// current/desired track, distance to go, and how early or late the arrival is tracking.
struct WatchCDIView: View {
  var math: IPTargetMath<TargetSnapshot>
  /// Where the aircraft lies relative to the run-in course. `nil` in the phases that steer toward
  /// the IP, which have no course line to deviate from, and hides the needle.
  var deviation: CourseDeviation?

  @ScaledMetric(relativeTo: .headline)
  private var nameFontSize = 16.0

  var body: some View {
    VStack {
      Text(math.target.name)
        .font(.system(size: nameFontSize, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)

      if let deviation {
        DeviationScale(deviation: deviation)
      }

      if let fromTo = math.pposToTarget {
        CDIReadouts(currentTrack: fromTo.trackMagnetic, fromTo: fromTo, target: math.target)
      }
    }
    .padding(.horizontal)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("watchCDI")
  }
}

// MARK: - Deviation needle

private struct DeviationScale: View {
  /// Distance between adjacent dot centers. Every dot is laid out in a frame of the same width, so
  /// the pitch stays uniform across the row whatever size each dot is drawn at.
  private static let dotPitch: CGFloat = 28
  private static let dotFrame: CGFloat = 6

  /// Full-scale needle travel, which lands the needle on the outermost dot — so one dot reads half
  /// of ``CourseDeviation/fullScale``.
  private static let fullScaleOffset = dotPitch * 2

  private static let centerDotSize: CGFloat = 6,
    outerDotSize: CGFloat = 4

  private static let needleWidth: CGFloat = 4,
    needleHeight: CGFloat = 34,
    scaleHeight: CGFloat = 36

  var deviation: CourseDeviation

  var body: some View {
    ZStack {
      HStack(spacing: Self.dotPitch - Self.dotFrame) {
        ForEach(-2...2, id: \.self) { dot in
          let size = dot == 0 ? Self.centerDotSize : Self.outerDotSize
          Circle()
            .fill(.secondary)
            .frame(width: size, height: size)
            .frame(width: Self.dotFrame)
        }
      }
      Capsule()
        .fill(.tint)
        .frame(width: Self.needleWidth, height: Self.needleHeight)
        .offset(x: deviation.needleOffset * Self.fullScaleOffset)
        .animation(.easeOut(duration: 0.2), value: deviation.needleOffset)
    }
    .frame(height: Self.scaleHeight)
    .accessibilityElement()
    .accessibilityLabel(Text("Course deviation"))
    .accessibilityValue(Text(deviation.announcement()))
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
  if let math = WatchPreviewData.math() {
    WatchCDIView(math: math, deviation: math.courseDeviation)
  }
}

#Preview("Left of Course") {
  if let math = WatchPreviewData.math(offsetEastNM: 2) {
    WatchCDIView(math: math, deviation: math.courseDeviation)
  }
}

#Preview("Right of Course") {
  if let math = WatchPreviewData.math(offsetEastNM: -2) {
    WatchCDIView(math: math, deviation: math.courseDeviation)
  }
}

#Preview("Steering to the IP") {
  if let math = WatchPreviewData.math() {
    WatchCDIView(math: math, deviation: nil)
  }
}
