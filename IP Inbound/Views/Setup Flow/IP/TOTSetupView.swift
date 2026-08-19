import MeasurementKit
import SwiftUI

struct TOTSetupView: View {
  private static let timeAdvanceNew = Measurement(value: 30, unit: UnitDuration.minutes)
  private static let timeAdvancePast = Measurement(value: 5, unit: UnitDuration.minutes)
  private static let contentSpacing = 20.0

  @Bindable var target: Target

  @Environment(\.services)
  private var services

  /// UI-test affordance: when the harness pins a past `UITEST_NOW` to exercise post-pass behavior,
  /// the auto-bump in ``seedTimeOnTargetIfNeeded()`` would silently overwrite the seeded TOT. This
  /// bypass is gated on both `isRunningUITests` and an explicit launch-env opt-in, so it is inert in
  /// production and only available to the harness.
  private var shouldBypassTimeOnTargetReset: Bool {
    ProcessInfo.processInfo.isRunningUITests
      && ProcessInfo.processInfo.environment["UITEST_BYPASS_TOT_RESET"] == "1"
  }

  var body: some View {
    VStack(spacing: Self.contentSpacing) {
      TOTEntryView(
        timeOnTarget: target.timeOnTarget,
        targetCoordinate: target.coordinate,
        dateProvider: services.clock.dateProvider,
        onAccept: { newTime in
          target.timeOnTarget = newTime
        }
      )

      Spacer()

      HStack {
        NavigationLink(value: SetupFlowStep.IPSetup) {
          Label("Define IP", systemImage: "chevron.backward")
            .labelStyle(.titleAndIcon)
        }.accessibilityIdentifier("defineIPButton")
        Spacer()
        NavigationLink(value: SetupFlowStep.fly) {
          HStack {
            Text("Fly!")
            Image(systemName: "chevron.forward")
              .accessibilityHidden(true)
          }
        }.accessibilityIdentifier("flyButton")
      }.padding(.horizontal)
    }
    .onAppear(perform: seedTimeOnTargetIfNeeded)
  }

  private func seedTimeOnTargetIfNeeded() {
    guard !shouldBypassTimeOnTargetReset else { return }

    if target.timeOnTarget == nil {
      target.timeOnTarget = defaultTimeOnTarget(advance: Self.timeAdvanceNew)
    } else if let currentTime = target.timeOnTarget, currentTime < services.clock.now {
      target.timeOnTarget = defaultTimeOnTarget(advance: Self.timeAdvancePast)
    }
  }

  private func defaultTimeOnTarget(advance: Measurement<UnitDuration>) -> Date {
    normalizedToMinute(services.clock.now + advance)
  }

  private func normalizedToMinute(_ date: Date) -> Date {
    var components = Calendar.current.dateComponents(
      [.year, .month, .day, .hour, .minute],
      from: date
    )
    components.second = 0
    return Calendar.current.date(from: components) ?? date
  }
}

#Preview {
  let helper = PreviewHelper()
  TOTSetupView(target: helper.target())
    .modelContainer(helper.modelContainer)
}
