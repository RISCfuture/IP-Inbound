import ActivityKit
import Foundation
import IP_Inbound_Shared
import MeasurementKit
import Sentry

/// The Lock Screen and Dynamic Island home of the Time-On-Target countdown.
///
/// The countdown leads two lives. Armed at the end of the brief — ``arm(_:at:)`` — it is handed to
/// the system as a scheduled activity and reaches the Lock Screen on its own a quarter of an hour
/// ahead of the time on target, with the app closed and the phone in a pocket. Raised with the run —
/// ``update(flying:)`` — it is an ordinary activity carrying the run-in figures alongside the
/// countdown. Either way the countdown ticks itself down from a time on target handed over once, so
/// no background updates are needed to keep it running.
///
/// An armed countdown is an `Activity` like any other and sits in the same collection, so nothing
/// here reads that collection whole: every operation is scoped to the target the countdown was drawn
/// for. A run ending must not quietly cancel a countdown armed for the next one, and a fix pushed for
/// the run being flown must not overwrite one armed for a target the aircraft is nowhere near. Which
/// life a countdown is in settles neither question: it stops being armed the moment its start date
/// arrives, and arrive it does — mid-run, while the pilot is flying somewhere else.
@MainActor
final class LiveActivityController {
  /// How far ahead of the briefed time on target an armed countdown appears.
  ///
  /// Scheduling an activity obliges the app to alert the pilot when it starts and offers no way to
  /// silence that, so this is equally how long before the time on target their phone buzzes at them
  /// — mid-taxi or mid-transit, wherever the lead time happens to find them.
  private static let armingLeadTime = Measurement(value: 15, unit: UnitDuration.minutes)

  static let shared = LiveActivityController()

  /// The activity work already queued.
  ///
  /// ActivityKit's start and end are both asynchronous, and a run can end and begin again in the
  /// same moment — a launch that clears the wreckage of a force-quit and then reopens the Fly
  /// screen, or a pass flown straight on to the next target. Run in whatever order the scheduler
  /// chose, a start that overtook the end before it would find an activity still standing, update
  /// that one, and then watch the end take it away, leaving a live run with nothing to draw on. One
  /// chain makes them happen in the order they were asked for.
  private var work: Task<Void, Never>?

  /// The countdowns the pilot can see.
  private var liveActivities: [Activity<TOTActivityAttributes>] {
    Activity<TOTActivityAttributes>.activities.filter(Self.isLive)
  }

  private init() {}

  /// Where a countdown armed for `timeOnTarget` belongs at `now`, or `nil` when there is nothing to
  /// arm — no time on target briefed, or one that has already passed.
  static func armPlan(timeOnTarget: Date?, at now: Date) -> ArmPlan? {
    guard let timeOnTarget, timeOnTarget > now else { return nil }
    let start = timeOnTarget - armingLeadTime
    return start > now ? .scheduled(start) : .immediate
  }

  /// Whether the countdown is one the pilot can see, as against one still waiting for its start
  /// date. A stale countdown still counts: it is on the Lock Screen, and is the app's to update and
  /// to take down.
  ///
  /// Isolated to no actor, along with `isArmed(_:)`, because an `Activity` handed to a main-actor
  /// function joins the main actor's region and can no longer be sent to the ending and updating
  /// calls that follow.
  nonisolated private static func isLive(_ activity: Activity<TOTActivityAttributes>) -> Bool {
    activity.activityState != .pending
  }

  /// Whether the countdown is armed: scheduled for a start date that has not arrived.
  nonisolated private static func isArmed(_ activity: Activity<TOTActivityAttributes>) -> Bool {
    activity.activityState == .pending
  }

  /// Whether the countdown is the run's, on the evidence of the identifiers: it was drawn for
  /// `targetID`, or one side or the other names no target to be told apart by — a run recorded
  /// before this app named them, or a countdown encoded before it did. Neither names another target
  /// to belong to instead, and a countdown no run will claim is one nothing takes down.
  nonisolated private static func isDrawn(
    _ activity: Activity<TOTActivityAttributes>,
    for targetID: String?
  ) -> Bool {
    guard let targetID, let drawnFor = activity.attributes.targetID else { return true }
    return drawnFor == targetID
  }

