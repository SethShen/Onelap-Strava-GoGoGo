# Settings Input Polish Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tighten `SettingsScreen` input behavior by validating lookback days, dismissing the keyboard before save feedback, and leaving OneLap fields unfocused after successful save.

**Architecture:** Keep the change local to `SettingsScreen` by adding a small helper for focus dismissal and a narrow validation branch for the lookback field. Drive the change with widget tests that prove invalid values do not persist and save flows clear focus before success feedback.

**Tech Stack:** Flutter, Dart, widget tests, Flutter secure storage mock

**Spec:** `docs/specs/2026-04-01-settings-input-polish-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/screens/settings_screen.dart` | Modify | Add focus dismissal and lookback validation |
| `test/screens/settings_screen_test.dart` | Modify | Cover invalid lookback input and unfocus behavior |

---

## Task 1: Reject invalid lookback values

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that enters `0` into `同步最近几天（默认 3）`, taps `保存同步设置`, and verifies `请输入大于 0 的整数天数` appears and the stored `LOOKBACK_DAYS` value remains unchanged.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "invalid lookback days shows error and does not persist"`

Expected: FAIL because the current code saves `0`.

- [ ] **Step 3: Write minimal implementation**

Validate the trimmed lookback value before save and return early on invalid input.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 2: Clear focus before OneLap success feedback

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that focuses the OneLap password field, taps `保存 OneLap 账号`, and verifies no `EditableText` remains focused after the successful save completes.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "successful OneLap save dismisses keyboard focus"`

Expected: FAIL because the active field keeps focus today.

- [ ] **Step 3: Write minimal implementation**

Dismiss the current focus before starting the OneLap save flow.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 3: Clear focus before sync-setting success feedback

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that focuses the lookback field, saves valid sync settings, and verifies no `EditableText` remains focused after the save completes.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "saving sync settings dismisses keyboard focus"`

Expected: FAIL because the active field keeps focus today.

- [ ] **Step 3: Write minimal implementation**

Reuse the same focus-dismissal helper before saving sync settings.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 4: Verify the change and rebuild Android artifact

**Files:**
- Modify if needed: `lib/screens/settings_screen.dart`
- Modify if needed: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Format touched files**

Run: `dart format lib/screens/settings_screen.dart test/screens/settings_screen_test.dart`

- [ ] **Step 2: Run focused settings tests**

Run: `flutter test test/screens/settings_screen_test.dart`

Expected: PASS.

- [ ] **Step 3: Run broader verification**

Run: `flutter analyze` and `flutter test`

Expected: PASS.

- [ ] **Step 4: Rebuild release APK**

Run: `flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false`

Expected: build succeeds and refreshes `build/app/outputs/flutter-apk/app-release.apk`.
