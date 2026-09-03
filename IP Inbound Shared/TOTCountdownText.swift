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

  public var body: some View {
    if let timeOnTarget, timeOnTarget > Date() {
      Text(
        .currentDate,
        format: .timer(countingDownIn: Date.now..<timeOnTarget, maxPrecision: .seconds(1))
      )
      .font(font)
      .contentTransition(.numericText())
    } else {
      Text("Past TOT")
        .font(pastTOTFont ?? font)
    }
  }

  public init(timeOnTarget: Date?, font: Font, pastTOTFont: Font? = nil) {
    self.timeOnTarget = timeOnTarget
    self.font = font
    self.pastTOTFont = pastTOTFont
  }
}