  private static func attributes(for target: Target) -> TOTActivityAttributes {
    .init(
      targetID: target.id,
      targetName: target.name,
      ipToTargetDuration: target.offsetTimeMeasurement
    )
  }

  private static func content(
    timeOnTarget: Date,
    runIn: RunInSnapshot? = nil
  ) -> ActivityContent<TOTActivityAttributes.ContentState> {
    .init(
      state: .init(
        timeOnTarget: timeOnTarget,
        ipDeltaTime: runIn?.ipDeltaTime,
        distanceToIP: runIn?.distanceToIP
      ),
      staleDate: timeOnTarget
    )
  }

  private static func alertConfiguration(for target: Target) -> AlertConfiguration {
    let leadMinutes = Int(armingLeadTime.converted(to: .minutes).value)
    return .init(
      title: "Countdown to “\(target.name)”",
      body: "\(leadMinutes) minutes to time on target.",
      sound: .default
    )
  }

  /// Live Activities the pilot has switched off, a device that has none, and a start attempted from
  /// the background are not faults to chase: the countdown simply does not appear, for a reason
  /// already known. Anything else — notably the simultaneous-activity limit, which armed countdowns
  /// count against — is the app's own doing and worth knowing about.
  private static func report(_ error: any Error) {
    if let error = error as? ActivityAuthorizationError {
      switch error {
        case .denied, .unsupported, .visibility: return
        default: break
      }
    }
    SentrySDK.capture(error: error)
  }

  /// Starts — or updates, if one is already running — the Live Activity for the target the pilot is
  /// flying. No-ops when Live Activities are unavailable or disabled, or under previews and tests.
  ///
  /// The run is being flown now, so the countdown armed for it has been spent: left standing it
  /// would arrive behind the one the pilot is already reading and alert them mid-run. One armed for
  /// another target is announcing a run this one knows nothing of, and is left alone.
  func update(flying target: Target) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      ActivityAuthorizationInfo().areActivitiesEnabled,
      let timeOnTarget = target.timeOnTarget
    else { return }

    let targetID = target.id
    let attributes = Self.attributes(for: target)
    let content = Self.content(timeOnTarget: timeOnTarget)

