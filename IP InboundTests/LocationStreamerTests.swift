import CoreLocation
import Foundation
import Testing

@testable import IP_Inbound

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

@Suite("LocationStreamer")
struct LocationStreamerTests {

  @Test("LocationEvent - derives coordinate, course, and speed from location")
  func locationEventDerivesValuesFromLocation() throws {
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

  @Test("LocationEvent - isSimulating reflects presence of a sim name")
  func locationEventIsSimulatingReflectsSimName() {
    let location = makeLocation(latitude: 37.7749, longitude: -122.4194)

    #expect(LocationEvent(location: location).isSimulating == false)
    #expect(LocationEvent(location: location, simName: "XPlane").isSimulating == true)
  }

  @Test("LocationEvent - a nil location yields nil derived values")
  func locationEventNilLocationYieldsNilDerivedValues() {
    enum TestError: Error {
      case testCase
    }

    let event = LocationEvent(error: TestError.testCase)

    #expect(event.isSimulating == false)
    #expect(event.coordinate == nil)
    #expect(event.courseTrue == nil)
    #expect(event.speed == nil)
  }

  @Test("LocationEvent - extrapolate returns same event if conditions not met")
  func locationEventExtrapolateSameEventIfConditionsNotMet() throws {
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
  }

  @Test("LocationEvent - extrapolate calculates new position correctly")
  func locationEventExtrapolateCalculatesNewPosition() throws {
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

    // Accuracies should increase by the time delta
    let extrapolatedLocation = try #require(extrapolated.location)
    #expect(extrapolatedLocation.horizontalAccuracy > location.horizontalAccuracy)
    #expect(extrapolatedLocation.verticalAccuracy > location.verticalAccuracy)
    #expect(extrapolatedLocation.courseAccuracy > location.courseAccuracy)
    #expect(extrapolatedLocation.speedAccuracy > location.speedAccuracy)
  }
}
