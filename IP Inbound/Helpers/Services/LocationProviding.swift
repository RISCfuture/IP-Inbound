import Foundation

/// Abstraction over the source of `LocationEvent`s consumed by the UI. The live
/// implementation is ``LocationStreamer``; UI tests use ``UITestLocationProvider``.
///
/// Class-bound because a provider's hold count is state its callers share: a value-type conformer
/// would be copied into the existential, and the `stop()` that balances a `start()` would be counted
/// against a copy the other caller never sees.
protocol LocationProviding: AnyObject, Sendable {
  func start() async
  func stop() async
  func eventStream() async -> AsyncThrowingStream<LocationEvent, any Error>?
  func currentEvent() async -> LocationEvent?

  /// Asks Core Location to lift a reduced-accuracy limitation for the rest of the run. Does nothing
  /// for feeds Core Location does not gate.
  func requestFullAccuracy() async
}
