# ``IP_Inbound_Watch``

The watchOS companion: the run-in CDI and countdown on the wrist.

## Overview

The watch app has no setup of its own. The phone pushes the active run over
`WatchConnectivity` as a ``WatchTargetPayload``, and the watch renders the same guidance the
phone shows — course deviation, distance and bearing to the next point, and the countdown to
time on target — using its own location fix.

## Topics

### Screens

- ``WatchRootView``
- ``WatchGuidanceView``
- ``WatchCDIView``
- ``WatchCountdownView``
- ``WatchPlaceholderView``

### Models

- ``WatchConnectivityModel``
- ``WatchLocationModel``
- ``WatchTargetPayload``
