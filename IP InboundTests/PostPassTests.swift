import Foundation
import Testing

@testable import IP_Inbound

@Suite("Post-Pass Tests")
struct PostPassTests {
  private let targetCoordinate = Coordinate(latitude: 36.772367, longitude: -115.453840)
  private let postIP = Coordinate(latitude: 36.8078222222, longitude: -115.4840472222)
  private let beyondTarget = Coordinate(latitude: 36.700000, longitude: -115.453840)

  @Test("isPastTarget, beyond the target, returns true")
  func isPastTargetWhenBeyond() throws {
    let target = Target(name: "Test Target", coordinate: targetCoordinate)
    target.offsetBearing = 359
    target.offsetDistance = 4.8

    let math = IPTargetMath(
      coordinate: beyondTarget,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target
    )

    #expect(math.isPastTarget)
  }

  @Test("isPastTarget, before the target, returns false")
  func isPastTargetWhenBeforeTarget() throws {
    let target = Target(name: "Test Target", coordinate: targetCoordinate)
    target.offsetBearing = 359
    target.offsetDistance = 4.8

    // postIP is between the IP and the target along the run-in axis, so the
    // aircraft has passed the IP but not yet reached the target.
    let math = IPTargetMath(
      coordinate: postIP,
      speed: Measurement(value: 500, unit: .knots),
      course: Bearing(angle: 180, reference: .true),
      target: target
    )

    #expect(!math.isPastTarget)
  }

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
  func nextTargetNilWhenNoneQualify() throws {
    let now = Date(timeIntervalSince1970: 1_000_000)

    let current = Target(name: "Current", coordinate: targetCoordinate)
    current.timeOnTarget = now

    let past = Target(name: "Past", coordinate: targetCoordinate)
    past.timeOnTarget = now.addingTimeInterval(-120)

    let noTOT = Target(name: "NoTOT", coordinate: targetCoordinate)

    #expect(NextTarget.next(after: current, in: [current, past, noTOT], now: now) == nil)
  }

  @Test("PostPassResult.capture is idempotent until reset")
  func captureIsIdempotentUntilReset() throws {
    let result = PostPassResult()

    result.capture(targetName: "First", missSeconds: 5)
    result.capture(targetName: "Second", missSeconds: 99)

    let firstCapture = try #require(result.capture)
    #expect(firstCapture.targetName == "First")
    #expect(firstCapture.missSeconds == 5)

    result.reset()
    #expect(result.capture == nil)

    result.capture(targetName: "Third", missSeconds: -3)
    let thirdCapture = try #require(result.capture)
    #expect(thirdCapture.targetName == "Third")
    #expect(thirdCapture.missSeconds == -3)
  }
}
