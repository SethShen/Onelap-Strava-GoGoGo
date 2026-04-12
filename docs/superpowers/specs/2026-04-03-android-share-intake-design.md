# Design: Android Share Intake Coverage

**Date:** 2026-04-03  
**Status:** Draft  
**Scope:** Broaden Android file intake entrypoints so WanSync appears in more system share/open flows, while moving FIT validation fully into the app.

## Goal

Make the Android app appear as a target for as many system-level file transfer flows as practical when another app sends or opens a file, including cases where the sender uses generic MIME types or non-FIT-specific APIs.

The app should no longer depend on Android intent filters that advertise only FIT MIME types or FIT filename patterns. Instead, Android should accept generic file handoff intents, and the app should decide internally whether the received file is a FIT file.

If the received file is not a FIT file, the app should show a user-visible error instead of opening the share confirmation flow.

For cold-start intake, that means the app starts normally, remains on the home screen, and shows the prompt there. For warm-start intake while the user is already elsewhere in the app, that means staying on the current screen and showing the prompt without forced navigation.

## Current State

The current Android integration already has a native intake pipeline:

- `android/app/src/main/AndroidManifest.xml` registers `SEND` and `VIEW` filters.
- `MainActivity.kt` reads incoming intents and forwards either a draft payload or an error payload to Flutter.
- `SharedFitIntentUriExtractor.kt` extracts a single URI from `EXTRA_STREAM`, `ClipData`, and `intent.data`.
- `SharedFitIntentValidator.kt` validates the file primarily from MIME type and filename.

The current limitations are:

- the manifest advertises only FIT-specific MIME types or `.fit` path patterns,
- the native action gate accepts only `Intent.ACTION_SEND` and `Intent.ACTION_VIEW`,
- some apps that use other standard handoff flows do not show WanSync in the chooser,
- non-FIT rejection messaging is native-first but the desired UX is to stay on the home screen with a visible prompt.

## Chosen Approach

Broaden Android intake in three layers:

1. expand manifest intent filters to generic file-oriented system actions and `*/*`,
2. expand native intent parsing so those actions all route through the existing share intake pipeline,
3. move FIT acceptance entirely to app-side validation, including file-content fallback checks when name and MIME type are unreliable.

This keeps the current architecture intact while removing the system-level FIT assumptions that prevent the app from appearing in some chooser/open flows.

## Why This Approach

- It directly addresses the known symptom: the app is missing from chooser targets for some apps.
- It avoids adding a new Android activity or a second intake architecture.
- It preserves the current Flutter-side event model with targeted behavior changes only where needed.
- It is compatible with content URIs, file URIs, generic MIME types, and providers that do not expose a stable display name.

## Alternatives Considered

### 1. Add only one or two missing actions

Rejected because it would likely fix only a subset of apps and leave the project in a repeated patch cycle as more sender behaviors are discovered.

### 2. Keep FIT-only manifest filters and just loosen native validation

Rejected because the current failure begins before app code runs: the app is not always shown as a candidate in the Android system chooser.

### 3. Add a dedicated native share trampoline activity

Rejected because the project already has a working single-activity intake path and a separate trampoline would increase complexity without solving the core discoverability issue better than broader filters.

## Execution Design

### Manifest Coverage

Update `android/app/src/main/AndroidManifest.xml` so `MainActivity` advertises broader file handoff support.

Actions to support:

- `android.intent.action.SEND`
- `android.intent.action.SEND_MULTIPLE`
- `android.intent.action.VIEW`

Categories:

- keep `android.intent.category.DEFAULT` for all relevant file intake filters,
- keep `android.intent.category.BROWSABLE` for actions that may come from external open flows.

Data matching:

- accept `content` and `file` schemes where scheme matching is used,
- use `*/*` rather than FIT-specific MIME types,
- remove FIT-specific path restrictions such as `.fit` / `.FIT` path patterns.

The manifest should be broad enough to maximize discoverability.

Because Android intent filters cannot require `EXTRA_STREAM`, registering `ACTION_SEND` with `*/*` will also make WanSync appear for some non-file shares such as generic text sends. That extra chooser noise is an accepted trade-off for this task because the requirement is to prioritize discoverability across sender implementations and reject unsupported input inside the app.

### Native Intent Acceptance

Update `MainActivity.isSupportedShareAction` so it accepts the same family of file-transfer actions registered in the manifest.

`SharedFitIntentItemSelector` should support action-specific URI selection for:

- `SEND`
- `SEND_MULTIPLE`
- `VIEW`

URI extraction priorities should remain centered on the existing three Android sources:

- `Intent.EXTRA_STREAM`
- `ClipData`
- `intent.data`

For `ACTION_SEND_MULTIPLE`, extraction must also read the standard `EXTRA_STREAM` `ArrayList<Uri>` form, because some senders provide multiple items there instead of `ClipData`.

The selector should normalize these sources into a deduplicated candidate URI list.

The single-file constraint should be enforced after normalization so the same underlying URI delivered through both `intent.data` and `ClipData`, or repeated by a sender, is treated as one candidate file rather than a false multi-file share.

### FIT Validation

Android should accept any file handoff at the manifest layer, but the app should still only proceed with actual FIT files.

Validation should happen after a candidate URI is identified and before a draft payload is emitted to Flutter.

Validation order:

