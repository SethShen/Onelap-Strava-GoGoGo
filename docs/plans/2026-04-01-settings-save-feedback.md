# Settings Save Feedback Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make saving settings feel responsive and discoverable by adding visible OneLap validation progress, a local lookback-days save button, and return-key save for the lookback field.

**Architecture:** Keep all behavior inside `SettingsScreen` with small, local state additions. Use widget tests to drive the behavior first, then implement the minimal UI changes needed to satisfy those tests without restructuring the screen.

**Tech Stack:** Flutter, Dart, widget tests, Flutter secure storage mock

**Spec:** `docs/specs/2026-04-01-settings-save-feedback-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `lib/screens/settings_screen.dart` | Modify | Add save-progress state and sync-setting save interactions |
| `test/screens/settings_screen_test.dart` | Modify | Prove new save feedback and lookback save behavior |

---

## Task 1: Cover OneLap save progress with a widget test

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that uses a pending `Completer<void>` for validation, taps `保存 OneLap 账号`, then calls `pump()` once without `pumpAndSettle()` and expects `验证中...`, a progress indicator, and a disabled OneLap save button before completion.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "save OneLap credentials shows validating state while request is in flight"`

Expected: FAIL because the current button never enters an in-progress state.

- [ ] **Step 3: Write minimal implementation**

Add a small `_savingOneLapCredentials` state flag and use it to disable the button and swap the label to a spinner plus `验证中...` while validation runs.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 2: Cover the OneLap success confirmation message

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Update the successful save test to expect `OneLap 账号已保存` after validation succeeds.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "save OneLap credentials validates persists and shows success feedback"`

Expected: FAIL because the current code suppresses the success snackbar after validation.

- [ ] **Step 3: Write minimal implementation**

After successful validation-and-save, show the save success snackbar instead of silently returning.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 3: Preserve failure feedback for invalid OneLap credentials

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Extend the existing failed-validation test so it also expects the existing failure snackbar text (`OneLap 登录验证失败: Exception: invalid credentials`) and the button to return from `验证中...` back to `保存 OneLap 账号` after the failed future completes.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "failed OneLap validation keeps previous credentials and restores idle state"`

Expected: FAIL because the current screen does not have a validating state to restore from.

- [ ] **Step 3: Write minimal implementation**

Ensure the OneLap saving flag is reset in a `finally` block so the button always leaves `验证中...`, including on errors.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 4: Cover explicit lookback-days saving

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that enters a new lookback value, taps `保存同步设置`, and verifies only `keyLookbackDays` is updated while unrelated stored settings remain unchanged and `同步设置已保存` appears.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "save sync settings persists lookback days only"`

Expected: FAIL because the button does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Add a local save method and a `保存同步设置` button below the lookback field.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 5: Cover return-key save for lookback days

**Files:**
- Modify: `test/screens/settings_screen_test.dart`
- Modify later: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that submits the `同步最近几天（默认 3）` field from the keyboard and verifies the value is persisted.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/settings_screen_test.dart --plain-name "submitting lookback days field saves sync settings"`

Expected: FAIL because the field has no submit handler.

- [ ] **Step 3: Write minimal implementation**

Add `textInputAction: TextInputAction.done` and `onSubmitted` to call the same local sync-setting save method.

- [ ] **Step 4: Run test to verify it passes**

Run the same test command and expect PASS.

---

## Task 6: Verify the full change

**Files:**
- Modify if needed: `lib/screens/settings_screen.dart`
- Modify if needed: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Format the touched files**

Run: `dart format lib/screens/settings_screen.dart test/screens/settings_screen_test.dart`

- [ ] **Step 2: Run the focused widget test file**

Run: `flutter test test/screens/settings_screen_test.dart`

Expected: PASS.

- [ ] **Step 3: Run broader verification**

Run: `flutter analyze` and `flutter test`

Expected: PASS.

---

## Task 7: Optional Android release build requested by the user

**Files:**
- Use: `build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 1: Build the release APK**

Run: `flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false`

Expected: build succeeds and produces `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 2: Report the APK path as a deliverable, but treat unrelated Android packaging failures separately from the UI-change verification result**

If the build fails for unrelated packaging reasons, report that the settings change was still verified by tests and analysis.