    enqueue {
      await self.cancelArmed(for: targetID)
      await self.startOrUpdate(attributes: attributes, content: content)
    }
  }

  /// Takes down what the run put on the Lock Screen, and leaves standing whatever a brief armed for
  /// a target the run was not flying.
  ///
  /// - Parameter targetID: the target the ending run was flying, or `nil` for a run recorded before
  ///   the app named them — which leaves nothing to tell that run's countdown from any other, so
  ///   every countdown the pilot can see comes down with it.
  func endRun(flying targetID: String?) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      ActivityAuthorizationInfo().areActivitiesEnabled
    else { return }

    enqueue { await self.endRunCountdowns(flying: targetID) }
  }

  /// Pushes the live run-in figures onto a running activity, leaving the countdown alone.
  ///
  /// Fixes arrive at roughly 1 Hz, which is far more often than a Lock Screen readout can usefully
  /// change; callers pass values already quantized to the precision they display, so this is only
  /// reached when the pilot would actually see a difference.
  func update(runIn: RunInSnapshot?, for target: Target) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      let timeOnTarget = target.timeOnTarget
    else { return }

    let targetID = target.id
    let content = Self.content(timeOnTarget: timeOnTarget, runIn: runIn)
    enqueue { await self.updateRunCountdowns(content, flying: targetID) }
  }

  /// Arms the countdown for a target the pilot has just briefed, so it reaches the Lock Screen by
  /// itself `armingLeadTime` ahead of the time on target. A pilot who briefs a run and pockets the
  /// phone through taxi and transit gets the countdown without ever reopening the app.
  ///
  /// A scheduled activity cannot be rescheduled, so this asks for a new countdown and takes down
  /// whatever was standing; the armed target is whichever one was briefed last. It stands aside for
  /// a run already outstanding, whose countdown is on the Lock Screen already and carries the run-in
  /// figures this one could not.
  ///
  /// - Parameters:
  ///   - target: the target to arm the countdown for.
  ///   - now: the moment to plan the countdown from.
  func arm(_ target: Target, at now: Date) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests,
      ActivityAuthorizationInfo().areActivitiesEnabled,
      !BackgroundActivityHolder.shared.isRunOutstanding,
      let timeOnTarget = target.timeOnTarget,
      let plan = Self.armPlan(timeOnTarget: timeOnTarget, at: now)
    else { return }

    let attributes = Self.attributes(for: target)
    let content = Self.content(timeOnTarget: timeOnTarget)
    let alertConfiguration = Self.alertConfiguration(for: target)

    enqueue {
      await self.armOrAdopt(
        attributes: attributes,
        content: content,
        alertConfiguration: alertConfiguration,
        plan: plan
      )
    }
  }

  /// Cancels every countdown for one target, whichever life it is in: the target has been deleted,
  /// and nothing should still be counting down to a run that cannot be flown.
  ///
  /// Wider than the cancelling ``update(flying:)`` does, which spares a countdown that has already
  /// started so the run can adopt it. There is no run to adopt this one.
  func disarm(targetID: String) {
    enqueue { await self.end { $0.attributes.targetID == targetID } }
  }

  /// Takes down a countdown nobody flew.
  ///
  /// A run raised on the Fly screen is bounded at both ends by `RunController`, but a countdown that
  /// was armed and then never flown belongs to no run and has no such bound: it starts on its own,
  /// counts through zero and sits on the Lock Screen. A brief that came to nothing is cleared away
  /// here, on the same footing as the run wreckage `RunController.endUnclaimedRun()` clears.
  func sweepExpiredCountdowns(at now: Date) {
    guard !ProcessInfo.processInfo.isRunningPreviewsOrTests else { return }

    enqueue {
      await self.end { now >= $0.content.state.timeOnTarget + Target.postTOTGrace }
    }
  }

  private func enqueue(_ operation: @escaping @MainActor () async -> Void) {
    let previous = work
    work = Task { @MainActor in
      await previous?.value
      await operation()
    }
  }

  /// Brings the running activity into line with the target being flown, requesting one when none
  /// stands for it.
  ///
  /// Only the content state can be updated once an activity is running: the target's name and the
  /// extent of its progress ring are fixed when it is requested. So a countdown drawn for this
  /// target under a name or a run-in leg it has since been given anew cannot be made to stand for
  /// it — it would keep the old ones while counting down to the new time — and is ended and replaced
  /// instead. One drawn for another target is not this run's to replace: it is counting down to a
  /// run of its own, and stands. An armed countdown that has since started is adopted here like any
  /// other, since its attributes are the ones this run would have asked for.
  ///
  /// The collection is read here rather than at the call site because an end still waiting its turn
  /// in the queue has not taken its activity down yet, and a start that judged the collection before
  /// it ran would update the very activity the end is about to remove.
  private func startOrUpdate(
    attributes: TOTActivityAttributes,
    content: ActivityContent<TOTActivityAttributes.ContentState>
  ) async {
    let isDrawnForThisTarget = liveActivities.contains { $0.attributes == attributes }

    guard isDrawnForThisTarget else {
      await endRunCountdowns(flying: attributes.targetID)
      do {
        _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
      } catch {
        Self.report(error)
      }
      return
    }

    await updateRunCountdowns(content, flying: attributes.targetID)
  }

  /// Puts the briefed target's countdown up, or brings up to date the one already showing it.
  ///
  /// Briefing is not a one-shot: the pilot walks back to the Time on Target screen and the arming
  /// runs again. By then the countdown armed on the first visit may have reached its start date and
  /// be on the Lock Screen — and a countdown that has started is no longer armed, so cancelling only
  /// what is armed would leave it standing and ask for a second one beside it.
  ///
  /// Nothing here belongs to a run — ``arm(_:at:)`` stands aside for one — so a countdown drawn for
  /// some other target is one no brief still wants, and goes.
  private func armOrAdopt(
    attributes: TOTActivityAttributes,
    content: ActivityContent<TOTActivityAttributes.ContentState>,
    alertConfiguration: AlertConfiguration,
    plan: ArmPlan
  ) async {
    guard !liveActivities.contains(where: { $0.attributes == attributes }) else {
      await update(content) { Self.isLive($0) && $0.attributes == attributes }
      return
    }

    // Asked for before what it replaces comes down, rather than after. A request refused — the app
    // no longer frontmost, the simultaneous-activity limit reached — must not leave the pilot with
    // nothing where their countdown was.
    let armed = requestArmed(
      attributes: attributes,
      content: content,
      alertConfiguration: alertConfiguration,
      plan: plan
    )
    guard let armed else { return }

    await end { $0.id != armed }
  }

  /// Asks for the armed countdown and answers with its identity, so that everything the brief
  /// replaces can be told apart from what it just put up. `nil` when the request was refused.
  private func requestArmed(
    attributes: TOTActivityAttributes,
    content: ActivityContent<TOTActivityAttributes.ContentState>,
    alertConfiguration: AlertConfiguration,
    plan: ArmPlan
  ) -> String? {
    do {
      switch plan {
        case .immediate:
          return try Activity.request(attributes: attributes, content: content, pushType: nil).id
        case .scheduled(let start):
          return try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil,
            style: .standard,
            alertConfiguration: alertConfiguration,
            start: start
          ).id
      }
    } catch {
      Self.report(error)
      return nil
    }
  }

  /// Cancels what is still waiting to start for one target, leaving a countdown that has already
  /// started for ``startOrUpdate(attributes:content:)`` to adopt.
  private func cancelArmed(for targetID: String) async {
    await end { Self.isArmed($0) && $0.attributes.targetID == targetID }
  }

  /// Ends the countdowns the run flying `targetID` drew, or could have drawn: what the pilot can see
  /// for that target, and nothing a brief armed for another.
  private func endRunCountdowns(flying targetID: String?) async {
    await end { Self.isLive($0) && Self.isDrawn($0, for: targetID) }
  }

  /// Pushes the run's figures onto the countdown the run flying `targetID` is drawing on, leaving one
  /// armed for another target counting down to the run it was armed for.
  private func updateRunCountdowns(
    _ content: ActivityContent<TOTActivityAttributes.ContentState>,
    flying targetID: String?
  ) async {
    await update(content) { Self.isLive($0) && Self.isDrawn($0, for: targetID) }
  }

  /// Pushes `content` onto every countdown `isIncluded` accepts. Paired with `end(_:)`, and takes a
  /// rule rather than a collection for the same reason.
  private func update(
    _ content: ActivityContent<TOTActivityAttributes.ContentState>,
    where isIncluded: (Activity<TOTActivityAttributes>) -> Bool
  ) async {
    for activity in Activity<TOTActivityAttributes>.activities {
      guard isIncluded(activity) else { continue }
      await activity.update(content)
    }
  }

  /// Ends every countdown `isIncluded` accepts.
  ///
  /// Callers pass a rule rather than a collection because `Activity` is not `Sendable`: one drawn
  /// from the collection here is the loop's alone and can be sent to the ending call, while one
  /// handed in from outside is shared with whoever assembled it.
  private func end(_ isIncluded: (Activity<TOTActivityAttributes>) -> Bool) async {
    for activity in Activity<TOTActivityAttributes>.activities {
      guard isIncluded(activity) else { continue }
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  /// Where an armed countdown belongs: waiting for a start date, or on the Lock Screen already
  /// because the lead time has run out.
  enum ArmPlan: Equatable {
    /// The lead time has already elapsed, so the countdown goes up now — which also spares the pilot
    /// the alert a scheduled request would insist on, at a moment they are holding the phone.
    case immediate

    /// The countdown is handed to the system to raise by itself at this date.
    case scheduled(Date)
  }
}
