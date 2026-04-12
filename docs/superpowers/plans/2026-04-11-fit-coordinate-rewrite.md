# FIT Coordinate Rewrite Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an opt-in GCJ-02 to WGS84 FIT rewrite step before Strava upload for both OneLap automatic sync and shared FIT upload.

**Architecture:** Keep coordinate conversion and FIT rewriting in small dedicated services. Wire the feature through the existing settings flow, inject the rewrite service into upload paths, and preserve current dedupe behavior by fingerprinting the original downloaded FIT.

**Tech Stack:** Flutter, Dart, `fit_tool` 1.0.5, `flutter_secure_storage`, existing widget/unit test suite

---

## File Map

### New files

- `lib/services/coordinate_converter.dart`
  - Pure Dart GCJ-02 to WGS84 exact inverse conversion.
- `lib/services/fit_coordinate_rewrite_service.dart`
  - Decode FIT, rewrite supported coordinate fields, write unique temporary FIT output.
- `test/services/coordinate_converter_test.dart`
  - Unit coverage for in-China and out-of-China conversion behavior.
- `test/services/fit_coordinate_rewrite_service_test.dart`
  - Unit coverage for FIT rewrite behavior, null field preservation, and temp output creation.
- `test/services/sync_engine_test.dart`
  - Focused coverage for upload-file selection and dedupe behavior.

### Modified files

- `pubspec.yaml`
  - Add `fit_tool` dependency.
- `lib/services/settings_service.dart`
  - Add rewrite flag key and keep string-based persistence behavior stable.
- `lib/screens/settings_screen.dart`
  - Add dedicated boolean state and UI switch for the rewrite option.
- `lib/screens/home_screen.dart`
  - Read rewrite flag, construct rewrite service, inject it into `SyncEngine`.
- `lib/services/sync_engine.dart`
  - Accept injected rewrite dependencies and use rewritten file for upload only.
- `lib/services/shared_fit_upload_service.dart`
  - Accept injected rewrite service and apply rewrite when the setting is enabled.
- `lib/services/share_navigation_coordinator.dart`
  - Accept injected upload service instance without regressing current share flow.
- `lib/main.dart`
  - Build the production `SharedFitUploadService` and pass it into `ShareNavigationCoordinator`.
- `lib/services/sync_failure_formatter.dart`
  - Recognize and format coordinate rewrite failures.
- `test/services/settings_service_test.dart`
  - Add rewrite setting persistence coverage.
- `test/screens/settings_screen_test.dart`
  - Cover loading, toggling, and preserving the rewrite switch.
- `test/services/shared_fit_upload_service_test.dart`
  - Cover passthrough, rewrite success, and rewrite failure behavior.
- `test/services/sync_failure_formatter_test.dart`
  - Cover coordinate rewrite failure formatting.
- `test/services/share_navigation_coordinator_test.dart`
  - Update wiring expectations if constructor shape changes.

