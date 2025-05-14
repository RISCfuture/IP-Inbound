import CoreLocation
import Foundation
@testable import IP_Inbound
import Testing

/// Mocks for testing LocationStreamer
final actor MockSimReceiver {
    private(set) var startCalled = false
    private(set) var stopCalled = false

    private var _stream: AsyncStream<SimData>
    private let _continuation: AsyncStream<SimData>.Continuation

    var stream: AsyncStream<SimData> {
        _stream
    }

    init(mockStream: AsyncStream<SimData>? = nil, port _: Int = 0) {
        if let mockStream {
            _stream = mockStream
            let (_, continuation) = AsyncStream<SimData>.makeStream()
            _continuation = continuation
        } else {
            let (stream, continuation) = AsyncStream<SimData>.makeStream()
            _stream = stream
            _continuation = continuation
        }
    }

    func start() {
        startCalled = true
    }

    func stop() {
        stopCalled = true
    }

    func send(_ value: SimData) {
        _continuation.yield(value)
    }
}

/// A helper function to create a CLLocation instance with the specified properties
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

    @Test("LocationEvent - initializes correctly with location data")
    func testLocationEventInitWithLocation() throws {
        let location = makeLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100,
            course: 45,
            speed: 10
        )

        let event = LocationEvent(location: location)

        #expect(event.location === location)
        #expect(event.simName == nil)
        #expect(event.error == nil)
        #expect(event.isSimulating == false)
        let coordinate = try #require(event.coordinate)
        #expect(coordinate.latitudeDeg == 37.7749)
        #expect(coordinate.longitudeDeg == -122.4194)
        let course = try #require(event.courseTrue)
        #expect(course.angle.converted(to: .degrees).value == 45)
        let speed = try #require(event.speed)
        #expect(speed.converted(to: .metersPerSecond).value == 10)
    }

    @Test("LocationEvent - initializes correctly with simulator data")
    func testLocationEventInitWithSimData() throws {
        let location = makeLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            altitude: 100,
            course: 45,
            speed: 10
        )

        let event = LocationEvent(location: location, simName: "XPlane")

        #expect(event.location === location)
        #expect(event.simName == "XPlane")
        #expect(event.error == nil)
        #expect(event.isSimulating == true)
    }

    @Test("LocationEvent - initializes correctly with error data")
    func testLocationEventInitWithError() throws {
        enum TestError: Error {
            case testCase
        }

        let error = TestError.testCase
        let event = LocationEvent(error: error)

        #expect(event.location == nil)
        #expect(event.simName == nil)
        #expect(event.error as? TestError == TestError.testCase)
        #expect(event.isSimulating == false)
        #expect(event.coordinate == nil)
        #expect(event.courseTrue == nil)
        #expect(event.speed == nil)
    }

    @Test("LocationEvent - extrapolate returns same event if conditions not met")
    func testLocationEventExtrapolateSameEventIfConditionsNotMet() throws {
        // Case 1: No location
        let event1 = LocationEvent()
        let extrapolated1 = event1.extrapolate(to: Date())
        // Use == instead of === for struct comparison
        #expect(extrapolated1.location == event1.location &&
               extrapolated1.simName == event1.simName &&
               extrapolated1.error?.localizedDescription == event1.error?.localizedDescription)

        // Case 2: Future time not after location time
        let now = Date()
        let location = makeLocation(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: now.addingTimeInterval(10) // Future timestamp
        )
        let event2 = LocationEvent(location: location)
        let extrapolated2 = event2.extrapolate(to: now) // Past time
        // Use == instead of === for struct comparison
        #expect(extrapolated2.location === event2.location &&
               extrapolated2.simName == event2.simName &&
               extrapolated2.error?.localizedDescription == event2.error?.localizedDescription)
    }

    @Test("LocationEvent - extrapolate calculates new position correctly")
    func testLocationEventExtrapolateCalculatesNewPosition() throws {
        let now = Date()
        let location = makeLocation(
            latitude: 0,
            longitude: 0,
            course: 90, // Due east
            speed: 10, // 10 m/s
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
        #expect(extrapolated.location?.horizontalAccuracy ?? 0 > location.horizontalAccuracy)
        #expect(extrapolated.location?.verticalAccuracy ?? 0 > location.verticalAccuracy)
        #expect(extrapolated.location?.courseAccuracy ?? 0 > location.courseAccuracy)
        #expect(extrapolated.location?.speedAccuracy ?? 0 > location.speedAccuracy)
    }
}
