import IP_Inbound_Shared
import MeasurementKit
import SwiftData
import SwiftUI

struct PostPassView: View {
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

  private var nextTarget: Target? {
    NextTarget.next(after: currentTarget, in: targets, now: services.clock.now)
  }

  /// What the screen is reporting. A run that lapsed short of the target has nothing to be past
  /// but the time it was briefed for — and that is the same thing ``CountdownView`` says of a
  /// time-on-target gone by, so it says it the same way.
  private var title: LocalizedStringKey {
    capture.crossedTarget ? "Past Target" : "Past TOT"
  }

  var body: some View {
    VStack(spacing: Self.sectionSpacing) {
      Spacer()

      VStack(spacing: Self.titleSpacing) {
        Text(title)
          .font(.title)
          .fontWeight(.bold)
        Text(capture.targetName)
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      // A run that lapsed with the target still ahead of it flew no pass, so there is no verdict to
      // give. The headline above has already said what happened; a figure here would only be the
      // grace period wearing a pass's clothes.
      if let miss = capture.miss {
        PostPassMissView(miss: miss)
      }

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

/// The verdict on a pass that was flown: how far the crossing fell from the briefed time on target,
/// and how good that is.
private struct PostPassMissView: View {
  /// On-time and caution tolerances for the post-pass verdict. The on-time window is the same one
  /// ``GuidanceContentView`` feeds to ``TimingView``; the caution tolerance widens it by
  /// `cautionMultiplier`. Keeping them aligned makes the post-pass verdict consistent with the
  /// timing the pilot was just flying to, rather than flipping a green pass to red after crossing.
  private static let cautionMultiplier = 5.0
  private static let onTimeTolerance = TimingTier.runInOnTimeDeltaTOT
  private static let cautionTolerance = onTimeTolerance * cautionMultiplier

  /// How far the crossing fell from the planned time-on-target: positive late, negative early.
  let miss: Measurement<UnitDuration>

  @ScaledMetric(relativeTo: .largeTitle)
  private var missFontSize = 36.0

  private var isEarly: Bool { miss < .zero }

  private var absoluteMiss: Measurement<UnitDuration> { miss.magnitude }
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
  }
}

/// A pass outcome as the canvas labels it, with the miss that produces it.
private enum PostPassPreview: CaseIterable, CustomStringConvertible {
  case onTime, lateCaution, lateWarning, earlyCaution, earlyWarning, lapsed

  var description: String {
    switch self {
      case .onTime: "On Time"
      case .lateCaution: "Late — Caution"
      case .lateWarning: "Late — Warning"
      case .earlyCaution: "Early — Caution"
      case .earlyWarning: "Early — Warning"
      case .lapsed: "Lapsed — Never Crossed"
    }
  }

  var miss: Measurement<UnitDuration>? {
    let seconds: Double? =
      switch self {
        case .onTime: 1
        case .lateCaution: 60
        case .lateWarning: 200
        case .earlyCaution: -60
        case .earlyWarning: -200
        case .lapsed: nil
      }
    return seconds.map { Measurement(value: $0, unit: .seconds) }
  }
}

#Preview(arguments: PostPassPreview.allCases) { preview in
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, miss: preview.miss),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}
