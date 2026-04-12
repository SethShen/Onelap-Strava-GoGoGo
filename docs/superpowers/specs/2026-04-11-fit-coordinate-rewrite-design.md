# FIT Coordinate Rewrite Design

## Goal

Add an optional upload-time rewrite step that converts GCJ-02 track coordinates to WGS84 before uploading FIT files to Strava.

This feature applies to both:

- OneLap automatic sync
- Shared FIT upload

The feature is explicitly user-controlled. The app does not attempt to auto-detect the input coordinate system.

## Current State

The current repository downloads OneLap FIT files and uploads them to Strava without rewriting file contents.

- `lib/services/sync_engine.dart` downloads FIT files and uploads them directly
- `lib/services/shared_fit_upload_service.dart` uploads shared FIT files directly
- `lib/services/settings_service.dart` stores sync-related settings in secure storage
- `lib/screens/settings_screen.dart` exposes user-editable settings

There is currently no FIT parsing or rewriting layer in the app.

## Chosen Approach

Use a settings-controlled rewrite step before upload.

When the new setting is enabled:

1. Read the original FIT file
2. Decode the FIT payload
3. Convert selected coordinate fields from GCJ-02 to WGS84
4. Write a rewritten FIT file into the cache directory
5. Upload the rewritten file to Strava

When the setting is disabled, existing behavior remains unchanged.

## Why This Approach

This is the smallest reliable change.

- It matches the already-proven implementation strategy used by `starva_auto`
- It avoids unreliable coordinate-system auto-detection
- It keeps upload behavior consistent across automatic sync and shared upload
- It limits risk by changing only the upload path, not dedupe or persisted sync identity

## Non-Goals

The first version does not include:

- Automatic detection of whether a FIT file is GCJ-02 or WGS84
- GPX or TCX coordinate rewriting
- Rewriting developer fields
- Rewriting every possible FIT message containing coordinates
- Silent fallback to uploading the original file after rewrite failure

## Dependencies

Add `fit_tool` to `pubspec.yaml`.

Rationale:

- It is a published Dart/Flutter package with FIT read/write support
- It has a stronger maturity signal than `fit_sdk` for this repository's immediate needs
- `starva_auto` has already demonstrated that it can be used for coordinate rewrite before Strava upload

Pinned implementation target:

- `fit_tool: 1.0.5`

Verified API surface for this design:

- Import path: `package:fit_tool/fit_tool.dart`
- Decode entrypoint: `FitFile.fromBytes(bytes)`
- Encode entrypoint: `fitFile.toBytes()`
- Mutable FIT container: `fitFile.records`
- Mutable message access: `record.message`
- Confirmed message types used by this design:
  - `RecordMessage`
  - `LapMessage`
  - `SessionMessage`
- Confirmed mutable coordinate properties exposed by `fit_tool`:
  - `RecordMessage.positionLat` / `positionLong`
  - `LapMessage.startPositionLat` / `startPositionLong`
  - `LapMessage.endPositionLat` / `endPositionLong`
  - `SessionMessage.startPositionLat` / `startPositionLong`
  - `SessionMessage.necLat` / `necLong`
  - `SessionMessage.swcLat` / `swcLong`

The implementation should use the public `package:fit_tool/fit_tool.dart` import surface rather than `package:fit_tool/src/...` imports.

## Coordinate Conversion

Add a small internal coordinate conversion service rather than adding a separate coordinate-transform package dependency.

New file:

- `lib/services/coordinate_converter.dart`

Responsibilities:

- Determine whether a point falls outside mainland China handling bounds
- Perform the forward GCJ offset transform internally as part of inverse solving
- Expose `gcj02ToWgs84Exact(double latitude, double longitude)`

Algorithm choice:

- Use the iterative exact inverse approach commonly known as `gcj2wgs_exact`
- Preserve points outside China without modification

FIT coordinate encoding rules:

