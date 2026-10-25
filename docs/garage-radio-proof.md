# Garage and radio proof

The sample uses a separate S2000 `CarSpec` so the current production garage and
server car/rules versions are not silently migrated. `VisualProofScreen` starts
paused behind a painted wooden key box. Tapping its key set or pressing Enter
starts a 7.6-second directed departure (1.8 seconds with reduced motion). The
key pickup, retreat/turn, walk, door and cabin views use shared timing and atlas
cells. A foreground occlusion hides the camera-view exchange; this is a 2.5D
sequence, not a navigable 3D garage. The race clock remains paused until handoff.
The skip button starts driving immediately. Telemetry `start()` also bypasses
the intro for repeatable timing samples. Hidden lifecycle events during departure
lead to an explicit resume screen rather than starting a hidden race.

At handoff the proof starts at 110 arcade mph with auto acceleration, and opts
into the reactive traffic model. Reset repeats seed 731 and the same options.
The sample lasts 90 simulated seconds. It does not issue cloud run receipts or
change saved production unlocks. The model year 2001 and red sample paint are
working art choices, not a completed production car specification.

The radio director chooses short original script variants from actual supplied
weather, closure and traffic state. A closure report does not invent flooding
when only construction is known. Variant rotation prevents immediate repeats;
reset restores repeatable selection. Optional captions are controlled separately
and available even when speech fails. Current spoken performance is device TTS:
there is no guaranteed regional accent and no recorded voice bank in this proof.

Proof music has three original phrase/chord/arrangement families: synth-pop,
country-flavored electronic rhythm and heavier sawtooth/power-interval mountain
music. On station change the current arrangement cuts, a short tuning burst
plays, the report speaks, then the next arrangement starts. Notes run on the
Web Audio clock, not the renderer clock. Speech has a bounded timeout and errors
resume music; mute, pause and hidden tabs cancel pending reports. The engine
oscillator remains separate from the song nodes. Quiet key/door/cabin Foley can
play during the explicitly requested garage sequence while the race is paused,
and obeys mute and visibility. All audio starts through a user gesture.

These simple oscillator themes establish sequencing and rhythm variation. They
are not the finished instrument library, full soundtrack, regional vocal cast,
or proof of audible quality on a phone. Physical sensors/audio and moving art
need device review. Root owns final browser screenshots and performance evidence.

Verification: three new bridge tests cover report ordering/music suppression,
resuming after failure/cancellation, and muted garage cues; all 13 bridge tests
pass. Widget tests cover the paused cinematic, skip/handoff, cached game scene,
steering/brake independence, hidden lifecycle, timed completion and portrait
prompt. Script tests exercise condition precedence and deterministic anti-repeat.
The forge's Flutter wrapper only accepts the central checkout, so Flutter
analysis/widget checks run there after integration rather than in this sibling
worktree.
