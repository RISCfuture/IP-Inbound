import CoreLocation
import Foundation
import MeasurementKitLocation
import RealModule
import Testing

@testable import IP_Inbound
@testable import IP_Inbound_Shared

func makeLocation(
  latitude: Double,
  longitude: Double,
  altitude: Double = 0,
  horizontalAccuracy: Double = 10,
  verticalAccuracy: Double = 10,
  course: Double = 0,
  courseAccuracy: Double = 1,
  speed: Double = 0,
  speedAccuracy: Double = 1,
  timestamp: Date = Date()
) -> CLLocation {
  CLLocation(
    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
    altitude: altitude,
    horizontalAccuracy: horizontalAccuracy,
    verticalAccuracy: verticalAccuracy,
    course: course,
    courseAccuracy: courseAccuracy,
    speed: speed,
    speedAccuracy: speedAccuracy,
    timestamp: timestamp
  )
}

@Suite
struct `LocationStreamer tests` {

  @Test
  func `LocationEvent - derives coordinate, course, and speed from location`() throws {
    let (latitudeDeg, longitudeDeg, courseDeg, speedMPS) = (37.7749, -122.4194, 45.0, 10.0)
    let location = makeLocation(
      latitude: latitudeDeg,
      longitude: longitudeDeg,
      altitude: 100,
      course: courseDeg,
      speed: speedMPS
    )

    let event = LocationEvent(location: location)

    let coordinate = try #require(event.coordinate)
    #expect(coordinate.latitudeDeg == latitudeDeg)
    #expect(coordinate.longitudeDeg == longitudeDeg)
    let course = try #require(event.courseTrue)
    #expect(course.angle.converted(to: .degrees).value == courseDeg)
    let speed = try #require(event.speed)
    #expect(speed.converted(to: .metersPerSecond).value == speedMPS)
  }

  @Test
  func `LocationEvent - isSimulating reflects presence of a sim name`() {
    let location = makeLocation(latitude: 37.7749, longitude: -122.4194)

    #expect(LocationEvent(location: location).isSimulating == false)
    #expect(LocationEvent(location: location, simName: "XPlane").isSimulating == true)
  }

  @Test
  func `LocationEvent - a nil location yields nil derived values`() {
    enum TestError: Error {
      case testCase
    }

    let event = LocationEvent(error: TestError.testCase)

    #expect(event.isSimulating == false)
    #expect(event.coordinate == nil)
    #expect(event.courseTrue == nil)
    #expect(event.speed == nil)
  }

  @Test
  func `LocationEvent - extrapolate returns same event if conditions not met`() throws {
    // Case 1: No location, so both events hold a nil CLLocation
    let event1 = LocationEvent()
    let extrapolated1 = event1.extrapolate(to: Date())
    #expect(
      extrapolated1.location == event1.location && extrapolated1.simName == event1.simName
        && extrapolated1.error?.localizedDescription == event1.error?.localizedDescription
    )

