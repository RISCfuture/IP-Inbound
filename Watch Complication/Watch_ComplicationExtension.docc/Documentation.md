# ``Watch_ComplicationExtension``

The watch-face countdown to a run's time on target.

## Overview

A widget extension cannot hold a `WCSession`, so this target never hears from the iPhone. The watch
app receives the flown target and writes it to a shared App Group container; this extension reads it
back. The complication is therefore only as fresh as the last time the watch app ran, which is why
the phone also sends the payload as a complication transfer.

Because the time on target is briefed rather than inferred, the run-in window is exact. The provider
donates it as a scheduled relevance context, so the Smart Stack floats the countdown for the run-in
and leaves it alone the rest of the day.

## Topics

### Presentation

- ``Watch_ComplicationBundle``
- ``TOTComplication``

### Timeline

- ``TOTComplicationProvider``
- ``TOTEntry``
