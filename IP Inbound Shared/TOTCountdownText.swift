public import Foundation
public import SwiftUI

/// A self-updating countdown to a time on target.
///
/// The Lock Screen, the Dynamic Island, the watch app and the watch complication all draw this one,
/// so no two of them can disagree about how long is left — or about what to say when the time has
/// gone by. They all read zero.
public struct TOTCountdownText: View {
  /// The briefed time on target.
  public var timeOnTarget: Date

  /// The font the countdown reads in.
  public var font: Font

  public var body: some View {
    Self.text(timeOnTarget: timeOnTarget)
      .font(font)
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.6)
  }

  public init(timeOnTarget: Date, font: Font) {
    self.timeOnTarget = timeOnTarget
    self.font = font
  }

  /// The same countdown as a `Text`, for the inline widget family, which interpolates it into a
  /// single run of text rather than composing it as a view.
  ///
  /// The range is clamped to stay ascending: once the time on target passes, an unclamped range
  /// would run backwards, which reads as counting up and traps outright when built from `now`.
  public static func text(timeOnTarget: Date) -> Text {
    Text(
      timerInterval: .now...max(timeOnTarget, .now.addingTimeInterval(1)),
      countsDown: true
    )
  }
}
