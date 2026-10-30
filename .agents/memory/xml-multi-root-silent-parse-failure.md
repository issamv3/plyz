---
name: XML with two top-level elements silently defeats try/catch parsing
description: A stray element before/after the real root (e.g. a metadata tag pasted above the actual document root) makes strict XML parsers throw on the whole document — and if extraction/stripping code wraps the parse in try/catch, it fails silently instead of erroring loudly.
---

XML only allows exactly one root element. If a document has a second top-level element (e.g. `<Title>...</Title>` placed before `<MPD ...>...</MPD>` instead of nested inside it), that is a fatal well-formedness error. Dart's `xml` package (and Android's underlying `XmlPullParser`) both reject it outright with an exception.

**Why this matters:** code that does `try { XmlDocument.parse(x); ... } catch (_) { return x; }` for "best effort" extraction/cleanup will silently no-op on this input — the extraction returns null/nothing found, and any "strip this tag" step returns the original unmodified string, because the parse threw before either could reach the target element. The bug looks like "the feature doesn't recognize this tag" when the real cause is "the document was never valid XML to begin with."

**How to apply:** when writing tolerant read/strip logic for XML/manifest content that may come from copy-pasted real-world sources (browsers, logs, other apps), don't rely solely on `XmlDocument.parse` + try/catch for elements that might sit outside the real root. Add a targeted regex pre-pass (e.g. `RegExp(r'<Tag\b[^>]*>([\s\S]*?)<\/Tag>')`) to extract/remove the offending fragment *before* attempting full XML parsing, so the parser only ever sees a well-formed single-root document.
