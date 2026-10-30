---
name: SystemChrome auto-rotate tricks still obey the OS rotation lock on some devices
description: Neither an empty orientation list (UNSPECIFIED) nor the FULL_SENSOR trick (all 4 orientations) reliably overrides the phone's system-level rotation lock on every device/ROM — a manual accelerometer listener that forces one explicit orientation is the approach that actually works everywhere.
---

`SystemChrome.setPreferredOrientations([])` on Android maps to `ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED`, which still defers to the phone's system-level auto-rotate/rotation-lock setting.

The "fix" of passing all four orientations (`[portraitUp, portraitDown, landscapeLeft, landscapeRight]`, mapping to `SCREEN_ORIENTATION_FULL_SENSOR`) is commonly recommended and does override the system lock on many devices — but not universally; on at least one real device/ROM combination it was still gated by the OS rotation-lock toggle.

**Why:** these tricks look correctly wired (toggle persists, code runs, no errors) yet still get reported as "doesn't work," because the failure is device/ROM-specific and won't reproduce on every test device.

**How to apply:** for auto-rotate behavior that must work regardless of the system lock (e.g. an in-player rotate button like YouTube's), don't rely on `FULL_SENSOR`/empty-list tricks alone. Instead, listen to the raw accelerometer (`sensors_plus`), compute the device's actual physical orientation from gravity x/y with a small hysteresis/debounce to avoid jitter, and call `setPreferredOrientations([singleExplicitOrientation])` with exactly one orientation — a request for one specific orientation is honored unconditionally by Android regardless of the rotation-lock setting. Start/stop the sensor listener alongside the auto-rotate toggle and manual fullscreen mode to avoid fighting user-initiated orientation changes.
