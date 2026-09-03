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

  /// The moment the countdown is read against, which decides whether it is still running.
  ///
  /// A view drawn on demand reads against the present, which is the default. A widget's timeline
  /// entry is drawn well ahead of the moment it stands for, so the complication passes that entry's
  /// own date: read against the present, every entry would be archived while the time on target was
  /// still to come, and the past-TOT notice could never be reached.
  public var asOf: Date

  public var body: some View {
    if let timeOnTarget, timeOnTarget > asOf {
      Text.countingDown(to: timeOnTarget, from: asOf)
        .font(font)
        .contentTransition(.numericText())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    } else {
      Text.pastTOT
        .font(pastTOTFont ?? font)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
  }

  public init(timeOnTarget: Date?, font: Font, pastTOTFont: Font? = nil, asOf: Date = .now) {
    self.timeOnTarget = timeOnTarget
    self.font = font
    self.pastTOTFont = pastTOTFont
    self.asOf = asOf
  }
}

extension Text {
  /// What stands in for the countdown once the time on target has gone by.
  fileprivate static var pastTOT: Text {
    Text("Past TOT", bundle: .guidance)
  }

  /// The countdown to `timeOnTarget` read as a single run of text, saying `Past TOT` once the time
  /// has gone by.
  ///
  /// ``TOTCountdownText`` draws the same thing wherever there is room for a view of its own. The
  /// inline complication has only one line, into which the countdown is interpolated alongside the
  /// target's name — and only a `Text` can be interpolated into a `Text`.
  public static func totCountdown(to timeOnTarget: Date, asOf now: Date = .now) -> Text {
    timeOnTarget > now ? countingDown(to: timeOnTarget, from: now) : pastTOT
  }

  /// The ticking countdown, which the system runs down without the view being redrawn. The range has
  /// to ascend, so every caller settles whether the time on target is still ahead before asking.
  fileprivate static func countingDown(to timeOnTarget: Date, from now: Date) -> Text {
    Text(
      .currentDate,
      format: .timer(countingDownIn: now..<timeOnTarget, maxPrecision: .seconds(1))
    )
  }
}
