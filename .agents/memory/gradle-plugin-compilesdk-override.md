---
name: Forcing compileSdk on Flutter plugin subprojects from the root build.gradle
description: How to safely override a stale/low compileSdk baked into a Flutter plugin's own android/build.gradle (causing checkReleaseAarMetadata failures), without hitting "already evaluated" or having the override silently overwritten.
---

Flutter plugins are built as included Gradle source modules (not prebuilt AARs), so a plugin with a hardcoded old `compileSdk` (e.g. 31) in its own `android/build.gradle` can be overridden from the root `android/build.gradle.kts` — but two traps make naive attempts silently fail or crash:

1. `subprojects { afterEvaluate { ... } }` can throw "Cannot run Project.afterEvaluate(Action) when the project is already evaluated" if another subproject's `evaluationDependsOn(":app")` (or similar) has already forced eager evaluation of some subprojects by the time this block runs.
2. `subprojects { pluginManager.withPlugin("com.android.library") { extensions.configure<LibraryExtension> { compileSdk = X } } }` looks correct but silently has **no effect** — `withPlugin` fires the instant `apply plugin` runs, which is at the *top* of the plugin's own build.gradle; that same script's own `android { compileSdkVersion 31 }` line further down runs afterward in the same script and overwrites the override.

**Why:** both are execution-order bugs in Gradle's configuration lifecycle, not classpath/API problems — the code compiles and runs without error either way, so the symptom (same unchanged error every time) is easy to misread as "the fix isn't being picked up" (e.g. stale repo) rather than an ordering bug.

**How to apply:** inside the `withPlugin` callback, check `if (state.executed) { setDirectly() } else { afterEvaluate { setDirectly() } }` — this guarantees the override always runs after the subproject's own script body has finished, whether or not that subproject was already eagerly evaluated by another module's `evaluationDependsOn`.

Also scope the override to `if (project.name == "the-specific-plugin")` rather than applying it to every `com.android.library` subproject. NDK/native-build plugins (e.g. ffmpeg-kit wrappers) read `compileSdk` eagerly during their own evaluation to configure the native build, and fail with "It is too late to set compileSdk — it has already been read" if a blanket root-level override touches them too, even though they never had the original problem.

**Update for AGP 9.x:** even the scoped `afterEvaluate` override eventually fails with the same "too late to set compileSdk — it has already been read" error, on the *target* plugin itself, not just NDK ones. AGP 9's new Variant API architecture locks `compileSdk` earlier in the lifecycle than `afterEvaluate` fires, so no `afterEvaluate`-based approach is reliable anymore. (Note: if a build error seems to disappear after narrowing the scope of a fix, verify it wasn't actually because Gradle aborted on an earlier-evaluated, alphabetically-preceding subproject before ever reaching the "fixed" one — order of subproject evaluation is often alphabetical, so "no more error" isn't proof of a fix.)

The correct AGP 9-safe mechanism is the Variant API's `finalizeDsl` hook, which the AGP error message itself points to ("...or using the variant API"):
```kotlin
pluginManager.withPlugin("com.android.library") {
    val androidComponents = extensions.getByType(com.android.build.api.variant.LibraryAndroidComponentsExtension::class.java)
    androidComponents.finalizeDsl { extension -> extension.compileSdk = 36 }
}
```
`finalizeDsl` runs at the one well-defined point guaranteed to be after the subproject's own DSL configuration and before AGP consumes it to create variants — sidestepping both the "overwritten by later script line" and "too late, already read" failure modes.

**Confirmed working (2026-07-06):** the universal `finalizeDsl` + `if (currentCompileSdk == null || currentCompileSdk < 36)` approach on all `com.android.library` subprojects resolved the build for this project — this is the settled, durable pattern for this class of problem.

**This is a systemic problem, not a single-plugin one:** many community Flutter plugins bundle a stale hardcoded `compileSdk` (seen with `flutter_volume_controller`, `screen_brightness_android`, etc.), so fixing one at a time is whack-a-mole — the next build just surfaces the next offending plugin. Once `finalizeDsl` is confirmed to work, apply it universally to every `com.android.library` subproject rather than name-scoping it, guarded by `if (currentCompileSdk == null || currentCompileSdk < 36) { extension.compileSdk = 36 }` so it only raises (never lowers) stale values and is a no-op for already-modern plugins (e.g. NDK-based ones like ffmpeg-kit, which don't need it and shouldn't be touched unnecessarily).
