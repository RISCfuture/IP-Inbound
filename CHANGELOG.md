# Changelog

Release notes for IP Inbound. A version heading is `## <version>`, matching the
tag exactly, and it is what `Scripts/release-notes.sh` reads and what the Release
workflow writes into App Store Connect's "What's New".

Write the entries to survive both renderings. This file is read as Markdown here
and as plain text on the store, where the field shows whatever it is given
verbatim: a line that only makes sense with its formatting will read badly in one
of the two places.

## 3.0

IP Inbound now requires iOS 27 and watchOS 27. If your iPhone or Apple Watch is
on an older version, the App Store will keep offering you 2.1.0 and it will go
on working — but this is where new versions stop until you update.

- With your iPhone in landscape, the Dynamic Island shows your run as a target
  symbol and a ring that runs down to your time on target.
- Siri and Shortcuts: ask Siri “Time on target in IP Inbound” to hear how long
  you have, or “End the run in IP Inbound” when you’re done. Each of your
  targets also appears as a shortcut in the Shortcuts app, which opens its Fly
  screen. On Apple Watch, ask Siri how long it is to your time on target.
- Your targets turn up in Spotlight: search for one by name to open it.
- The number pad for an IP’s bearing, offset and ground speed has a Done button,
  so you can put the keyboard away without scrolling or tapping elsewhere.

## 2.1.0

### Apple Watch

- A new complication puts the countdown to your time on target right on the watch
  face.
- The watch runs its own Live Activity, so guidance keeps running while your wrist
  is down.
- The watch now follows the run: a countdown before you are moving, course
  guidance once you are, and a pass-flown screen after.

### Runs that stay alive

- Guidance keeps running while IP Inbound is in the background, and a run survives
  a relaunch — you land back on the target you were flying.
- The countdown is armed when you brief a time on target, rather than when you
  reach the Fly screen.
- The Lock Screen now carries your run-in figures.

### Everywhere else

- When there is no fix, IP Inbound says why and offers the remedy — opening
  Settings, or turning precise location back on.
- Adding a target opens it straight away; your present position fills in behind
  you.
- Run-in distance is shown in your own units.
- A run that lapses short of the target no longer reports a miss it never flew.
