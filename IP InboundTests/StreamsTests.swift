import Foundation
@testable import IP_Inbound
import Testing
import XCTest

@Suite("Streams")
struct StreamsTests {

    @Test("MulticastStream - can broadcast to multiple consumers")
    func testMulticastStreamBroadcast() async throws {
        // Set up a simple input stream
        let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()

        // Create the multicast stream
        let multicastStream = MulticastStream(stream: stream)

        // Set up two consumer streams
        let consumer1 = await multicastStream.consume()
        let consumer2 = await multicastStream.consume()

        // Set up tasks to collect values from consumers
        var results1: [Int] = []
        var results2: [Int] = []

        let task1 = Task {
            for try await value in consumer1 {
                results1.append(value)
                if value == 3 { break } // Stop after receiving 3
            }
        }

        let task2 = Task {
            for try await value in consumer2 {
                results2.append(value)
                if value == 3 { break } // Stop after receiving 3
            }
        }

        // Send values through the original stream
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)

        // Wait for tasks to complete
        _ = await task1.result
        _ = await task2.result

        // Check that both consumers received the values
        #expect(results1 == [1, 2, 3])
        #expect(results2 == [1, 2, 3])

        // Clean up
        await multicastStream.stop()
        continuation.finish()
    }

    @Test("MulticastStream - handles errors correctly")
    func testMulticastStreamErrors() async throws {
        // Define a test error
        enum TestError: Error {
            case testCase
        }

        // Set up a stream that will throw an error
        let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()

        // Create the multicast stream
        let multicastStream = MulticastStream(stream: stream)

        // Set up a consumer stream
        let consumer = await multicastStream.consume()

        // Set up a task to collect values and catch errors
        var receivedError: Error?

        let task = Task {
            do {
                for try await value in consumer where value == 2 {
                    continuation.finish(throwing: TestError.testCase)
                }
            } catch {
                receivedError = error
            }
        }

        // Send values through the original stream
        continuation.yield(1)
        continuation.yield(2)

        // Wait a moment for the error to propagate
        try await Task.sleep(for: .milliseconds(100))

        // Wait for task to complete
        _ = await task.result

        // Check that the consumer received the error
        #expect(receivedError is TestError)

        // Clean up
        await multicastStream.stop()
    }

    @Test("bootstrap - prepends initial value to stream")
    func testBootstrap() async throws {
        // Set up a simple input stream
        let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()

        // Create the bootstrapped stream with initial value 0
        let bootstrappedStream = bootstrap(stream: stream, initial: 0)

        // Set up a task to collect values
        var results: [Int] = []

        let task = Task {
            for try await value in bootstrappedStream {
                results.append(value)
                if value == 3 { break } // Stop after receiving 3
            }
        }

        // Send values through the original stream (after a small delay)
        try await Task.sleep(for: .milliseconds(100))
        continuation.yield(1)
        continuation.yield(2)
        continuation.yield(3)

        // Wait for task to complete
        _ = await task.result

        // Check that the bootstrapped stream received the initial value followed by the stream values
        #expect(results == [0, 1, 2, 3])

        // Clean up
        continuation.finish()
    }

    @Test("extrapolate - extrapolates values at specified intervals")
    func testExtrapolate() async throws {
        // Set up a simple input stream with timestamps
        let (stream, continuation) = AsyncThrowingStream<TestEvent, Error>.makeStream()

        // Create the extrapolated stream with a maxTime of 1 second and interval of 0.2 seconds
        let extrapolatedStream = extrapolate(
            stream: stream,
            maxTime: 1.0,
            interval: 0.2
        ) { event, timeOffset in
            // Simple extrapolation logic - increment value by timeOffset
            TestEvent(
                value: event.value + timeOffset * 10, // Increment by 10 per second
                timestamp: event.timestamp.addingTimeInterval(timeOffset)
            )
        }

        // Set up a task to collect values
        var results: [TestEvent] = []

        let task = Task {
            var count = 0
            for try await value in extrapolatedStream {
                results.append(value)
                count += 1
                if count >= 7 { break } // To avoid an infinite loop
            }
        }

        // Send a value through the original stream
        let startTime = Date()
        continuation.yield(TestEvent(value: 0, timestamp: startTime))

        // Wait long enough to see some extrapolated values
        try await Task.sleep(for: .seconds(0.5))

        // Cancel the task to stop collection
        task.cancel()

        // Clean up
        continuation.finish()

        // Check that we got the original value plus some extrapolated values
        #expect(results.count >= 2)
        #expect(results[0].value == 0) // Original value

        // The extrapolated values should have increasing values
        // and timestamps close to the expected intervals
        for i in 1..<results.count {
            let expectedOffset = Double(i) * 0.2
            let expectedValue = expectedOffset * 10
            let expectedTime = startTime.addingTimeInterval(expectedOffset)

            // Value should match our extrapolation formula
            #expect(results[i].value.isApproximatelyEqual(to: expectedValue, relativeTolerance: 0.1))

            // Timestamp should be close to expected intervals
            let actualOffset = results[i].timestamp.timeIntervalSince(startTime)
            #expect(actualOffset.isApproximatelyEqual(to: expectedOffset, relativeTolerance: 0.1))
        }
    }

    // A helper struct for unit tests
    private struct TestEvent: Sendable, Equatable {
        var value: Double
        var timestamp: Date

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.value == rhs.value && lhs.timestamp == rhs.timestamp
        }
    }
}
