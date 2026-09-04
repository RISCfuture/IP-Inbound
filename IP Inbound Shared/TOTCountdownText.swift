public import Foundation
public import SwiftUI

/// A self-updating countdown to a time on target.
///
/// The Lock Screen, the Dynamic Island, the watch app and the watch complication all draw this one,
/// so no two of them can disagree about how long is left — or about what to say when the time has
/// gone by. They all read zero.
///
/// The Fly screen is not among them. Its countdown runs against the simulated clock rather than the
/// wall clock, which nothing drawn outside the app can do, and it still reads `Past TOT`.
public struct TOTCountdownText: View {
  /// The briefed time on target.
  public var timeOnTarget: Date

  /// The font the countdown reads in, or `nil` to read in whatever font it is drawn into — which is
  /// what the Dynamic Island's compact regions want, having already sized their own text.
  public var font: Font?

  public var body: some View {
    countdown
      .monospacedDigit()
      .lineLimit(1)
      .minimumScaleFactor(0.6)
  }

  /// `font(nil)` clears an inherited font rather than deferring to it, so leaving the font unset has
  /// to mean not applying the modifier at all.
  @ViewBuilder private var countdown: some View {
    if let font {
      Self.text(timeOnTarget: timeOnTarget).font(font)
    } else {
      Self.text(timeOnTarget: timeOnTarget)
    }
  }

  public init(timeOnTarget: Date, font: Font? = nil) {
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
