---
name: Loopback manifest/local server URLs are session-scoped, not durable
description: Any http://127.0.0.1:<port>/... URL from an in-process loopback server should never be persisted and reused across app sessions or screen instances — republish fresh on every use.
---

When a feature spins up a loopback HTTP server (e.g. to serve pasted-in XML/JSON content to a native player that requires a real http(s) URI), the resulting `http://127.0.0.1:<port>/...` URL is only valid for the lifetime of that specific server instance/port. If that URL gets persisted (e.g. into a history/resume record) and the server is torn down when the consuming screen closes — a reasonable thing to do to avoid leaking sockets — resuming later from the persisted URL hits a dead port and fails with an opaque, low-level connection/source error rather than a clear "expired" message.

**Why:** this bug is easy to miss because it only reproduces on the *second* open of the same content (e.g. history resume, or switching back to a previous state), not on first use — first use always publishes right before consuming, so it looks correct in the common manual test path.

**How to apply:** never trust a stored loopback URL as still-live. Keep the original raw content (not just the derived loopback URL) alongside any persisted reference, and republish it fresh through the loopback server every time that screen/flow is entered — treat the loopback URL as a derived, session-scoped value, not a stable identifier.
