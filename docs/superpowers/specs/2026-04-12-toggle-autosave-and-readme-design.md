# Toggle Autosave And README Update Design

## Goal

Make the GCJ-02 to WGS84 settings toggle save immediately when the user taps it, and document the coordinate rewrite feature in `README.md`.

## Target Context

This follow-up applies to the in-progress implementation on branch `feature/fit-coordinate-rewrite` in the current worktree, where the optional FIT coordinate rewrite feature, `GCJ_CORRECTION_ENABLED` setting, and settings toggle already exist but are not yet documented in `README.md` and do not yet auto-save on toggle.

## Current State

- The coordinate rewrite feature is implemented and verified in code
- `README.md` does not yet mention the new upload-time coordinate rewrite behavior
- `SettingsScreen` currently persists `GCJ_CORRECTION_ENABLED` only when the user taps `保存同步设置`

## Chosen Approach

Use immediate persistence for the toggle only, while keeping the existing explicit save button for lookback days.

## Why This Approach

- It matches the user's requested behavior exactly
- It keeps the current settings screen structure intact
- It avoids broadening the follow-up into a larger sync-settings redesign

## README Changes

Update `README.md` in bilingual style to mention:

- optional upload-time `GCJ-02 -> WGS84` conversion
- that the feature applies to both OneLap sync uploads and shared FIT uploads
- that it should only be enabled when the source track is known to be GCJ-02 or visibly offset

## Settings Behavior Changes

Update `lib/screens/settings_screen.dart` so the coordinate rewrite switch saves immediately.

Behavior:

1. User toggles the switch
2. UI updates immediately
3. App persists only `GCJ_CORRECTION_ENABLED`
4. On success, keep the new state
5. On failure, revert the switch state and show `设置保存失败: ...`

The existing `保存同步设置` button remains responsible for `lookbackDays` only.

## Scope

Modify:

- `README.md`
- `lib/screens/settings_screen.dart`
- `test/screens/settings_screen_test.dart`

No service-layer persistence model changes are needed.

This is because the target branch already contains the `GCJ_CORRECTION_ENABLED` key in `SettingsService`; this follow-up only changes how the existing setting is persisted from the settings UI.

## Testing

Add widget coverage for:

- toggle change immediately persisting the new setting value
- persistence failure reverting the switch state and showing an error message

Run:

- `flutter test test/screens/settings_screen_test.dart`

For the README update, no extra verification is required beyond the existing implementation verification already completed.
