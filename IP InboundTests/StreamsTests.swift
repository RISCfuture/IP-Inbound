import Foundation
import Testing

@testable import IP_Inbound

@Suite(.disabled("Streams (non-deterministic)"))
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

    // Use actors to collect values safely across tasks
    actor ResultsCollector {
      var values: [Int] = []

      func append(_ value: Int) {
        values.append(value)
      }

      func getValues() -> [Int] {
        values
      }
    }

    let collector1 = ResultsCollector()
    let collector2 = ResultsCollector()

    let task1 = Task {
      for try await value in consumer1 {
        await collector1.append(value)
        if value == 3 { break }  // Stop after receiving 3
      }
    }

    let task2 = Task {
      for try await value in consumer2 {
        await collector2.append(value)
        if value == 3 { break }  // Stop after receiving 3
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
    let results1 = await collector1.getValues()
    let results2 = await collector2.getValues()
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

    // Use an actor to store the error safely
    actor ErrorCollector {
      var error: Error?

      func setError(_ error: Error) {
        self.error = error
      }

      func getError() -> Error? {
        error
      }
    }

    let errorCollector = ErrorCollector()

    let task = Task {
      do {
        for try await value in consumer where value == 2 {
          continuation.finish(throwing: TestError.testCase)
        }
      } catch {
        await errorCollector.setError(error)
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
    let receivedError = await errorCollector.getError()
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

    // Use an actor to collect values safely
    actor ResultsCollector {
      var values: [Int] = []

      func append(_ value: Int) {
        values.append(value)
      }

      func getValues() -> [Int] {
        values
      }
    }

    let collector = ResultsCollector()

    let task = Task {
      for try await value in bootstrappedStream {
        await collector.append(value)
        if value == 3 { break }  // Stop after receiving 3
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
    let results = await collector.getValues()
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
        value: event.value + timeOffset * 10,  // Increment by 10 per second
        timestamp: event.timestamp.addingTimeInterval(timeOffset)
      )
    }

    // Use an actor to collect values safely
    actor EventCollector {
      var events: [TestEvent] = []

      func append(_ event: TestEvent) {
        events.append(event)
      }

      func getEvents() -> [TestEvent] {
        events
      }

      func count() -> Int {
        events.count
      }
    }

    let collector = EventCollector()

    let task = Task {
      for try await value in extrapolatedStream {
        await collector.append(value)
        let count = await collector.count()
        if count == 6 {
          break
        }
      }
    }

    // Send a value through the original stream
    let startTime = Date()
    continuation.yield(TestEvent(value: 0, timestamp: startTime))

    // Wait for the task to collect all values with timeout
    let timeoutTask = Task {
      try await Task.sleep(for: .seconds(2))
      task.cancel()
    }

    _ = await task.result
    timeoutTask.cancel()

    // Clean up
    continuation.finish()

    // Get the collected results
    let results = await collector.getEvents()

    // Check that we got exactly 6 values (original + 5 extrapolated)
    #expect(results.count == 6)
    #expect(results[0].value == 0)  // Original value

    // Check the extrapolated values match the formula with tolerance
    for i in 1..<results.count {
      let actualOffset = results[i].timestamp.timeIntervalSince(startTime)
      let expectedValue = actualOffset * 10

      // Value should match our extrapolation formula (based on actual elapsed time)
      #expect(results[i].value.isApproximatelyEqual(to: expectedValue, relativeTolerance: 0.05))

      // Timestamp should be close to expected intervals (within 50ms tolerance)
      let expectedOffset = Double(i) * 0.2
      #expect(actualOffset.isApproximatelyEqual(to: expectedOffset, absoluteTolerance: 0.05))
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