## Task 1: Add the dependency and lock the settings contract

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/services/settings_service.dart`
- Test: `test/services/settings_service_test.dart`

- [ ] **Step 1: Write the failing settings test for the rewrite flag**

Add a test case in `test/services/settings_service_test.dart` that saves `SettingsService.keyGcjCorrectionEnabled: 'true'` and expects `loadSettings()` to return `'true'` while preserving the other existing keys.

- [ ] **Step 2: Run the settings test to verify it fails**

Run: `flutter test test/services/settings_service_test.dart`
Expected: FAIL because `keyGcjCorrectionEnabled` does not exist yet.

- [ ] **Step 3: Add the new dependency and setting key**

Make the minimal code changes:

- Add `fit_tool: 1.0.5` to `pubspec.yaml`
- Add `SettingsService.keyGcjCorrectionEnabled = 'GCJ_CORRECTION_ENABLED'`
- Add the key to `SettingsService.allKeys`
- Keep the existing string-only settings model intact

- [ ] **Step 4: Run the settings test again**

Run: `flutter test test/services/settings_service_test.dart`
Expected: PASS.

- [ ] **Step 5: Run package resolution**

Run: `flutter pub get`
Expected: dependency graph updates successfully.

## Task 2: Implement and test the coordinate conversion service

**Files:**
- Create: `lib/services/coordinate_converter.dart`
- Create: `test/services/coordinate_converter_test.dart`

- [ ] **Step 1: Write the failing converter tests**

Add tests covering:

- an in-China point returns a changed coordinate pair
- an out-of-China point returns the original coordinate pair unchanged

Keep assertions simple and tolerant to floating-point behavior.

- [ ] **Step 2: Run the converter test to verify it fails**

Run: `flutter test test/services/coordinate_converter_test.dart`
Expected: FAIL because the new service file does not exist.

- [ ] **Step 3: Implement the minimal converter**

Implement in `lib/services/coordinate_converter.dart`:

- China bounds helper
- internal transform helpers
- `gcj02ToWgs84Exact(double latitude, double longitude)`

Return a small value object or record-like result consistent with repo style.

- [ ] **Step 4: Run the converter tests again**

Run: `flutter test test/services/coordinate_converter_test.dart`
Expected: PASS.

## Task 3: Implement and test FIT coordinate rewriting in isolation

**Files:**
- Create: `lib/services/fit_coordinate_rewrite_service.dart`
- Create: `test/services/fit_coordinate_rewrite_service_test.dart`

- [ ] **Step 1: Write the failing FIT rewrite tests**

Add tests that cover:

- rewriting a FIT file with `RecordMessage.positionLat/positionLong`
- preserving `null` targeted coordinates
- preserving the original value when conversion would produce an invalid latitude/longitude
- succeeding on a FIT payload with none of the targeted coordinate fields
- creating a unique cache output path with a `.fit` extension in the application cache directory

Use `fit_tool` in tests to generate a minimal in-memory FIT sample rather than relying on checked-in fixtures.

- [ ] **Step 2: Run the FIT rewrite tests to verify they fail**

Run: `flutter test test/services/fit_coordinate_rewrite_service_test.dart`
Expected: FAIL because the rewrite service does not exist.

- [ ] **Step 3: Implement the minimal rewrite service**

Implement `lib/services/fit_coordinate_rewrite_service.dart`:

- read bytes from `File`
- decode with `FitFile.fromBytes`
- iterate `fitFile.records`
- rewrite supported message fields only:
  - `RecordMessage.positionLat/positionLong`
  - `LapMessage.startPositionLat/startPositionLong`
  - `LapMessage.endPositionLat/endPositionLong`
  - `SessionMessage.startPositionLat/startPositionLong`
  - `SessionMessage.necLat/necLong`
  - `SessionMessage.swcLat/swcLong`
- preserve `null` values
- preserve original values if converted coordinates are invalid
- use deterministic rounding before writing values back to the FIT messages
- clear `fitFile.crc`
- write a unique `.fit` file to the application cache directory
- use only the public `package:fit_tool/fit_tool.dart` import surface

- [ ] **Step 4: Run the FIT rewrite tests again**

Run: `flutter test test/services/fit_coordinate_rewrite_service_test.dart`
Expected: PASS.

## Task 4: Add the settings UI and keep existing save flows stable

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Write the failing settings screen tests**

Add widget tests that verify:

- the rewrite switch loads from stored settings
- toggling the switch and saving sync settings persists the boolean value
- existing Strava auth/save flows preserve the boolean value

- [ ] **Step 2: Run the settings screen tests to verify they fail**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL because the switch does not exist yet.

- [ ] **Step 3: Implement the minimal settings UI changes**

Update `lib/screens/settings_screen.dart` to:

- keep `GCJ_CORRECTION_ENABLED` in `SettingsService.allKeys`
- avoid creating a `TextEditingController` for that key
- store it in dedicated `bool _gcjCorrectionEnabled` state
- load it in `_load()` with a default of `false`
- preserve it in `_save()` and `_saveSyncSettings()`
- render a switch with the approved copy

- [ ] **Step 4: Run the settings screen tests again**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS.

## Task 5: Wire rewrite behavior into shared FIT upload

**Files:**
- Modify: `lib/services/shared_fit_upload_service.dart`
- Modify: `lib/main.dart`
- Test: `test/services/shared_fit_upload_service_test.dart`

- [ ] **Step 1: Write the failing shared upload tests**

Add tests for `SharedFitUploadService` covering:

- pass-through upload when rewrite is disabled
- rewritten file upload when enabled
- failure result when rewrite throws

- [ ] **Step 2: Run the shared upload tests to verify they fail**

Run: `flutter test test/services/shared_fit_upload_service_test.dart`
Expected: FAIL because rewrite dependencies and behavior do not exist yet.

- [ ] **Step 3: Implement the minimal shared upload wiring**

Update `SharedFitUploadService` to accept:

- rewrite service dependency
- optional setting parser for `GCJ_CORRECTION_ENABLED`

Behavior:

- load settings
- if enabled, rewrite the FIT before `_executeUpload`
- if rewrite fails, return `SharedFitUploadStatus.failure` with the error message

Update `main.dart` so the production app creates a rewrite-capable `SharedFitUploadService` and passes it into `ShareNavigationCoordinator` through the existing injected upload-service constructor path.

- [ ] **Step 4: Run the shared upload tests again**

Run: `flutter test test/services/shared_fit_upload_service_test.dart`
Expected: PASS.

## Task 6: Wire rewrite behavior into automatic sync without changing dedupe identity

**Files:**
- Modify: `lib/screens/home_screen.dart`
- Modify: `lib/services/sync_engine.dart`
- Create: `test/services/sync_engine_test.dart`

- [ ] **Step 1: Write the failing sync engine tests**

Add focused tests covering:

- original downloaded file is still used for fingerprinting
- rewritten file is used for upload when rewrite is enabled
- rewrite errors are reported as `坐标转换失败 (<filename>): ...`

Use fakes for OneLap, Strava, StateStore, and rewrite service.

- [ ] **Step 2: Run the sync engine tests to verify they fail**

Run: `flutter test test/services/sync_engine_test.dart`
Expected: FAIL because the new constructor shape and rewrite logic do not exist.

- [ ] **Step 3: Implement the minimal sync wiring**

Update `SyncEngine` to accept:

- `bool gcjCorrectionEnabled`
- `FitCoordinateRewriteService fitCoordinateRewriteService`

Keep the flow strict:

- download original FIT
- fingerprint original FIT
- if already synced, skip upload
- if rewrite is enabled, rewrite only after fingerprinting
- upload rewritten file when available
- preserve current duplicate handling and mark-synced behavior

Update `home_screen.dart` to read the flag from settings, construct the rewrite service, and pass both into `SyncEngine`.

- [ ] **Step 4: Run the sync engine tests again**

Run: `flutter test test/services/sync_engine_test.dart`
Expected: PASS.

## Task 7: Surface rewrite failures correctly in the UI

**Files:**
- Modify: `lib/services/sync_failure_formatter.dart`
- Test: `test/services/sync_failure_formatter_test.dart`

- [ ] **Step 1: Write the failing formatter test**

Add a test verifying that `坐标转换失败 (ride.fit): ...` is converted into a coordinate-conversion-specific user message rather than a generic upload error.

- [ ] **Step 2: Run the formatter test to verify it fails**

Run: `flutter test test/services/sync_failure_formatter_test.dart`
Expected: FAIL because the formatter only recognizes download/upload prefixes.

- [ ] **Step 3: Implement the minimal formatter change**

Extend the regex and mapping logic to recognize `坐标转换失败` and return a specific message that tells the user the file could not be converted before upload.

- [ ] **Step 4: Run the formatter test again**

Run: `flutter test test/services/sync_failure_formatter_test.dart`
Expected: PASS.

## Task 8: Verify the whole feature end to end

**Files:**
- Modify only if verification exposes defects

- [ ] **Step 1: Format the touched files**

Run: `dart format lib test`
Expected: formatting completes without errors.

- [ ] **Step 2: Run targeted tests for changed areas**

Run:

- `flutter test test/services/settings_service_test.dart`
- `flutter test test/services/coordinate_converter_test.dart`
- `flutter test test/services/fit_coordinate_rewrite_service_test.dart`
- `flutter test test/screens/settings_screen_test.dart`
- `flutter test test/services/shared_fit_upload_service_test.dart`
- `flutter test test/services/sync_engine_test.dart`
- `flutter test test/services/sync_failure_formatter_test.dart`

Expected: PASS.

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: PASS.

- [ ] **Step 4: Run full test suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 5: Manual sanity check with a real OneLap FIT sample**

If a local sample is available:

- enable the new setting
- run rewrite once
- inspect that a rewritten `.fit` file is created
- verify the rewritten file still uploads successfully to Strava or at minimum parses successfully with `fit_tool`

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib test
git commit -m "Add optional FIT coordinate rewrite before upload"
```
