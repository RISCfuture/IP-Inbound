import Foundation
import Numerics
import Testing

@testable import IP_Inbound

@Suite("Streams")
struct StreamsTests {

  @Test("MulticastStream - can broadcast to multiple consumers")
  func multicastStreamBroadcast() async throws {
    let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
    let multicastStream = MulticastStream(stream: stream)

    let consumer1 = await multicastStream.consume()
    let consumer2 = await multicastStream.consume()

    let expected = [1, 2, 3]

    let task1 = Task { try await collect(expected.count, from: consumer1) }
    let task2 = Task { try await collect(expected.count, from: consumer2) }

    for value in expected { continuation.yield(value) }

    let results1 = try await task1.value
    let results2 = try await task2.value

    #expect(results1 == expected)
    #expect(results2 == expected)

    await multicastStream.stop()
    continuation.finish()
  }

  @Test("MulticastStream - handles errors correctly")
  func multicastStreamErrors() async throws {
    enum TestError: Error {
      case testCase
    }

    let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
    let multicastStream = MulticastStream(stream: stream)
    let consumer = await multicastStream.consume()

    let task = Task { () -> Error? in
      do {
        for try await value in consumer where value == 2 {
          continuation.finish(throwing: TestError.testCase)
        }
        return nil
      } catch {
        return error
      }
    }

    continuation.yield(1)
    continuation.yield(2)

    let receivedError = await task.value
    #expect(receivedError is TestError)

    await multicastStream.stop()
  }

  @Test("MulticastStream - stopping finishes the streams it vended", .timeLimit(.minutes(1)))
  func multicastStreamStopFinishesConsumers() async throws {
    let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
    defer { continuation.finish() }

    let multicastStream = MulticastStream(stream: stream)
    let consumer = await multicastStream.consume()
    await multicastStream.stop()

    // A consumer left attached to a stopped broadcast has no element coming and no end coming
    // either, so this loop would suspend for the rest of the run and the time limit is what would
    // report it.
    for try await _ in consumer {}
  }

  @Test("bootstrap - prepends initial value to stream")
  func bootstrapPrependsInitialValue() async throws {
    let (stream, continuation) = AsyncThrowingStream<Int, Error>.makeStream()
    let bootstrappedStream = bootstrap(stream: stream, initial: 0)

    let expected = [0, 1, 2, 3]

    let task = Task { try await collect(expected.count, from: bootstrappedStream) }

    continuation.yield(1)
    continuation.yield(2)
    continuation.yield(3)

    let results = try await task.value
    #expect(results == expected)

    continuation.finish()
  }

  @Test("extrapolate - extrapolates values driven by an injected clock")
  func extrapolateEmitsClockDrivenValues() async throws {
    let interval = 0.2
    let maxTime = 1.0
    let valueRatePerSecond = 10.0

    // A deterministic clock that advances by a fixed step on every `now()` call. Because
    // the step is positive and monotonic, `extrapolate`'s `now() - start < maxTime` loop
    // condition is guaranteed to fail after a bounded number of iterations, so the number
    // of emitted events is deterministic — it does not depend on wall-clock pacing of the
    // production `Task.sleep`.
    let clock = SteppingClock(start: Date(timeIntervalSinceReferenceDate: 0), step: interval)
    let dateProvider = DateProvider(now: { clock.advance() }, offsetFromRealTime: .zero)

    let (stream, continuation) = AsyncThrowingStream<TestEvent, Error>.makeStream()
    let extrapolatedStream = extrapolate(
      stream: stream,
      maxTime: maxTime,
      interval: interval,
      dateProvider: dateProvider
    ) { event, timeOffset in
      TestEvent(
        value: event.value + timeOffset * valueRatePerSecond,
        timestamp: event.timestamp.addingTimeInterval(timeOffset)
      )
    }

    let originalTimestamp = Date(timeIntervalSinceReferenceDate: 1000)
    let expectedCount = 4  // original element + 3 clock-bounded extrapolations

    let task = Task { try await collect(expectedCount, from: extrapolatedStream) }
    continuation.yield(TestEvent(value: 0, timestamp: originalTimestamp))

    let results = try await task.value
    continuation.finish()

    #expect(results.count == expectedCount)
    #expect(results[0].value == 0)
    #expect(results[0].timestamp == originalTimestamp)

    // Each extrapolated value must satisfy the extrapolation formula relative to its own
    // (clock-derived) timestamp. This is an internal-consistency invariant that holds
    // regardless of how many `now()` calls the production loop makes per iteration.
    for event in results.dropFirst() {
      let offset = event.timestamp.timeIntervalSince(originalTimestamp)
      #expect(offset > 0)
      #expect(event.value.isApproximatelyEqual(to: offset * valueRatePerSecond))
    }

    // Offsets must be strictly increasing, proving the clock drives each successive event.
    let offsets = results.dropFirst().map { $0.timestamp.timeIntervalSince(originalTimestamp) }
    #expect(offsets == offsets.sorted())
    #expect(Set(offsets).count == offsets.count)
  }

  // MARK: Helpers

  // Collects exactly `count` elements from `stream`, returning once that many have arrived.
  private func collect<S: AsyncSequence>(
    _ count: Int,
    from stream: S
  ) async throws -> [S.Element] {
    var collected = [S.Element]()
    collected.reserveCapacity(count)
    for try await element in stream {
      collected.append(element)
      if collected.count == count { break }
    }
    return collected
  }

  // MARK: Subtypes

  // A monotonic, deterministic clock for driving time-based streams in tests. Each call to
  // ``advance()`` returns the next instant, `step` seconds after the previous one.
  private final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private let start: Date
    private let step: TimeInterval
    private var tick = 0

    init(start: Date, step: TimeInterval) {
      self.start = start
      self.step = step
    }

    func advance() -> Date {
      lock.lock()
      defer { lock.unlock() }
      let now = start.addingTimeInterval(Double(tick) * step)
      tick += 1
      return now
    }
  }

  private struct TestEvent: Sendable, Equatable {
    var value: Double
    var timestamp: Date
  }
}
