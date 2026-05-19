import SwiftData
import SwiftUI

struct PostPassView: View {
  let capture: PostPassResult.Capture
  let currentTarget: Target
  var onSelectTarget: (Target) -> Void
  var onChooseTarget: () -> Void

  @Query(sort: \Target.timeOnTarget)
  private var targets: [Target]

  private var nextTarget: Target? {
    NextTarget.next(after: currentTarget, in: targets, now: .now)
  }

  private var missDuration: Duration {
    .seconds(abs(capture.missSeconds))
  }

  private var isEarly: Bool { capture.missSeconds < 0 }

  private var missText: String {
    let amount = missDuration.formatted(
      .units(allowed: [.minutes, .seconds], width: .wide)
    )
    return isEarly
      ? String(localized: "\(amount) early")
      : String(localized: "\(amount) late")
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      VStack(spacing: 8) {
        Text("Pass Complete")
          .font(.title)
          .fontWeight(.bold)
        Text(capture.targetName)
          .font(.headline)
          .foregroundStyle(.secondary)
      }

      Text(missText)
        .font(.system(size: 44, weight: .black))
        .contentTransition(.numericText())
        .accessibilityIdentifier("postPassMiss")

      Spacer()

      VStack(spacing: 12) {
        if let nextTarget {
          Button {
            onSelectTarget(nextTarget)
          } label: {
            Text("Fly next target")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .accessibilityIdentifier("flyNextTargetButton")
        }

        Button {
          onChooseTarget()
        } label: {
          Text("Choose target")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier("chooseTargetButton")
      }
    }
    .padding()
    .accessibilityIdentifier("postPassView")
  }
}

#Preview("Late") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: 12),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}

#Preview("Early") {
  let helper = PreviewHelper()
  let target = helper.target()
  PostPassView(
    capture: .init(targetName: target.name, missSeconds: -8),
    currentTarget: target,
    onSelectTarget: { _ in },
    onChooseTarget: {}
  )
  .modelContainer(helper.modelContainer)
}
