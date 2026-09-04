import CoreLocation
import Foundation
import MeasurementKit
import MeasurementKitLocation
import Testing

@testable import IP_Inbound
@testable import IP_Inbound_Shared

@Suite
struct `Post-Pass tests` {
  private let targetCoordinate = Coordinate(latitude: 36.772367, longitude: -115.453840)
  private let postIP = Coordinate(latitude: 36.8078222222, longitude: -115.4840472222)
  private let beyondTarget = Coordinate(latitude: 36.700000, longitude: -115.453840)
  /// Well up the run-in axis from the IP, which sits 4.8 NM off a 359° offset at about 36.852.
  private let shortOfIP = Coordinate(latitude: 37.100000, longitude: -115.453840)
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  /// A time on target far enough back that the run has expired, by a minute.
  private var expiredTimeOnTarget: Date {
    now - (Target.postTOTGrace + Measurement(value: 1, unit: UnitDuration.minutes))
  }

  // MARK: - isPastTarget (geometric)

  @Test
  func `isPastTarget, beyond the target, returns true`() {
    let target = makeTarget()

    let math = IPTargetMath(
      coordinate: beyondTarget,
      speed: Measurement(value: 500, unit: .knots),
      course: TrueBearing(degrees: 180),
      target: target,
      now: now
    )

    #expect(math.isPastTarget)
  }

  @Test
  func `isPastTarget, before the target, returns false`() {
    let target = makeTarget()

    // postIP is between the IP and the target along the run-in axis, so the
    // aircraft has passed the IP but not yet reached the target.
    let math = IPTargetMath(
      coordinate: postIP,
      speed: Measurement(value: 500, unit: .knots),
      course: TrueBearing(degrees: 180),
      target: target,
      now: now
    )

    #expect(!math.isPastTarget)
  }

  // MARK: - isAfterTOT (clock)

