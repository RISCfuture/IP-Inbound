import SwiftUI

/// Keeps the location stream running for the lifetime of the modified view without gating on a fix.
/// Use where the UI benefits from a *warm* location — so one is already in hand by the time a screen
/// further on asks for it — but must stay fully usable when there is none. Views that consume the
/// live stream and require a fix use ``NeedsLocationView`` instead.
///
/// Never apply it to a window's root view. A root never disappears, so its hold is never released
/// and the airborne configuration Core Location is asked for runs from launch to termination; the
/// authorization prompt goes up at launch, too, rather than when the pilot engages with a run.
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
