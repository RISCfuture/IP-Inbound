# IP Inbound

An application that helps pilots fly an IP-to-target run to an accurate time on
target. This application is useful for formation demo pilots, or pilots who
participate in simulated tactical events, and need to be over a target at a
precise time.

## The Problem

Maybe you are lead of a formation flight over a ceremony and you have specific
time on target (TOT), or you are being tested on your ability to put a flour
bomb on a mock target at a precise moment. In either case, you are likely given
three pieces of information:

1. Your target location
2. A desired time on target
3. An initial point (IP) or run-in direction

Your job is to select a run-in speed, and plan your arrival over the IP so that
you arrive over the target at TOT. For flights that must coordinate with a band
or pyrotechnics display on the ground, or for aircraft that are being tested on
their timing, seconds matter.

## The Solution

This iOS application allows you to select or enter a precise target coordinate,
choose an IP bearing and distance, and a desired ground speed, and then enter
your TOT. It then provides you with useful information during each phase of your
flight:

**On the ground**, it shows you a countdown to your TOT for takeoff planning.

**Airborne, pre-IP**, it provides you with lateral guidance to the IP, and a
countdown for when you must exit the IP to make your TOT. It will also
automatically provide you with direct-to-target guidance if it calculates that
you must skip your IP in order to make your TOT.

**Airborne, post-IP** it provides you with lateral guidance for the IP-to-target
run, and tells you to speed up or slow down to meet your TOT.

The app automatically includes turning time in its calculations: For example, if
you are running very early and opt to make a 360 or an S-turn during the
IP-to-target run, it will include the time needed to complete the turn in its
estimated-time-of-arrival (ETA) calculations, and airspeed guidance.

## How to Use

The initial app screen includes a link to a tutorial that will show you how to
use the app in two typical scenarios: flying a route to a target, and flying a
hold over an IP to a target.

## Requirements

This app is written in Swift 6 and targets iOS 18.

## Development

The "IP Inbound" target is the application, which can be compiled and run on any
iOS device. The "Generate Screenshots" target generates screenshots for the
App Store.

Bugsnag is included for exception reporting.