  @Test
  func `isAfterTOT, now is past TOT, returns true`() {
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(-1))
    let math = makePastTargetMath(for: target, at: now)
    #expect(math.isAfterTOT)
  }

  @Test
  func `isAfterTOT, now exactly equals TOT, returns true`() {
    let target = makeTarget(timeOnTarget: now)
    let math = makePastTargetMath(for: target, at: now)
    #expect(math.isAfterTOT)
  }

  @Test
  func `isAfterTOT, now is before TOT, returns false`() {
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(30))
    let math = makePastTargetMath(for: target, at: now)
    #expect(!math.isAfterTOT)
  }

  @Test
  func `isAfterTOT, TOT is unset, returns false`() {
    let target = makeTarget(timeOnTarget: nil)
    let math = makePastTargetMath(for: target, at: now)
    #expect(!math.isAfterTOT)
  }

  // MARK: - .postPass gating (composition)

  @Test
  func `guidance is .postPass only when past target AND past TOT`() throws {
    // Aircraft is moving fast enough to satisfy the movement threshold, on
    // the run-in course, at a position beyond the target along that axis.
    let location = makePastTargetLocation()
    let beforeTOT = makeTarget(timeOnTarget: now.addingTimeInterval(60))
    let afterTOT = makeTarget(timeOnTarget: now.addingTimeInterval(-1))

    let stillInbound = try #require(
      GuidanceHelper(location: location, target: beforeTOT, now: now)
    ).guidance
    let postPass = try #require(
      GuidanceHelper(location: location, target: afterTOT, now: now)
    ).guidance

    #expect(stillInbound != .postPass)
    #expect(postPass == .postPass)
  }

  @Test
  func `guidance is not .postPass when past TOT but before target`() throws {
    let location = makeLocation(at: postIP)  // between IP and target
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(-30))

    let guidance = try #require(
      GuidanceHelper(location: location, target: target, now: now)
    ).guidance

    #expect(guidance != .postPass)
  }

  @Test
  func `guidance stands down short of the IP only once the run has expired`() throws {
    let location = makeLocation(at: shortOfIP)
    let withinGrace = makeTarget(timeOnTarget: now.addingTimeInterval(-60))
    let expired = makeTarget(timeOnTarget: expiredTimeOnTarget)

    let stillFlying = try #require(
      GuidanceHelper(location: location, target: withinGrace, now: now)
    ).guidance
    let stoodDown = try #require(
      GuidanceHelper(location: location, target: expired, now: now)
    ).guidance

    // A minute late is a run the pilot may still be pressing; a quarter of an hour is not.
    #expect(stillFlying != .postPass)
    #expect(stoodDown == .postPass)
  }

  @Test
  func `guidance stands a lapsed run down with the aircraft below the movement threshold`() throws {
    // A fix below the threshold - on the ground, in a hold, or reporting no speed at all - is what
    // the countdown is for, right up until there is no longer a run to count down to.
    let location = makeLocation(at: shortOfIP, speedKnots: 0)
    let withinGrace = makeTarget(timeOnTarget: now.addingTimeInterval(-60))
    let expired = makeTarget(timeOnTarget: expiredTimeOnTarget)

    let stillCountingDown = try #require(
      GuidanceHelper(location: location, target: withinGrace, now: now)
    ).guidance
    let stoodDown = try #require(
      GuidanceHelper(location: location, target: expired, now: now)
    ).guidance

    #expect(stillCountingDown == .countdownOnly)
    #expect(stoodDown == .postPass)
  }

  @Test
  func `guidance keeps the run-in past the IP however late the run has run`() throws {
    // The pilot is still flying this one, so the expiry that stands the guidance down short of the
    // IP must not reach it.
    let location = makeLocation(at: postIP)
    let target = makeTarget(timeOnTarget: expiredTimeOnTarget)

    let guidance = try #require(
      GuidanceHelper(location: location, target: target, now: now)
    ).guidance

    #expect(guidance == .toTarget)
  }

  // MARK: - NextTarget pick

  @Test
  func `NextTarget.next, picks the soonest future TOT and excludes the current target`() throws {
    let now = Date(timeIntervalSince1970: 1_000_000)

    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now.addingTimeInterval(-60)

    let soon = Target(name: "Soon", coordinate: targetCoordinate)
    soon.timeOnTarget = now.addingTimeInterval(120)

    let later = Target(name: "Later", coordinate: targetCoordinate)
    later.timeOnTarget = now.addingTimeInterval(600)

    let past = Target(name: "Past", coordinate: targetCoordinate)
    past.timeOnTarget = now.addingTimeInterval(-300)

    let chosen = try #require(
      NextTarget.next(after: current, in: [later, current, past, soon], now: now)
    )

    #expect(chosen.id == soon.id)
  }

  @Test
  func `NextTarget.next, returns nil when no future targets qualify`() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now

    let past = Target(name: "Past", coordinate: targetCoordinate)
    past.timeOnTarget = now.addingTimeInterval(-120)

    let noTOT = Target(name: "NoTOT", coordinate: targetCoordinate)

    #expect(NextTarget.next(after: current, in: [current, past, noTOT], now: now) == nil)
  }

  @Test
  func `NextTarget.next, returns the next target by TOT even when behind schedule`() throws {
    let now = Date(timeIntervalSince1970: 1_000_000)

    // The whole run is late: both the just-flown target and the next one have TOTs in the past.
    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now.addingTimeInterval(-600)

    let next = Target(name: "Next", coordinate: targetCoordinate)
    next.timeOnTarget = now.addingTimeInterval(-120)

    let chosen = try #require(NextTarget.next(after: current, in: [current, next], now: now))
    #expect(chosen.id == next.id)
  }

  @Test
  func `PostPassResult.capture is idempotent until reset`() throws {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    result.recordCrossing(at: tot.addingTimeInterval(5))
    result.capture(targetName: "First", timeOnTarget: tot)
    result.capture(targetName: "Second", timeOnTarget: tot)

    let firstCapture = try #require(result.capture)
    #expect(firstCapture.targetName == "First")
    #expect(firstCapture.miss == Measurement(value: 5, unit: .seconds))

    result.reset()
    #expect(result.capture == nil)

    result.recordCrossing(at: tot.addingTimeInterval(-3))
    result.capture(targetName: "Third", timeOnTarget: tot)
    let thirdCapture = try #require(result.capture)
    #expect(thirdCapture.targetName == "Third")
    #expect(thirdCapture.miss == Measurement(value: -3, unit: .seconds))
  }

  @Test
  func `PostPassResult.capture times an early crossing from the crossing, not from TOT`() {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    // The aircraft crossed the target 20 s before TOT; the post-pass state is only entered once the
    // clock reaches TOT, so the miss must come from the recorded crossing — a 20 s-early pass.
    result.recordCrossing(at: tot.addingTimeInterval(-20))
    result.capture(targetName: "T", timeOnTarget: tot)

    #expect(result.capture?.miss == Measurement(value: -20, unit: .seconds))
    #expect(result.capture?.crossedTarget == true)
  }

  @Test
  func `PostPassResult.capture reports no miss when the target was never crossed`() throws {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    result.capture(targetName: "T", timeOnTarget: tot)

    // The run lapsed with the target still ahead of it. Timing that against the moment the guidance
    // stood down would report the grace period as a pass the aircraft never flew, so there is no
    // miss to report at all.
    let capture = try #require(result.capture)
    #expect(capture.miss == nil)
    #expect(!capture.crossedTarget)
  }

  // MARK: - Helpers

  private func makeTarget(timeOnTarget: Date? = nil) -> Target {
    let target = Target(name: "Test Target", coordinate: targetCoordinate)
    target.offsetBearing = 359
    target.offsetBearingIsTrue = true
    target.offsetDistance = 4.8
    target.targetGroundSpeed = 120
    target.timeOnTarget = timeOnTarget
    return target
  }

  private func makePastTargetMath(for target: Target, at now: Date) -> IPTargetMath<Target> {
    IPTargetMath(
      coordinate: beyondTarget,
      speed: Measurement(value: 500, unit: .knots),
      course: TrueBearing(degrees: 180),
      target: target,
      now: now
    )
  }

  private func makePastTargetLocation() -> CLLocation {
    makeLocation(at: beyondTarget)
  }

  private func makeLocation(at coordinate: Coordinate, speedKnots: Double = 500) -> CLLocation {
    let speedMS = Measurement(value: speedKnots, unit: UnitSpeed.knots)
      .converted(to: .metersPerSecond).value
    return CLLocation(
      coordinate: coordinate.clCoordinate,
      altitude: 0,
      horizontalAccuracy: 1,
      verticalAccuracy: 1,
      course: 180,
      courseAccuracy: 1,
      speed: speedMS,
      speedAccuracy: 1,
      timestamp: now
    )
  }
}
