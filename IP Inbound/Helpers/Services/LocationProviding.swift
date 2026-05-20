import Foundation

/// Abstraction over the source of `LocationEvent`s consumed by the UI. The live
/// implementation is ``LocationStreamer``; UI tests use ``UITestLocationProvider``.
protocol LocationProviding: Sendable {
  func start() async
  func stop() async
  func eventStream() async -> AsyncThrowingStream<LocationEvent, any Error>?
  func currentEvent() async -> LocationEvent?
}
