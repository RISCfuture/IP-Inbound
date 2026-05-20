import SwiftUI

struct TOTSetupView: View {
  @Bindable var target: Target

  @Environment(\.services)
  private var services

  private let timeAdvanceNew = 30.0  // minutes after now, for new targets without TOTs
  private let timeAdvanceEdit = 5.0  // minutes after now, for TOTs in the past

  var body: some View {
    VStack(spacing: 20) {
      TOTEntryView(
        timeOnTarget: target.timeOnTarget,
        targetCoordinate: target.coordinate,
        dateProvider: services.clock.dateProvider,
        onAccept: { newTime in
          target.timeOnTarget = newTime
        },
        onCancel: {
          // In this context, cancel doesn't do anything since we're always showing the entry
        }
      )

      Spacer()

      HStack {
        NavigationLink(value: SetupFlowStep.IPSetup) {
          HStack {
            Image(systemName: "chevron.backward")
              .accessibilityHidden(true)
            Text("Define IP")
          }
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
    .onAppear {
      // UI-test affordance: when the harness pins a past `UITEST_NOW` to
      // exercise post-pass behavior, the auto-bump below would silently
      // overwrite the seeded TOT. The bypass is gated on both
      // `isRunningUITests` and an explicit launch-env opt-in, so it is inert
      // in production and only available to the harness.
      if ProcessInfo.processInfo.isRunningUITests,
        ProcessInfo.processInfo.environment["UITEST_BYPASS_TOT_RESET"] == "1"
      {
        return
      }
      // Set default time if not already set
      if target.timeOnTarget == nil {
        let defaultTime = services.clock.now.addingTimeInterval(60 * timeAdvanceNew)
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: defaultTime
        )
        components.second = 0
        target.timeOnTarget = Calendar.current.date(from: components) ?? defaultTime
      } else if let targetTime = target.timeOnTarget, targetTime < services.clock.now {
        // If the saved time is in the past, update it
        let updatedTime = services.clock.now.addingTimeInterval(60 * timeAdvanceEdit)
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute],
          from: updatedTime
        )
        components.second = 0
        target.timeOnTarget = Calendar.current.date(from: components) ?? updatedTime
      }
    }
  }
}

#Preview {
  let helper = PreviewHelper()
  TOTSetupView(target: helper.target())
}
