# ``IP_Inbound``

Guidance for flying an initial-point-to-target run to a precise time on target.

## Overview

Given a target coordinate, an IP bearing and distance, a run-in ground speed, and a desired time
on target, the app plans the run and then flies it: a countdown to TOT on the ground, lateral
guidance and an IP exit countdown before the IP, and a CDI with a speed correction on the run
itself. Afterwards it reports how many seconds early or late the pass was.

The geometry underneath all of that lives in `IP_Inbound_Shared`, which the watch app flies from
too.

## Topics

### Setting up a run

- ``SetupFlowView``
- ``TargetSetupView``
- ``IPSetupView``
- ``TOTSetupView``
- ``Target``

### Flying the run

- ``FlyView``
- ``GuidanceContentView``
- ``CDIView``
- ``TimingView``
- ``PostPassView``

### Location and companions

- ``LocationStreamer``
- ``LiveActivityController``
- ``WatchSessionController``
