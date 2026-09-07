# Changelog

Release notes for IP Inbound. A version heading is `## <version>`, matching the
tag exactly, and it is what `Scripts/release-notes.sh` reads and what the Release
workflow writes into App Store Connect's "What's New".

Write the entries to survive both renderings. This file is read as Markdown here
and as plain text on the store, where the field shows whatever it is given
verbatim: a line that only makes sense with its formatting will read badly in one
of the two places.

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
