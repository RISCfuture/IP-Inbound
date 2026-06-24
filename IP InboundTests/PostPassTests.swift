import CoreLocation
import Foundation
import Testing

@testable import IP_Inbound

@Suite("Post-Pass Tests")
struct PostPassTests {
  private let targetCoordinate = Coordinate(latitude: 36.772367, longitude: -115.453840)
  private let postIP = Coordinate(latitude: 36.8078222222, longitude: -115.4840472222)
  private let beyondTarget = Coordinate(latitude: 36.700000, longitude: -115.453840)
  private let now = Date(timeIntervalSince1970: 1_700_000_000)

  // MARK: - isPastTarget (geometric)

  @Test("isPastTarget, beyond the target, returns true")
  func isPastTargetWhenBeyond() {
    let target = makeTarget()

    let math = IPTargetMath(
      coordinate: beyondTarget,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target,
      now: now
    )

    #expect(math.isPastTarget)
  }

  @Test("isPastTarget, before the target, returns false")
  func isPastTargetWhenBeforeTarget() {
    let target = makeTarget()

    // postIP is between the IP and the target along the run-in axis, so the
    // aircraft has passed the IP but not yet reached the target.
    let math = IPTargetMath(
      coordinate: postIP,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target,
      now: now
    )

    #expect(!math.isPastTarget)
  }

  // MARK: - isAfterTOT (clock)

  @Test("isAfterTOT, now is past TOT, returns true")
  func isAfterTOTPast() {
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(-1))
    let math = makePastTargetMath(for: target, at: now)
    #expect(math.isAfterTOT)
  }

  @Test("isAfterTOT, now exactly equals TOT, returns true")
  func isAfterTOTBoundary() {
    let target = makeTarget(timeOnTarget: now)
    let math = makePastTargetMath(for: target, at: now)
    #expect(math.isAfterTOT)
  }

  @Test("isAfterTOT, now is before TOT, returns false")
  func isAfterTOTBefore() {
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(30))
    let math = makePastTargetMath(for: target, at: now)
    #expect(!math.isAfterTOT)
  }

  @Test("isAfterTOT, TOT is unset, returns false")
  func isAfterTOTNoTOT() {
    let target = makeTarget(timeOnTarget: nil)
    let math = makePastTargetMath(for: target, at: now)
    #expect(!math.isAfterTOT)
  }

  // MARK: - .postPass gating (composition)

  @Test("guidance is .postPass only when past target AND past TOT")
  func gatingRequiresBothConditions() {
    // Aircraft is moving fast enough to satisfy the movement threshold, on
    // the run-in course, at a position beyond the target along that axis.
    let location = makePastTargetLocation()
    let beforeTOT = makeTarget(timeOnTarget: now.addingTimeInterval(60))
    let afterTOT = makeTarget(timeOnTarget: now.addingTimeInterval(-1))

    let stillInbound = GuidanceHelper(location: location, target: beforeTOT, now: now).guidance
    let postPass = GuidanceHelper(location: location, target: afterTOT, now: now).guidance

    #expect(stillInbound != .postPass)
    #expect(postPass == .postPass)
  }

  @Test("guidance is not .postPass when past TOT but before target")
  func gatingRejectsPastTOTBeforeTarget() {
    let location = makeLocation(at: postIP)  // between IP and target
    let target = makeTarget(timeOnTarget: now.addingTimeInterval(-30))

    let guidance = GuidanceHelper(location: location, target: target, now: now).guidance

    #expect(guidance != .postPass)
  }

  // MARK: - NextTarget pick

  @Test("NextTarget.next, picks the soonest future TOT and excludes the current target")
  func nextTargetPicksSoonestFuture() throws {
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

  @Test("NextTarget.next, returns nil when no future targets qualify")
  func nextTargetNilWhenNoneQualify() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now

    let past = Target(name: "Past", coordinate: targetCoordinate)
    past.timeOnTarget = now.addingTimeInterval(-120)

    let noTOT = Target(name: "NoTOT", coordinate: targetCoordinate)

    #expect(NextTarget.next(after: current, in: [current, past, noTOT], now: now) == nil)
  }

  @Test("NextTarget.next, returns the next target by TOT even when behind schedule")
  func nextTargetReturnsNextWhenBehindSchedule() throws {
    let now = Date(timeIntervalSince1970: 1_000_000)

    // The whole run is late: both the just-flown target and the next one have TOTs in the past.
    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now.addingTimeInterval(-600)

    let next = Target(name: "Next", coordinate: targetCoordinate)
    next.timeOnTarget = now.addingTimeInterval(-120)

    let chosen = try #require(NextTarget.next(after: current, in: [current, next], now: now))
    #expect(chosen.id == next.id)
  }

  @Test("PostPassResult.capture is idempotent until reset")
  func captureIsIdempotentUntilReset() throws {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    result.capture(targetName: "First", timeOnTarget: tot, now: tot.addingTimeInterval(5))
    result.capture(targetName: "Second", timeOnTarget: tot, now: tot.addingTimeInterval(99))

    let firstCapture = try #require(result.capture)
    #expect(firstCapture.targetName == "First")
    #expect(firstCapture.missSeconds == 5)

    result.reset()
    #expect(result.capture == nil)

    result.capture(targetName: "Third", timeOnTarget: tot, now: tot.addingTimeInterval(-3))
    let thirdCapture = try #require(result.capture)
    #expect(thirdCapture.targetName == "Third")
    #expect(thirdCapture.missSeconds == -3)
  }

  @Test("PostPassResult.capture times an early crossing from the crossing, not from TOT")
  func captureUsesCrossingTimeForEarlyPass() {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    // The aircraft crossed the target 20 s before TOT; the post-pass state is only entered once the
    // clock reaches TOT, so the miss must come from the recorded crossing — a 20 s-early pass.
    result.recordCrossing(at: tot.addingTimeInterval(-20))
    result.capture(targetName: "T", timeOnTarget: tot, now: tot)

    #expect(result.capture?.missSeconds == -20)
  }

  @Test("PostPassResult.capture falls back to now when no crossing was recorded")
  func captureFallsBackToNowWithoutCrossing() {
    let result = PostPassResult()
    let tot = Date(timeIntervalSince1970: 1_700_000_000)

    result.capture(targetName: "T", timeOnTarget: tot, now: tot.addingTimeInterval(8))

    #expect(result.capture?.missSeconds == 8)
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
      course: Bearing(angle: 180, reference: .true),
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
      coordinate: coordinate.toCoreLocation,
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
