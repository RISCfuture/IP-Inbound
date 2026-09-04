import Foundation

/// Anchors ``Foundation/Bundle/guidance`` to this framework rather than to whichever app loaded it.
private final class BundleToken {}

extension Bundle {
  /// The framework's own bundle, which is where its localized strings live.
  ///
  /// A string written in a framework resolves against `Bundle.main` unless it is told otherwise, and
  /// `Bundle.main` is whatever loaded the framework — the iPhone app, the watch app, or a widget
  /// extension. None of them carries these strings, so without this the guidance would fall back to
  /// its own keys and no translation would ever reach it.
  static let guidance = Bundle(for: BundleToken.self)
}
