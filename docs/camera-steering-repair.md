# Steering camera repair and rim finish

## Regression and correction

The prior chase implementation added a lateral look offset to the camera origin,
then mistakenly used that shifted origin to estimate the road tangent:
`(roadCenter(z+20)-shiftedCameraX)/20`. A small lateral offset therefore became a
false heading. Subtracting that heading times depth swung the whole visible road,
including the vanishing direction. Both keyboard and touch inputs exercised the
same faulty path. This was an implementation regression, not a control-tuning or
user-device problem.

`ProofRoadFrame` now derives heading solely from two road samples. The translated
camera origin remains separate. The maximum look fraction is reduced from.045 to
.018 road-half-widths. For a20-unit camera shift on a straight, the regression test
requires under12 pixels near the car and under1 pixel at20000 depth; curved
linear-road samples obey the same invariant. Camera translation must diminish
with depth rather than rotate the scene. Physical steering, collision geometry,
wide framing, terrain and traffic remain on their existing shared coordinates.

## Visible comparison and art

Optional edge effects begin earlier in the speed range and use longer, brighter
peripheral streaks and stronger edge shading. V or the utility toggles them;
`?proof=1&effects=on` starts enabled. The center stays clear, and reduced motion
suppresses the effect. This remains a perceptual comparison, not a claim that
adding blur guarantees speed sensation.

A new original [leather/stitched-metal rim](../assets/controls/PROMPTS.md) supplies
texture inside the approved side arcs. Annular mapping preserves the geometry
across aspect ratios. Art is low-alpha and never changes the touch targets,
neutral guard or independent central brake gesture. The native fallback remains
available if the texture fails. No real brand or stock wheel artwork is used.

This document corrects the implementation described by the previous
[rolling chase study](research/rolling-chase-suspension.md). Human touch reach,
comfort and challenge remain moving-review work; tests do not establish that a
new camera treatment is universally preferred.
