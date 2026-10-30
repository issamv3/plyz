---
name: SharedPreferences JSON list pattern for local "library" data
description: Reusable pattern for any locally-persisted list of records (history, downloads, favorites, etc.) that doesn't need a real database — one JSON-encoded list under a single SharedPreferences key.
---

For small-to-medium local lists (tens to low hundreds of records) that don't warrant a full database, store them as a single JSON-encoded array under one versioned SharedPreferences key (e.g. `download_library_v1`).

Shape of the service:
- `loadAll()` — read the key, `jsonDecode` into a list, map each entry through a `Model.fromJson` factory, sort by recency, and return `[]` on missing/corrupt data instead of throwing.
- `_saveAll(list)` — sort, `jsonEncode`, write back to the same key.
- `add(record)` — load, remove any existing entry with the same id (upsert semantics), append, save.
- `remove(id)` — load, filter out by id, save.
- `clear()` — remove the key outright.

**Why:** this mirrors an existing pattern already used elsewhere in the app (history) and keeps read/write logic trivial and consistent — no schema migrations, no native DB dependency, and safe-by-default parsing (`as Type? ?? fallback` per field) means older/partial JSON from a previous app version won't crash the list.

**How to apply:** whenever adding a new kind of locally-tracked list (e.g. a downloads library), copy this shape rather than reaching for sqlite/drift/hive unless the data volume or query needs actually require it.
