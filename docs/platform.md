# Browser controls and sound

The browser adapter is `web/platform_bridge.js`, loaded before Flutter bootstrap.
`lib/platform/browser_platform.dart` conditionally exports the real JS interop
adapter or a no-op Dart VM adapter, keeping simulation and widget tests independent
of browser APIs. `BrowserPlatform.instance` owns the single browser lifecycle.

## Input and lifecycle

Call `initialize` with steering, visibility and optional orientation/tilt-status
callbacks. Tilt is an optional gesture-initiated `enableTilt()` request; permission
denial, unsupported APIs, insecure origins and portrait viewports return false.
Permission alone does not enable steering: at least three valid readings over
250 ms calibrate a neutral pose, with an 1800 ms deadline. Hold the phone in its
comfortable landscape driving pose while enabling tilt. Flat-on-table readings
lack a gravity direction in the screen plane and cannot calibrate.

The implementation projects the world-up vector from beta/gamma into screen axes,
then measures screen roll. It compensates both landscape orientations, wraps
angular differences, clamps steering at 28 degrees and applies a small dead zone
and time-based smoothing. This calculation follows the coordinate-frame model in
the [W3C device orientation specification](https://www.w3.org/TR/orientation-event/).
Calibration and direction still require physical validation; numerical tests alone
cannot establish perceived control direction or comfort.

No valid sensor event for 1600 ms, screen rotation, hiding the tab or an explicit
`disableTilt()` resets steering and reports tilt disabled so touch remains usable.
Hiding/portrait also silences audio; root UI pauses simulation and requires an
explicit resume. `requestLandscape()` optionally requests fullscreen and an
orientation lock from a gesture. Failure preserves the rotate prompt. The
`reducedMotion` getter reads the browser preference; camera roll remains the
renderer’s independently damped presentation choice, with steady horizon available.

## Audio and radio

Call `beginAudio()` directly from Start/resume interaction, and `pause(false)`
when driving. `setAudioState(speed: ..., intensity: ..., region: ...)` takes
normalized 0–1 speed and intensity. The original score uses MIDI-numbered note
events rendered with Web Audio oscillators: bass, percussion, melody and sustained
harmony. Four original phrase/palette variants are selected deterministically by
region name; transitions occur at the next 16-step bar. Intensity changes the
arrangement and tempo. A filtered oscillator supplies speed-responsive engine
sound. Nodes are scheduled against the audio clock with short lookahead, following
the [Web Audio scheduling model](https://www.w3.org/TR/webaudio-1.1/).

This is a playable synthesized score, not Web MIDI hardware support, a complete
MIDI-file player, a licensed production sound bank or the final authored score.
No third-party music, samples or voices are bundled; all oscillator patterns in
the bridge were written for this project. Production score/bank review remains
OpenSpec task 5.2.

`muted` and `pause(true)` silence all sound and cancel pending speech. `say(text)`
uses available browser speech voices, checks for voices loaded later, and lets the
newest state-derived instruction replace an old one. The game supplies caption
text independently and should prioritize which instructions it sends. Speech is
bounded to 320 characters and cancelled after 12 seconds. Missing APIs, blocked
audio and TTS errors do not block play. A curated prerecorded/cached voice library
is still required for the production audio specification; caption fallback is
implemented now. Browser voice availability, accent and latency are not controlled.

## Google button

`renderGoogleButton(element, clientId, nonce, credential, error)` accepts the
`web.HTMLElement` from `HtmlElementView.fromTagName`. It lazily loads Google's
supported external GIS script and renders the official branded button with a
nonce and popup callback, using the [official GIS JavaScript API](https://developers.google.com/identity/gsi/web/reference/js-reference).
The app fetches config and a browser-bound challenge from the same-origin API,
then submits the returned credential to that API for verification. The bridge
never stores credentials or changes account progress. It reports missing config
and script/network errors. Google account cancellation may leave the button
available without a callback; closing the profile remains possible.

Register the exact Cannonball origin on the configured public client and verify
real popup/FedCM sign-in separately. Mocked button tests do not prove registration,
OAuth access, cookie policy or live deployment. If adding a Content-Security-Policy,
allow the Google GIS script/frame/connect endpoints per Google's integration guide;
the bridge injects only the official external script, never inline script text.

## Checks and outstanding physical trials

Run `node --test web/platform_bridge.test.mjs` for deterministic bridge checks:
landscape math, calibration, permission denial, absent/stalled events, a cancelled
permission race, lifecycle notifications, audio/speech failure, pause/mute and
Google button/load failure. Run `flutter analyze lib/platform` for Dart interop.

Still validate on actual Safari/iPhone and Chrome/Android: HTTPS permission from
the real touch gesture; both landscape directions; calibration while comfortably
holding the device; touch takeover; screen lock support; interruption/resume;
Bluetooth and device mute behavior; delayed or absent TTS voices; sustained music
and region changes; official Google popup/FedCM; and camera direction/comfort with
steady horizon. No such physical-device or live Google checks are claimed here.
