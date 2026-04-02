# Design: Settings Input Polish

**Date:** 2026-04-01  
**Status:** Approved for implementation  
**Scope:** small interaction polish for `SettingsScreen`

## Goal

Make settings input behavior feel cleaner by validating lookback days before save, dismissing the keyboard before save feedback, and leaving the OneLap fields unfocused after a successful validation-and-save.

## Chosen Design

### Lookback Days Validation

Treat `同步最近几天` as a positive integer field.

- keep numeric keyboard,
- reject empty, zero, negative, and non-integer text,
- on invalid input, do not persist and show `请输入大于 0 的整数天数`.

### Keyboard Dismissal

Before saving OneLap credentials or sync settings, dismiss the active text focus so the keyboard closes before snackbar feedback appears.

### OneLap Success Focus

After OneLap validation succeeds, leave the username/password fields unfocused rather than returning focus to the active field.

## Non-Goals

- no layout redesign,
- no copy rewrite beyond one validation message,
- no changes to Strava settings behavior.

## Files Expected To Change

| File | Change |
|---|---|
| `lib/screens/settings_screen.dart` | Add lookback validation and focus dismissal |
| `test/screens/settings_screen_test.dart` | Add regression coverage for invalid lookback and focus dismissal |
