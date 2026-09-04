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
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

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

    result.capture(targetName: "First", timeOnTarget: tot, now: tot.addingTimeInterval(5))
    result.capture(targetName: "Second", timeOnTarget: tot, now: tot.addingTimeInterval(99))

    let firstCapture = try #require(result.capture)
    #expect(firstCapture.targetName == "First")
    #expect(firstCapture.miss == Measurement(value: 5, unit: .seconds))

    result.reset()
    #expect(result.capture == nil)

    result.capture(targetName: "Third", timeOnTarget: tot, now: tot.addingTimeInterval(-3))
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
    result.capture(targetName: "T", timeOnTarget: tot, now: tot)

    #expect(result.capture?.miss == Measurement(value: -20, unit: .seconds))
  }

  @Test
  func `PostPassResult.capture falls back to now when no crossing was recorded`() {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    result.capture(targetName: "T", timeOnTarget: tot, now: tot.addingTimeInterval(8))

    #expect(result.capture?.miss == Measurement(value: 8, unit: .seconds))
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

  private func makeLocation(at coordinate: Coordinate) -> CLLocation {
    let speedMS = Measurement(value: 500, unit: UnitSpeed.knots)
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
