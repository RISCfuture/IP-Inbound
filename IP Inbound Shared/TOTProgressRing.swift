import Foundation
import MeasurementKit
import SwiftUI

/// A self-updating circular countdown to a time on target, for the places a textual countdown clips:
/// the minimal Dynamic Island, and the watch face's smallest complication families.
///
/// Full extent is the IP-to-target leg — full while the aircraft is still inbound to the IP, emptying
/// over the final `legDuration` to the time on target. The labels are suppressed so only the ring
/// shows.
public struct TOTProgressRing: View {
  private static let minimumLegDuration = Measurement(value: 1, unit: UnitDuration.seconds)

  /// The briefed time on target the ring empties toward.
  public var timeOnTarget: Date

  /// How long the run-in leg takes, which is how much of the ring is drawn.
  public var legDuration: Measurement<UnitDuration>

  /// How much of the ring is drawn, floored at a second.
  ///
  /// The floor also catches a leg that never divided to a duration at all: a target briefed with no
  /// ground speed divides to infinity, and one with no offset distance either divides to nothing.
  /// Neither is an extent a ring can be scaled against, and neither is a bound a range can be built
  /// from.
  private var extent: Measurement<UnitDuration> {
    guard legDuration.value.isFinite else { return Self.minimumLegDuration }
    return max(legDuration, Self.minimumLegDuration)
  }

  private var ringRange: ClosedRange<Date> {
    (timeOnTarget - extent)...timeOnTarget
  }

  public var body: some View {
    ProgressView(timerInterval: ringRange, countsDown: true) {
      EmptyView()
    } currentValueLabel: {
      EmptyView()
    }
    .progressViewStyle(.circular)
    .accessibilityLabel(Text("Time on target countdown", bundle: .guidance))
  }

  public init(timeOnTarget: Date, legDuration: Measurement<UnitDuration>) {
    self.timeOnTarget = timeOnTarget
    self.legDuration = legDuration
  }
}
