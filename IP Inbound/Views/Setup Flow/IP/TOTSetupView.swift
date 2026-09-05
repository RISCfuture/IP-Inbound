import IP_Inbound_Shared
import MeasurementKit
import SwiftData
import SwiftUI

struct TOTSetupView: View {
  private static let timeAdvanceNew = Measurement(value: 30, unit: UnitDuration.minutes)
  private static let timeAdvancePast = Measurement(value: 5, unit: UnitDuration.minutes)
  private static let contentSpacing = 20.0

  /// How long the entry has to settle before the countdown is armed for it.
  ///
  /// The keypad writes the time on target on every keystroke, so a brief typed in full walks through
  /// half a dozen times the pilot never meant. Waiting out a pause spares the system that many
  /// cancel-and-reschedule rounds and arms the time they stopped at.
  private static let armingDelay = Measurement(value: 1.5, unit: UnitDuration.seconds)

  @Bindable var target: Target

  @Environment(\.services)
  private var services

  @Environment(\.scenePhase)
  private var scenePhase

  /// The time on target the countdown standing was armed for, so that the two things that can arm
  /// one — the entry settling, and the pilot leaving with it — cannot arm the same brief twice.
  @State private var armedTimeOnTarget: Date?

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
    // Arming here rather than on the way out is what makes the feature work for the pilot it is for:
    // a phone pocketed straight off this screen never fires `onDisappear`, and a target deleted
    // while it is showing would fire one against a model already gone.
    .task(id: target.timeOnTarget) { await armCountdownOnceSettled() }
    // The pilot leaving settles a brief as surely as a pause does, and is the one signal that
    // cannot wait for the delay: starting an activity is refused outside the foreground, so a brief
    // typed and pocketed inside the settling window would otherwise arm nothing at all.
    .onChange(of: scenePhase) {
      if scenePhase != .active { armCountdown() }
    }
  }

  private func armCountdownOnceSettled() async {
    guard (try? await Task.sleep(for: Self.armingDelay.duration)) != nil else { return }
    armCountdown()
  }

  private func armCountdown() {
    guard armedTimeOnTarget != target.timeOnTarget else { return }
    armedTimeOnTarget = target.timeOnTarget
    LiveActivityController.shared.arm(target, at: services.clock.now)
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