- FIT latitude and longitude fields are stored as semicircle integers
- The rewrite flow must convert `semicircles -> degrees -> gcj02ToWgs84Exact -> semicircles`
- In practice, `fit_tool` exposes the selected message coordinate properties as decoded `double?` values; `null` must be treated as absent and skipped
- In v1, the only invalid/sentinel-like case the implementation must preserve explicitly is `null`
- Converted values must be rounded deterministically before writing back to the FIT message
- If conversion produces an invalid latitude or longitude, preserve the original field value

Required regression coverage:

- At least one test where a targeted coordinate property is `null` and remains unchanged after rewrite

Rationale:

- The implementation is small and self-contained
- It avoids taking on a second third-party dependency for a narrow feature
- The exact inverse approach is safer than a one-pass approximation for rewritten activity tracks

## FIT Rewrite Service

Add a dedicated service for rewriting FIT coordinates.

New file:

- `lib/services/fit_coordinate_rewrite_service.dart`

Responsibilities:

- Accept an input `File`
- Decode the FIT payload
- Update the selected coordinate fields
- Emit a rewritten FIT file into the cache directory
- Return the rewritten file for upload

The service should be stateless aside from temporary file creation.

Suggested API:

- `Future<File> rewriteFit(File inputFile)`

The service should be constructor-injected anywhere it is used so upload-path behavior can be tested without touching real FIT parsing code.

## FIT Fields To Rewrite In V1

Rewrite only the smallest useful set of standard fields.

Included in v1:

- `RecordMessage.positionLat`
- `RecordMessage.positionLong`
- `LapMessage.startPositionLat`
- `LapMessage.startPositionLong`
- `LapMessage.endPositionLat`
- `LapMessage.endPositionLong`
- `SessionMessage.startPositionLat`
- `SessionMessage.startPositionLong`
- `SessionMessage.necLat`
- `SessionMessage.necLong`
- `SessionMessage.swcLat`
- `SessionMessage.swcLong`

Excluded in v1:

- `CoursePointMessage`
- `SegmentPointMessage`
- `SegmentLapMessage`
- Developer-defined coordinate fields

Rationale:

- `RecordMessage` is the most important message for actual route display on Strava
- Lap and session start/end fields reduce obvious summary-level inconsistencies
- Excluding less common message types keeps the first version smaller and lowers compatibility risk

## Temporary File Strategy

Write rewritten FIT files to the application cache directory.

Suggested behavior:

- Preserve the original input file
- Create a unique rewritten filename in cache while preserving the `.fit` extension
- Use a timestamp, random suffix, or `createTemp`-style uniqueness rather than a stable reused filename
- Do not delete rewritten files immediately in v1 so failures can be inspected during testing

Future cleanup can be added later if needed.

## SyncEngine Integration

Modify `lib/services/sync_engine.dart`.

Current effective flow:

1. Download FIT
2. Compute fingerprint
3. Upload FIT
4. Poll Strava
5. Mark synced

New flow:

1. Download FIT
2. Compute fingerprint from the original downloaded file
3. If rewrite is enabled, rewrite the FIT into a temporary file
4. Upload the selected file
5. Poll Strava
6. Mark synced

Integration shape:

- Add an explicit `gcjCorrectionEnabled` dependency to `SyncEngine`
- Inject `FitCoordinateRewriteService` into `SyncEngine`
- Keep settings IO in the caller layer rather than loading settings inside `SyncEngine`
- `lib/screens/home_screen.dart` must read `GCJ_CORRECTION_ENABLED`, construct `FitCoordinateRewriteService`, and pass both the flag and service into `SyncEngine`

This keeps `SyncEngine` testable and avoids coupling sync orchestration to storage details.

Important invariant:

- Dedupe must continue to use the original downloaded file

Rationale:

- Coordinate rewrite is an upload-time transformation, not a new activity identity
- Changing dedupe identity would make behavior depend on a user setting and could create duplicate uploads across setting changes

## Shared Upload Integration

Modify `lib/services/shared_fit_upload_service.dart`.

Current flow:

1. Validate shared file
2. Load settings
3. Upload FIT

New flow:

1. Validate shared file
2. Load settings
3. If rewrite is enabled, rewrite the FIT into a temporary file
4. Upload the selected file

