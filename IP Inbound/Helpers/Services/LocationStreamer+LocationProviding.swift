import Foundation

extension LocationStreamer: LocationProviding {
  func eventStream() async -> AsyncThrowingStream<LocationEvent, any Error>? {
    await producer?.consume()
  }
}
