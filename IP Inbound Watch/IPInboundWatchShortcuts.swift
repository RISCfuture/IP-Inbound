import AppIntents

/// The phrases that reach IP Inbound on the Apple Watch. The watch only ever holds the target it is
/// flying, so asking after that run is all it offers.
struct IPInboundWatchShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: TimeOnTargetIntent(),
      phrases: [
        "Time on target in \(.applicationName)",
        "How long to time on target in \(.applicationName)"
      ],
      shortTitle: "Time on Target",
      systemImageName: "clock"
    )
  }
}
