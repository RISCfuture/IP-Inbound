import Foundation
import NIOConcurrencyHelpers

actor MulticastStream<T: Sendable, E: Error> {
  typealias Continuation = AsyncThrowingStream<T, any Error>.Continuation

  private var consumers = [UUID: Continuation]()
  private var broadcastTask: Task<Void, Never>?
  private let stream: AsyncThrowingStream<T, E>

  init(stream: AsyncThrowingStream<T, E>) {
    self.stream = stream
  }

  func start() {
    guard broadcastTask == nil else { return }

    broadcastTask = Task {
      do {
        for try await element in stream {
          for continuation in consumers.values {
            continuation.yield(element)
          }
        }
      } catch {
        // Forward any failure to consumers (whose continuations are typed `any Error`) rather than
        // trapping on an error whose concrete type doesn't match `E`.
        for continuation in consumers.values {
          continuation.finish(throwing: error)
        }
      }
    }
  }

  func stop() {
    broadcastTask?.cancel()
    broadcastTask = nil
  }

  func consume() -> AsyncThrowingStream<T, any Error> {
    defer { start() }

    return AsyncThrowingStream { continuation in
      let id = add(continuation: continuation)
      continuation.onTermination = { _ in
        Task { await self.remove(consumer: id) }
      }
    }
  }

  private func add(continuation: Continuation) -> UUID {
    let id = UUID()
    consumers[id] = continuation
    return id
  }

  private func remove(consumer id: UUID) {
    consumers.removeValue(forKey: id)
  }
}

func bootstrap<T: Sendable, S: Sendable & AsyncSequence<T, any Error>>(
  stream: S,
  initial: T
) -> AsyncThrowingStream<T, any Error> {
  AsyncThrowingStream { continuation in
    continuation.yield(initial)
    let task = Task {
      do {
        for try await element in stream {
          continuation.yield(element)
        }
      } catch {
        continuation.finish(throwing: error)
      }
    }

    continuation.onTermination = { _ in task.cancel() }
  }
}

func extrapolate<T: Sendable, S: Sendable & AsyncSequence<T, any Error>>(
  stream: S,
  maxTime: TimeInterval,
  interval: TimeInterval,
  dateProvider: DateProvider = .system,
  extrapolate: @Sendable @escaping (T, TimeInterval) -> T
) -> AsyncThrowingStream<T, any Error> {
  AsyncThrowingStream { continuation in
    let task = Task {
      var extrapolationTask: Task<Void, Never>?

      do {
        for try await element in stream {
          continuation.yield(element)

          extrapolationTask?.cancel()
          extrapolationTask = Task {
            let extrapolationStart = dateProvider.now()
            repeat {
              try? await Task.sleep(for: .seconds(interval))
              let elapsed = dateProvider.now().timeIntervalSince(extrapolationStart)
              let extrapolated = extrapolate(element, elapsed)
              continuation.yield(extrapolated)
            } while !Task.isCancelled
              && dateProvider.now().timeIntervalSince(extrapolationStart) < maxTime
          }
        }
      } catch {
        extrapolationTask?.cancel()
        continuation.finish(throwing: error)
      }
    }

    continuation.onTermination = { _ in task.cancel() }
  }
}
