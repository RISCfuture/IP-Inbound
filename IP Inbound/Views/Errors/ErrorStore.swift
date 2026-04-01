import Observation
import Sentry

@Observable
final class ErrorStore {
  var error: Error? {
    didSet {
      if let error, !(error is Errors) {
        SentrySDK.capture(error: error) { scope in
          scope.setTag(value: "user-facing", key: "visibility")
        }
      }
    }
  }
}
