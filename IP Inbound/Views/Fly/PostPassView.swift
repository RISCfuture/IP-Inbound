import IP_Inbound_Shared
import MeasurementKit
import SwiftData
import SwiftUI

struct PostPassView: View {
  /// On-time and caution tolerances for the post-pass verdict. The on-time window is the same one
  /// ``GuidanceContentView`` feeds to ``TimingView``; the caution tolerance widens it by
  /// ``cautionMultiplier``. Keeping them aligned makes the post-pass verdict consistent with the
  /// timing the pilot was just flying to, rather than flipping a green pass to red after crossing.
  private static let cautionMultiplier = 5.0
  private static let onTimeTolerance = TimingTier.runInOnTimeDeltaTOT
  private static let cautionTolerance = onTimeTolerance * cautionMultiplier

  private static let
    sectionSpacing = 24.0,
    titleSpacing = 8.0,
    buttonStackSpacing = 12.0

  let capture: PostPassResult.Capture
  let currentTarget: Target
  var onSelectTarget: (Target) -> Void
  var onChooseTarget: () -> Void

  @Environment(\.services)
  private var services

  @Query(sort: \Target.timeOnTarget)
  private var targets: [Target]

  @ScaledMetric(relativeTo: .largeTitle)
  private var missFontSize = 36.0

  private var nextTarget: Target? {
    NextTarget.next(after: currentTarget, in: targets, now: services.clock.now)
  }

  private var isEarly: Bool { capture.miss < .zero }

  private var absoluteMiss: Measurement<UnitDuration> { capture.miss.magnitude }
  private var isOnTime: Bool { absoluteMiss <= Self.onTimeTolerance }
  private var isWithinCaution: Bool { absoluteMiss <= Self.cautionTolerance }

  private var tier: TimingTier {
    .init(isLate: !isEarly, isOnTime: isOnTime, isWithinCaution: isWithinCaution)
  }

  private var missText: String {
    let amount = absoluteMiss.duration.formatted(
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
        Image(systemName: tier.systemImage)
          .accessibilityHidden(true)
      }
      .font(.system(size: missFontSize, weight: .black))
      .foregroundStyle(tier.color)
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
    capture: .init(targetName: target.name, miss: .init(value: 1, unit: .seconds)),
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
    capture: .init(targetName: target.name, miss: .init(value: 60, unit: .seconds)),
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
    capture: .init(targetName: target.name, miss: .init(value: 200, unit: .seconds)),
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
    capture: .init(targetName: target.name, miss: .init(value: -60, unit: .seconds)),
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
    capture: .init(targetName: target.name, miss: .init(value: -200, unit: .seconds)),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}