1. require exactly one normalized candidate URI,
2. if MIME type is a known FIT type, accept it,
3. otherwise inspect display name and URI tail for a `.fit` suffix,
4. if the name is inconclusive, copy the file to cache and inspect the content header for a FIT signature,
5. if still not recognized as FIT, emit an error payload instead of a draft payload.

This design intentionally uses content inspection as a fallback because many Android providers expose generic MIME types, opaque names, or both.

For this task, the FIT signature check should be explicit and minimal:

- read at least the first 12 bytes of the copied file,
- require the FIT header size byte at offset `0` to be `12` or `14`,
- require bytes `8..11` to equal ASCII `.FIT`.

If the file is shorter than 12 bytes or does not match that signature, treat it as non-FIT.

### Native File Copying

The project already copies accepted shared files into `cacheDir/shared-fit-intake`.

The same cache copy path can be reused for file signature inspection to avoid reading the provider stream twice in incompatible ways. If implementation simplicity is better with a single copy-then-validate flow, that is acceptable as long as errors remain actionable and the file is not treated as an accepted draft until validation succeeds.

Any cached file created only for validation and then rejected as non-FIT should be deleted immediately on the native side.

Cache filenames should continue to be sanitized and timestamp-prefixed.

### Flutter UX Behavior

The existing Flutter side receives either:

- a draft event that opens `ShareConfirmScreen`, or
- an error event.

Update the Flutter coordination so non-FIT or unreadable-file errors do not navigate into the share confirmation flow. Instead:

- surface a visible error message through a root-level `ScaffoldMessenger`,
- preserve the existing share confirmation flow for valid FIT drafts.

This applies to both warm-start event delivery and cold-start initial payload delivery. If the app is launched from an invalid share before Flutter is ready, the native layer must buffer that error payload through the existing initial-payload mechanism so Flutter can show the home-screen prompt after startup.

The desired behavior for this task is specifically:

- valid FIT file: open confirmation flow,
- invalid/non-FIT file: show a prompt on the home screen,
- multiple files: show an error on the home screen rather than entering confirmation.

When the app is already open on another screen and a new invalid share arrives, prefer the smallest behavior change: do not force navigation back to the home screen. Instead, suppress share-confirm navigation and surface the visible error prompt through the root-level `ScaffoldMessenger`.

### Error Messages

Error messaging should remain specific enough to explain why intake failed.

Examples of acceptable messages:

- `Only one FIT file can be shared at a time`
- `Only FIT files are supported`
- `Unable to read shared FIT file`

If the native layer includes low-level details, Flutter should present them in the existing user-visible style without exposing secrets or confusing stack data.

## Testing Design

Follow TDD for the behavior change.

### Android Unit Tests

Add or update Kotlin unit tests for:

- `SEND_MULTIPLE` selecting `ClipData` and enforcing single-file rejection,
- `VIEW` selecting `intent.data` and deduplicating overlapping `data` and `ClipData` entries,
- generic MIME types with `.fit` filenames being accepted,
- opaque filenames with recognized FIT content being accepted,
- duplicated references to the same URI being normalized to one candidate file,
- distinct multiple candidate files still being rejected as multi-file input,
- non-FIT files being rejected even when delivered through a generic system action.

### Flutter Tests

Add or update Dart tests for share navigation behavior so that:

- a valid shared draft still routes to `ShareConfirmScreen`,
- an intake error leaves the app on the home screen and shows the error prompt,
- a cold-start invalid share still surfaces the prompt after Flutter initialization,
- a new invalid share event while the app is already open does not incorrectly open the confirmation flow.

### Verification Commands

After implementation, run the smallest relevant scopes first, then broader checks:

```bash
flutter test test/services/share_navigation_coordinator_test.dart
flutter test
./android/gradlew test
flutter analyze
```

If Android unit tests are scoped more narrowly, that is preferred before the full `./gradlew test` run.

## Files Expected To Change

| File | Change |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Broaden intent filters to generic file actions and MIME matching |
| `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/MainActivity.kt` | Accept broader actions and validate FIT files inside the app |
| `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentItemSelector.kt` | Support additional system actions and URI selection paths |
| `android/app/src/main/kotlin/cn/onelap/onelap_strava_sync/SharedFitIntentValidator.kt` | Shift to app-side FIT detection, including name/content fallback |
| `android/app/src/test/kotlin/cn/onelap/onelap_strava_sync/*` | Add native regression coverage for new actions and validation |
| `lib/services/share_navigation_coordinator.dart` and/or related Flutter UI code | Keep invalid shares on the home screen with a visible prompt |
| `test/services/share_navigation_coordinator_test.dart` and related tests | Verify routing and error handling behavior |

## Non-Goals

- supporting batch upload of multiple FIT files in one share action,
- changing iOS share handling,
- redesigning the share confirmation UI,
- accepting non-FIT files for upload.

## Risks And Mitigations

### Risk: Broader filters make the app appear for irrelevant files

Mitigation: this is intentional at the Android chooser layer, and the app will reject unsupported files internally with a clear message.

### Risk: Some sender apps still use custom or undocumented flows

Mitigation: cover the common Android file-transfer actions and all standard URI sources (`EXTRA_STREAM`, `ClipData`, `data`) so the remaining unsupported surface is minimized.

### Risk: Content inspection requires reading provider streams

Mitigation: reuse the existing cache-copy flow and handle I/O failures as user-visible read errors rather than silent failures.
