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
            } catch let error as E {
                for continuation in consumers.values {
                    continuation.finish(throwing: error)
                }
            } catch {
                fatalError(error.localizedDescription)
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
    stream: S, initial: T
) -> AsyncThrowingStream<T, any Error> {
    AsyncThrowingStream { continuation in
        continuation.yield(initial)
        let task = Task { @Sendable in
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
    extrapolate: @Sendable @escaping (T, TimeInterval) -> T
) -> AsyncThrowingStream<T, any Error> {
    AsyncThrowingStream { continuation in
        let task = Task { @Sendable in
            var extrapolationTask: Task<Void, Never>?

            do {
                for try await element in stream {
                    continuation.yield(element)

                    extrapolationTask?.cancel()
                    extrapolationTask = Task {
                        let extrapolationStart = Date()
                        repeat {
                            try? await Task.sleep(for: .seconds(interval))
                            let extrapolated = extrapolate(
                                element,
                                -extrapolationStart.timeIntervalSinceNow
                            )
                            continuation.yield(extrapolated)
                        } while !Task.isCancelled && extrapolationStart.timeIntervalSinceNow > -maxTime
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