This keeps shared upload behavior aligned with automatic sync behavior.

Integration shape:

- Inject `FitCoordinateRewriteService` into `SharedFitUploadService`
- The rewritten output must retain a `.fit` extension
- Tests should cover passthrough, rewrite success, and rewrite failure
- `lib/services/share_navigation_coordinator.dart` must construct or inject the rewrite-capable `SharedFitUploadService` used by `ShareConfirmScreen`
- `lib/main.dart` must pass the production `SharedFitUploadService` instance into `ShareNavigationCoordinator` rather than relying on the current default constructor path

## Settings Integration

Modify `lib/services/settings_service.dart`.

Add:

- `keyGcjCorrectionEnabled = 'GCJ_CORRECTION_ENABLED'`

Include the key in `allKeys` so existing load/save behavior continues to work through the same settings mechanism.

Storage contract:

- Persist the value as the string `true` or `false`
- Missing key means disabled

Modify `lib/screens/settings_screen.dart`.

Add a user-visible setting for the new behavior.

Recommended copy:

- Title: `上传前将 GCJ-02 转为 WGS84`
- Supporting text: `仅在来源轨迹偏移且确认使用 GCJ-02 时开启`

The UI should make it clear that this is an advanced compatibility setting, not a default requirement.

Because this screen is controller-based and primarily text-oriented today, the switch should use a dedicated boolean state in the screen rather than a text field controller.

Implementation detail for this codebase:

- `keyGcjCorrectionEnabled` remains part of `SettingsService.allKeys`
- `lib/screens/settings_screen.dart` must not create a `TextEditingController` for this boolean key
- The screen must load and save this key through dedicated boolean state
- `_load()`, `_save()`, and `_saveSyncSettings()` must preserve the existing boolean value correctly
- Related tests should be updated in `test/screens/settings_screen_test.dart`

## Failure Handling

Rewrite failures should stop upload of that file.

Automatic sync behavior:

- Count the activity as failed
- Include a failure reason prefixed with `坐标转换失败`

The raw failure shape must be:

- `坐标转换失败 (<filename>): <details>`

Shared upload behavior:

- Return upload failure with a clear message
- Do not upload the original file after rewrite failure

Rationale:

- Silent fallback would hide a known data-quality issue and produce confusing route offsets for users

Related formatter change:

- Extend `lib/services/sync_failure_formatter.dart` so `坐标转换失败` is recognized and surfaced as a coordinate-conversion-specific message instead of falling back to a generic upload failure message

## Testing Strategy

Add focused tests where practical.

Recommended test coverage:

- `SettingsService` key round-trip for the new rewrite flag
- `SettingsScreen` loading, toggling, and preserving the rewrite switch across save flows
- `CoordinateConverter` behavior for:
  - representative in-China point
  - representative out-of-China point
- `FitCoordinateRewriteService` behavior for:
  - FIT file with record coordinates
  - FIT file with no targeted coordinate fields
  - rewrite output file creation
- Integration-adjacent tests for:
  - `SyncEngine` choosing rewritten file for upload when enabled
  - `SharedFitUploadService` choosing rewritten file for upload when enabled
  - rewrite failures surfacing with the expected `坐标转换失败` prefix

After implementation, run:

- `dart format lib test`
- `flutter analyze`
- `flutter test`

## Risks

1. Some OneLap FIT files may already use WGS84
2. FIT message coverage in v1 is intentionally incomplete
3. Some FIT samples may expose library compatibility gaps
4. Temporary files will accumulate until cleanup is added

## Rollout Guidance

This feature should ship as opt-in.

Recommended rollout behavior:

- Default setting value is disabled
- Validate using real OneLap FIT samples before relying on it broadly
- Expand field coverage only if real-world files show a clear need

## Implementation Summary

Add a small, opt-in FIT rewrite path that converts selected standard coordinate fields from GCJ-02 to WGS84 before Strava upload, while preserving the current dedupe model and keeping shared upload behavior consistent with automatic sync.
