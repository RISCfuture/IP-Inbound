import SwiftUI

private let defaultErrorStore = ErrorStore()

extension EnvironmentValues {
  @Entry var errorStore = defaultErrorStore
}
