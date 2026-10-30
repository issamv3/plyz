---
name: ffmpeg-kit https flavor bloats APK far beyond 20MB even with abiFilters
description: Why the https/full ffmpeg-kit flavor produces a 100MB+ APK even single-ABI, and how downloading via Dart's http client first lets you use the min flavor instead.
---

`ffmpeg_kit_flutter_new_https` bundles a full network stack (OpenSSL/GnuTLS + http/https/tls/tcp protocol handlers) into the native `.so`, which dominates APK size even after `abiFilters` restricts the build to a single ABI — restricting ABIs does not shrink the per-ABI library itself.

**Why:** the app only ever does `-c copy` remuxing (no transcoding), so the heavy protocol/TLS layer inside ffmpeg was pure overhead — it was only needed because ffmpeg was fed remote `https://` URLs directly.

**How to apply:** when the ffmpeg usage is pure local-file remux/mux (`-c copy`), download the source file(s) to local temp paths first using Dart's own `http` package (respecting any CDN-specific headers), then invoke ffmpeg only on local `file` paths. This removes the need for network protocols or TLS inside ffmpeg entirely, so the `min` flavor (`ffmpeg_kit_flutter_new_min`) can replace `https`/`full`, cutting the native library size drastically. Progress reporting must move from ffmpeg's statistics callback (which tracked encode/remux time) to tracking bytes-received during the manual download instead.
