import SwiftUI

private struct PreviewLocationKey: EnvironmentKey {
    static let defaultValue: LocationEvent? = nil
}

extension EnvironmentValues {
    var previewLocation: LocationEvent? {
        get { self[PreviewLocationKey.self] }
        set { self[PreviewLocationKey.self] = newValue }
    }
}
