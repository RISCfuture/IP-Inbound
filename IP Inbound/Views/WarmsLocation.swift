import SwiftUI

/// Keeps the location stream running for the lifetime of the modified view without gating on a fix.
/// Use where the UI benefits from a *warm* location — so a present-position seed or map centering is
/// available when one exists — but must stay fully usable when it doesn't. Views that consume the
/// live stream and require a fix use ``NeedsLocationView`` instead.
private struct WarmsLocation: ViewModifier {
  @Environment(\.services)
  private var services

  func body(content: Content) -> some View {
    content
      .task { await services.location.start() }
      .onDisappear {
        let provider = services.location
        Task { await provider.stop() }
      }
  }
}

extension View {
  /// Warms the location stream for this view's lifetime without gating on a fix. See `WarmsLocation`.
  func warmsLocation() -> some View {
    modifier(WarmsLocation())
  }
}
