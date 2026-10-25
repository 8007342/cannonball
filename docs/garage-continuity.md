# Departure continuity: directed 2.5D sample

The prior keybox, garage wall and exterior paintings are retained. This revision
addresses a single sliding hand image, an opaque full-screen wipe, stretched
square cabin art and the black-to-driving cut. It is a directed illustration
sequence, not a freely moving 3D camera or a finished character rig.

## Research and application

Dominic Cianciolo's primary [NetherRealm GDC 2011 presentation](https://media.gdcvault.com/gdceurope2011/slides/Dominic_Cianciolo_VisualArts_TheCinematicsOf.pdf)
frames cinematography around composition, character blocking, focal length,
movement and editorial timing/rhythm (slides 10–20). It does not prescribe an
arcade-racing transition. Our application is to preserve subject direction,
proportions and screen position through a short series of motivated cuts rather
than treating any fade as sufficient continuity.

The [Web Audio recommendation](https://www.w3.org/TR/webaudio-1.0/#AudioScheduledSourceNode)
defines source scheduling against the audio context timeline. Its
[AudioParam automation](https://www.w3.org/TR/webaudio-1.0/#AudioParam)
provides timed pitch and gain envelopes. The starter/rev prelap therefore uses
scheduled short oscillators, independent of frame cadence. This is an original
synthesized engine sketch, not a recording of a real S2000.

## Picture timeline

The normal 7.6-second sequence remains compatible with the existing caller. A
reduced-motion version uses 1.8 seconds, suppresses camera translation and walk
sway, and retains the same semantic beats.

- Reach, pinch/grasp and withdrawal use the new hand atlas's first four cells.
  The separate hanging key disappears only as the grasp frame takes ownership.
- A continuous leftward pan moves the wall right as the doorway enters from the
  left. There is no full-screen opaque post wipe. The dark painting edges form
  a directed transition; exact physical garage geometry is still illustrative.
- The exterior approach has restrained translation/scale and a low walking sway.
- The door insert stays square and rotates gently. The new wide cabin painting
  always uses aspect-preserving cover/crop, never viewport stretching.
- Cabin and garage layers clear to the already loaded live scene. A rear sprite
  settles toward the chase composition and the final overlay becomes transparent.
  No all-black final frame is introduced. The race remains paused until the
  caller's completion handoff; a skip still completes immediately.

Source image coordinates and pixel proportions remain constant as the viewport
changes. The first-pass hand attachment/contact alignment and pan seam still need
moving review; they are not claimed to be final animation approval.

## Sound and integration

`onShot` emits reach, grasp, pickup, reveal, walk, door, cabin, rear and launch.
The caller should trigger the key jingle on grasp instead of immediately on tap;
route door/cabin/rear/launch through the existing `garageCue` API. Cabin begins a
short starter sequence; rear adds idle; launch pitches into the driving engine.

Garage sounds have a separate bounded node set from music. A station break can
stop song nodes without truncating the ignition handoff. Muting, hiding, pausing
or disposing explicitly stops those garage nodes. Duplicate shot notifications
within 250ms are ignored. This small bus intentionally bypasses the gameplay
pause gain during the requested cinematic, while honoring mute/visibility.

The static hand and cabin images are generated source assets copied into the
project by root; their prompts/provenance live under `assets/milestone`.

## Checks

`departure_continuity_test.dart` covers the hand beat order, transparent handoff,
single completion and cabin fit mode. Central Flutter execution is required
because this forge mounts its Flutter runtime only at the root checkout.
`web/platform_bridge.test.mjs` adds two audio tests for bounded schedules,
duplicate shots and cancellation; all 15 bridge tests passed in this worktree.
Headless scheduling tests cannot establish audible quality or physical-phone
comfort. Root performs the integrated moving review and release build.
