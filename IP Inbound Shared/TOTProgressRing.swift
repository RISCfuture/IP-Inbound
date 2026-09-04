public import Foundation
import MeasurementKit
public import SwiftUI

/// A self-updating circular countdown to a time on target, for the places a textual countdown clips:
/// the minimal Dynamic Island, and the watch face's smallest complication families.
///
/// Full extent is the IP-to-target leg — full while the aircraft is still inbound to the IP, emptying
/// over the final `legDuration` to the time on target.
public struct TOTProgressRing: View {
  private static let minimumLegDuration = Measurement(value: 1, unit: UnitDuration.seconds)

  /// The briefed time on target the ring empties toward.
  public var timeOnTarget: Date

  /// How long the run-in leg takes, which is how much of the ring is drawn.
  public var legDuration: Measurement<UnitDuration>

  /// Whether the countdown is drawn inside the ring. Only the circular complication has the room:
  /// the corner family draws against the bezel and puts its countdown in the widget label, and the
  /// minimal Dynamic Island is the tightest draw of all.
  public var showsCountdown: Bool

  private var ringRange: ClosedRange<Date> {
    let extent = max(legDuration, Self.minimumLegDuration)
    return (timeOnTarget - extent)...timeOnTarget
  }

  public var body: some View {
    ProgressView(timerInterval: ringRange, countsDown: true) {
      EmptyView()
    } currentValueLabel: {
      if showsCountdown {
        TOTCountdownText(timeOnTarget: timeOnTarget, font: .caption2)
      }
    }
    .progressViewStyle(.circular)
    .accessibilityLabel(Text("Time on target countdown", bundle: .guidance))
  }

  public init(
    timeOnTarget: Date,
    legDuration: Measurement<UnitDuration>,
    showsCountdown: Bool = false
  ) {
    self.timeOnTarget = timeOnTarget
    self.legDuration = legDuration
    self.showsCountdown = showsCountdown
  }
}
