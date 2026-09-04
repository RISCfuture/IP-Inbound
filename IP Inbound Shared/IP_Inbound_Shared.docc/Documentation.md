# ``IP_Inbound_Shared``

The run-in geometry, and the guidance both platforms fly it with.

## Overview

Everything the iPhone and the Apple Watch must agree about lives here: where the initial point sits
relative to the target, when the aircraft will reach each of them, how far it lies off the run-in
course, and which phase of the run that adds up to. Both apps solve the same geometry from their own
GPS, so their guidance cannot drift apart, and the Live Activity formats its readout with the same
styles the Fly screen uses.

The one thing the module deliberately does not know is where a target is stored. It reads
``GuidanceTarget``, which the iPhone's persisted model and the watch's wire-transmitted
``TargetSnapshot`` both conform to.

## Topics

### The target

- ``GuidanceTarget``
- ``TargetSnapshot``
- ``OffsetBearing``

### Solving the run

- ``IPTargetMath``
- ``FromToMath``
- ``GuidanceHelper``
- ``Guidance``
- ``CourseDeviation``
- ``TimingTier``

### Talking to the watch

- ``WatchTargetPayload``

### Location and background

- ``LocationDiagnostics``
- ``LocationImpediment``
- ``BackgroundActivityHolder``
- ``RunLocationUpdates``
