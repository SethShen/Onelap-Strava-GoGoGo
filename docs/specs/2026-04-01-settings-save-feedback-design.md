# Design: Settings Save Feedback Improvements

**Date:** 2026-04-01  
**Status:** Approved for implementation  
**Scope:** `SettingsScreen` save feedback for OneLap credentials and lookback days

## Goal

Make settings saves feel responsive and obvious by showing in-progress state for OneLap credential validation, adding an explicit save action for lookback days, and allowing the lookback field to save from the keyboard.

## Current Problems

1. Tapping `保存 OneLap 账号` does not show a visible in-progress state, so the screen appears unresponsive while login validation runs.
2. The `同步最近几天` field has no nearby save affordance, so users may not realize the bottom global `保存` button is required.
3. Pressing return in the `同步最近几天` field does not save the value.

## Chosen Design

### OneLap Credentials

Keep the existing `保存 OneLap 账号` button, but turn it into an in-progress action while validation runs:

- disable the button,
- replace the label with a small spinner plus `验证中...`,
- on success, persist the username and password and show `OneLap 账号已保存`,
- on failure, keep the existing error snackbar behavior and do not persist invalid credentials.

This preserves the current validation-before-save behavior while making the action visible and understandable.

### Lookback Days

Add a local `保存同步设置` button directly below the `同步最近几天` field.

- tapping the button saves only `keyLookbackDays`,
- success shows `同步设置已保存`.

This keeps the change minimal and avoids expanding the scope of the bottom global `保存` button.

### Keyboard Submit

Add `onSubmitted` only for the `同步最近几天` field.

- pressing return saves the same local sync setting,
- OneLap username/password fields will not auto-submit on return, to avoid accidental login validation from the keyboard.

## Alternatives Considered

### 1. Keep a single bottom `保存`

Rejected because it does not solve the discoverability problem around the lookback field.

### 2. Auto-save every field on blur

Rejected because it is a behavior change larger than needed and would make credential validation timing less predictable.

### 3. Save OneLap credentials without validation

Rejected because the current screen intentionally uses validation as part of the save flow, and the user only asked for clearer feedback, not weaker validation.

## Files Expected To Change

| File | Change |
|---|---|
| `lib/screens/settings_screen.dart` | Add loading state, lookback save action, and keyboard submit handling |
| `test/screens/settings_screen_test.dart` | Add widget tests for loading feedback and lookback save behavior |

## Testing Strategy

- add widget coverage for the in-progress `验证中...` state,
- verify successful OneLap validation still persists credentials and now shows the success snackbar,
- verify `保存同步设置` persists only lookback days,
- verify submitting the lookback field from the keyboard persists the value.
