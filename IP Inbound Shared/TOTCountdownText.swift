import Foundation
import SwiftUI

/// A self-updating countdown to a time on target, reading `Past TOT` once the time has gone by.
///
/// The watch app and the watch complication both draw it, so a glance at the face and a glance at the
/// app cannot disagree about how long is left.
public struct TOTCountdownText: View {
  /// The briefed time on target, or `nil` when none is set.
  public var timeOnTarget: Date?

  /// The font the running countdown reads in.
  public var font: Font

  /// The font the past-TOT notice reads in, which the watch app sets smaller than its countdown.
  /// Defaults to ``font``.
  public var pastTOTFont: Font?

  private var isCountingDown: Bool { timeOnTarget.map { $0 > Date() } ?? false }

  public var body: some View {
    Self.text(timeOnTarget: timeOnTarget)
      .font(isCountingDown ? font : (pastTOTFont ?? font))
      .contentTransition(.numericText())
      .lineLimit(1)
      .minimumScaleFactor(0.6)
  }

  public init(timeOnTarget: Date?, font: Font, pastTOTFont: Font? = nil) {
    self.timeOnTarget = timeOnTarget
    self.font = font
    self.pastTOTFont = pastTOTFont
  }

  /// The same countdown as a `Text`, for the inline widget family, which interpolates it into a
  /// single run of text rather than composing it as a view.
  ///
  /// The past-TOT branch is what keeps the countdown's range from running backwards: built once the
  /// time has gone by, `now..<timeOnTarget` is a range whose lower bound exceeds its upper, which
  /// traps rather than reading zero.
  public static func text(timeOnTarget: Date?) -> Text {
    guard let timeOnTarget, timeOnTarget > Date() else {
      return Text("Past TOT", bundle: .guidance)
    }
    return Text(
      .currentDate,
      format: .timer(countingDownIn: Date.now..<timeOnTarget, maxPrecision: .seconds(1))
    )
  }
}
