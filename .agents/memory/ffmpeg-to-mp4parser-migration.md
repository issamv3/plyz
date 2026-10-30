---
name: Replacing ffmpeg with MP4Parser for mp4 muxing on Android
description: What MP4Parser can and cannot replace when removing ffmpeg from an Android video app, and the ProGuard pitfall it introduces.
---

MP4Parser (Maven Central group `org.mp4parser`, artifacts `muxer` + `isoparser`) is a pure-Java remuxer: it can combine an already-encoded video-only track and audio-only track into one `.mp4` container (`Movie`/`Track`/`MovieCreator`/`DefaultMp4Builder`) with no transcoding and no native/NDK libraries — a good ffmpeg replacement for "download + merge DASH streams with `-c copy`" style use cases, and it shrinks APK size dramatically since ffmpeg-kit's native `.so` libs (per-ABI, often 10-50MB) go away entirely.

**What it cannot do:** MP4Parser cannot decode/render video frames, so it cannot replace ffmpeg's frame-extraction-for-thumbnail use case. On Android, that gap is filled for free by the built-in `android.media.MediaMetadataRetriever` (`getFrameAtTime` + `Bitmap.createScaledBitmap` + JPEG compress) — no extra dependency needed, since it ships in the Android SDK itself.

**ProGuard/R8 pitfall:** MP4Parser resolves ISO-BMFF box classes via reflection (a bundled properties file mapping fourcc → class name), so without explicit keep rules R8 will strip/rename box classes on minified release builds and muxing will throw at runtime. Always pair the dependency with `-keep class org.mp4parser.** { *; }` (+ `-keepclassmembers` and `-dontwarn`) in `proguard-rules.pro`.

**How to apply:** when a Flutter/Android app only needs the app to *remux* pre-encoded segments (never transcode/filter/decode), expose the muxer via a small custom `MethodChannel` from Kotlin (no existing pub.dev plugin wraps MP4Parser) rather than pulling in a heavy ffmpeg plugin.
