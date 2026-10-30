---
name: Accelerometer axis-to-orientation mapping is easy to get 180° backwards
description: When deriving DeviceOrientation from raw accelerometer x/y (sensors_plus), swapping landscapeLeft/landscapeRight (or portraitUp/portraitDown) produces an upside-down video/UI even though the code "runs fine" — no error, wrong orientation.
---

`landscapeLeft` and `landscapeRight` (and `portraitUp`/`portraitDown`) are each 180° apart. If a custom accelerometer-based rotation handler assigns `x > 0 ? landscapeRight : landscapeLeft`, the video can render upside-down after rotating, because the sign convention was inverted relative to what the accelerometer actually reports for that physical tilt.

**Why:** this class of bug is silent — the debounce/threshold logic all works, the orientation still changes on tilt, so it "looks correct" in code review; only physically rotating a device reveals the flip.

**How to apply:** when a user reports "rotates but comes out upside-down" for a custom sensor-orientation mapping, suspect the axis-to-enum sign mapping first (try swapping the two orientations tied to that axis) rather than the debounce/threshold logic. Also add a dominance-ratio check (e.g. `x.abs() > y.abs() * 1.6`, not just `>`) plus a longer debounce (~500ms) to fix "too sensitive/twitchy" rotation complaints in the same pass.
