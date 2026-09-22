import AppIntents

/// The phrases that reach IP Inbound on the iPhone without setting anything up in Shortcuts first.
struct IPInboundShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: FlyTargetIntent(),
      phrases: [
        "Fly \(\.$target) in \(.applicationName)",
        "Fly a target in \(.applicationName)"
      ],
      shortTitle: "Fly Target",
      systemImageName: "scope"
    )
    AppShortcut(
      intent: TimeOnTargetIntent(),
      phrases: [
        "Time on target in \(.applicationName)",
        "How long to time on target in \(.applicationName)"
      ],
      shortTitle: "Time on Target",
      systemImageName: "clock"
    )
    AppShortcut(
      intent: EndRunIntent(),
      phrases: [
        "End the run in \(.applicationName)",
        "Stop the run in \(.applicationName)"
      ],
      shortTitle: "End Run",
      systemImageName: "xmark.circle"
    )
  }
}
