# ``Live_ActivityExtension``

The Live Activity and Dynamic Island presentation of a run's time on target.

## Overview

The app starts and ends the activity; this extension only renders it. Both refer to the same
``TOTActivityAttributes``, which is how ActivityKit matches a running activity to its
presentation, so the type is defined in the app sources and picked up here through target
membership.

## Topics

### Presentation

- ``Live_ActivityBundle``
- ``TOTLiveActivity``
- ``TOTActivityAttributes``
