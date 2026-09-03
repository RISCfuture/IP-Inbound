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

  private var ringRange: ClosedRange<Date> {
    let extent = max(legDuration, Self.minimumLegDuration)
    return (timeOnTarget - extent)...timeOnTarget
  }

  public var body: some View {
    ProgressView(timerInterval: ringRange, countsDown: true) {
      EmptyView()
    } currentValueLabel: {
      EmptyView()
    }
    .progressViewStyle(.circular)
    .accessibilityLabel("Time on target countdown")
  }

  public init(timeOnTarget: Date, legDuration: Measurement<UnitDuration>) {
    self.timeOnTarget = timeOnTarget
    self.legDuration = legDuration
  }
}
