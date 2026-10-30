---
name: Android edge-swipe-to-go-back silently fails without a manifest flag
description: Flutter app on Android where CupertinoPageRoute is used everywhere (for iOS-style swipe-back), but pages only go back via a button/AppBar, never a swipe — even on screens with no competing GestureDetector.
---

`CupertinoPageRoute`'s pop gesture detector has no platform check — it registers on Android too, so in theory it should give swipe-to-go-back everywhere. If it doesn't work on *any* page (not just ones with custom gesture handling), the cause is almost always missing predictive-back support in `AndroidManifest.xml`, not a bug in Flutter's route or app code.

On Android 13+ with gesture navigation enabled, the OS intercepts the edge swipe for its own predictive-back animation before delivering a real back event to the Activity, unless the app opts in with `android:enableOnBackInvokedCallback="true"` on the `<application>` tag. Without it, the edge swipe either does nothing useful or exits/backgrounds the app instead of popping the Flutter `Navigator`.

**Why:** this is easy to misdiagnose as a Flutter-side gesture-arena conflict (e.g. blaming a full-screen `GestureDetector`) when the real fix is a one-line manifest attribute — a targeted fix (custom edge-swipe pan handler) on one screen won't fix the other screens that have no such conflict at all.

**How to apply:** when a Flutter/Android app's swipe-back "only works with the button," check `AndroidManifest.xml` for `android:enableOnBackInvokedCallback="true"` before adding custom gesture-detection code. Add it if missing; combine with `PopScope`/`CupertinoPageRoute` as normal.

**Custom pan-based back gesture on a screen with its own full-screen `GestureDetector`** (e.g. a video player also handling volume/brightness/seek drags) stays fragile even after the manifest flag is set:
- A hardcoded small edge-detection width (e.g. 24 logical px) is too thin for real fingers to reliably land in; scale it to screen width with a sane minimum (e.g. `max(32, width * 0.12)`).
- Also wrap that screen's root widget in `PopScope(canPop: true, ...)` as a safety net — it guarantees the OS back button/predictive-back gesture still pops the route even if the custom pixel-based pan detection misses, independent of the manual `GestureDetector` logic.
- In an RTL (Arabic) app, remember `Directionality.of(context)` flips which physical edge counts as "leading" — the flip itself is usually correct/expected, not the bug; look first at the edge-zone width and direction-lock ratio (dx vs dy) before suspecting RTL logic.
- User expectation for "swipe from anywhere" was literally "نص الشاشة" (half the screen), not the whole screen — treat that phrase as "start zone = 50% of width", not as "remove the start-zone check entirely" (removing it fully would hijack the coexisting horizontal seek/scrub gesture).
