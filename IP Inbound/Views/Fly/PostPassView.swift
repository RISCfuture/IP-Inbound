import SwiftData
import SwiftUI

struct PostPassView: View {
  /// On-time and caution tolerances for the post-pass verdict. The 30-second on-time window matches
  /// the run-in window ``GuidanceContentView`` feeds to ``TimingView`` (`runInOnTimeDeltaTOT`); the
  /// caution tolerance applies ``TimingView``’s `cautionMultiplier` (5×) to that window. Keeping them
  /// aligned makes the post-pass verdict consistent with the timing the pilot was just flying to,
  /// rather than flipping a green pass to red after crossing.
  private static let
    onTimeToleranceSeconds = 30.0,
    cautionToleranceSeconds = 150.0

  private static let
    sectionSpacing = 24.0,
    titleSpacing = 8.0,
    buttonStackSpacing = 12.0
  private static let missFontSize = 36.0

  let capture: PostPassResult.Capture
  let currentTarget: Target
  var onSelectTarget: (Target) -> Void
  var onChooseTarget: () -> Void

  @Environment(\.services)
  private var services

  @Query(sort: \Target.timeOnTarget)
  private var targets: [Target]

  private var nextTarget: Target? {
    NextTarget.next(after: currentTarget, in: targets, now: services.clock.now)
  }

  private var missDuration: Duration {
    .seconds(abs(capture.missSeconds))
  }

  private var isEarly: Bool { capture.missSeconds < 0 }

  private var absoluteMissSeconds: Double { abs(capture.missSeconds) }
  private var isOnTime: Bool { absoluteMissSeconds <= Self.onTimeToleranceSeconds }
  private var isWithinCaution: Bool { absoluteMissSeconds <= Self.cautionToleranceSeconds }

  /// Mirrors TimingView's color tiers: green when within tolerance, the
  /// "too fast" palette when early, the "too slow" palette when late, in
  /// caution / warning shades by magnitude.
  private var missColor: Color {
    if isOnTime { return Color("OnTime") }
    if isEarly {
      return isWithinCaution ? Color("TooFastCaution") : Color("TooFastWarning")
    }
    return isWithinCaution ? Color("TooSlowCaution") : Color("TooSlowWarning")
  }

  /// Mirrors TimingView's chevron direction: down for early, up for late,
  /// doubled at the warning threshold, checkmark on-time.
  private var missIcon: String {
    if isOnTime { return "checkmark.circle.fill" }
    if isEarly {
      return isWithinCaution ? "chevron.down" : "chevron.down.2"
    }
    return isWithinCaution ? "chevron.up" : "chevron.up.2"
  }

  private var missText: String {
    let amount = missDuration.formatted(
      .units(allowed: [.minutes, .seconds], width: .wide)
    )
    return isEarly
      ? String(localized: "\(amount) early")
      : String(localized: "\(amount) late")
  }

  var body: some View {
    VStack(spacing: Self.sectionSpacing) {
      Spacer()

      VStack(spacing: Self.titleSpacing) {
        Text("Past Target")
          .font(.title)
          .fontWeight(.bold)
        Text(capture.targetName)
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      Label {
        Text(missText)
          .contentTransition(.numericText())
      } icon: {
        Image(systemName: missIcon)
          .accessibilityHidden(true)
      }
      .font(.system(size: Self.missFontSize, weight: .black))
      .foregroundStyle(missColor)
      .accessibilityIdentifier("postPassMiss")

      Spacer()

      VStack(spacing: Self.buttonStackSpacing) {
        if let nextTarget {
          Button {
            onSelectTarget(nextTarget)
          } label: {
            Text("Fly \(nextTarget.name)")
              .padding(.horizontal)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .accessibilityIdentifier("flyNextTargetButton")
        }

        Button {
          onChooseTarget()
        } label: {
          Text("Choose next target")
            .padding(.horizontal)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityIdentifier("chooseTargetButton")
      }
    }
    .padding()
    .accessibilityIdentifier("postPassView")
  }
}

#Preview("On Time") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: 1),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}

#Preview("Late — Caution") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: 60),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}

#Preview("Late — Warning") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: 200),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}

#Preview("Early — Caution") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: -60),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}

#Preview("Early — Warning") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: -200),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}