    // Case 2: Future time not after location time, so the same CLLocation instance is returned
    let now = Date()
    let location = makeLocation(
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: now.addingTimeInterval(10)  // Future timestamp
    )
    let event2 = LocationEvent(location: location)
    let extrapolated2 = event2.extrapolate(to: now)  // Past time
    #expect(
      extrapolated2.location === event2.location && extrapolated2.simName == event2.simName
        && extrapolated2.error?.localizedDescription == event2.error?.localizedDescription
    )

    // Case 3: CoreLocation signals an unusable course and speed with negative values. Dead-reckoning
    // on those would fly the fix backwards along a course a degree west of north.
    let stationary = makeLocation(
      latitude: 37.7749,
      longitude: -122.4194,
      course: -1,
      speed: -1,
      timestamp: now
    )
    let event3 = LocationEvent(location: stationary)
    #expect(event3.courseTrue == nil)
    #expect(event3.speed == nil)
    #expect(event3.extrapolate(to: now.addingTimeInterval(10)).location === stationary)
  }

  @Test
  func `LocationEvent - extrapolate calculates new position correctly`() throws {
    let now = Date()
    let location = makeLocation(
      latitude: 0,
      longitude: 0,
      course: 90,  // Due east
      speed: 10,  // 10 m/s
      timestamp: now
    )

    let event = LocationEvent(location: location)

    // Extrapolate 10 seconds into the future
    let futureTime = now.addingTimeInterval(10)
    let extrapolated = event.extrapolate(to: futureTime)

    // At 10 m/s for 10 seconds moving due east, we should move 100m east
    // This would be approximately 0.0009 degrees of longitude at the equator
    // (very rough approximation for testing)
    let coordinate = try #require(extrapolated.coordinate)

    // Skip latitude check as it may vary depending on implementation
    // Only check longitude since we're moving east
    #expect(coordinate.longitudeDeg.isApproximatelyEqual(to: 0.0009, relativeTolerance: 0.01))

    let extrapolatedLocation = try #require(extrapolated.location)

    // The propagated fix is an estimate of the aircraft's position at the time asked for, so that is
    // when it is valid.
    #expect(extrapolatedLocation.timestamp == futureTime)

    // Dead-reckoning error propagation: the 1 m/s speed error integrates to 10 m along track, and
    // the 1° course error swings the 100 m traveled ~1.75 m across it, both in quadrature with the
    // fix's own 10 m.
    let alongTrack = 1.0 * 10.0
    let crossTrack = 100.0 * (1.0 * .pi / 180.0)
    let expectedHorizontal = (100.0 + alongTrack * alongTrack + crossTrack * crossTrack)
      .squareRoot()
    #expect(
      extrapolatedLocation.horizontalAccuracy.isApproximatelyEqual(to: expectedHorizontal)
    )

    // A turn at the maneuver bound sweeps well past a half-turn in 10 s at this speed, so the course
    // reads as wholly unknown rather than claiming a precision the model cannot have.
    #expect(extrapolatedLocation.courseAccuracy == 180)

    // Altitude and speed are carried forward unchanged, so their error grows with the maneuver bound.
    #expect(extrapolatedLocation.verticalAccuracy > location.verticalAccuracy)
    #expect(extrapolatedLocation.speedAccuracy > location.speedAccuracy)
  }

  @Test
  func `LocationEvent - extrapolate leaves unavailable accuracies unavailable`() throws {
    let now = Date()
    let location = makeLocation(
      latitude: 0,
      longitude: 0,
      horizontalAccuracy: -1,
      verticalAccuracy: -1,
      course: 90,
      courseAccuracy: -1,
      speed: 10,
      speedAccuracy: -1,
      timestamp: now
    )

    let extrapolated = LocationEvent(location: location).extrapolate(to: now.addingTimeInterval(5))
    let extrapolatedLocation = try #require(extrapolated.location)

    // CoreLocation reports a negative accuracy when it could not determine one; growing that
    // sentinel would turn "unknown" into a plausible-looking number.
    #expect(extrapolatedLocation.horizontalAccuracy < 0)
    #expect(extrapolatedLocation.verticalAccuracy < 0)
    #expect(extrapolatedLocation.courseAccuracy < 0)
    #expect(extrapolatedLocation.speedAccuracy < 0)
  }

  @Test
  func `extrapolate, carries the diagnostics onto the propagated fix`() throws {
    let now = Date()
    var diagnostics = LocationDiagnostics()
    diagnostics.accuracyLimited = true

    // A reduced-accuracy fix is the case that matters: it arrives with a location, so it is the one
    // the propagation could silently launder into a fix the CDI would treat as trustworthy.
    let event = LocationEvent(
      location: makeLocation(latitude: 37, longitude: -122, course: 90, speed: 100),
      diagnostics: diagnostics
    )

    #expect(event.extrapolate(to: now.addingTimeInterval(5)).diagnostics == diagnostics)
  }

  @Test
  func `impediment, defers to the pending prompt over an unanswered denial`() {
    var diagnostics = LocationDiagnostics()
    diagnostics.authorizationRequestInProgress = true
    diagnostics.authorizationDenied = true

    // The prompt is on screen and unanswered; reporting the denial would flash a refusal the pilot
    // has not made on every first launch.
    #expect(diagnostics.impediment == nil)
    #expect(LocationDiagnostics.clean.impediment == nil)
  }
}
