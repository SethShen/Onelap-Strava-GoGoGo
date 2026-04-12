# Toggle Autosave And README Update Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Document the coordinate rewrite feature in `README.md` and make the GCJ rewrite toggle save immediately when tapped.

**Architecture:** Keep the existing settings screen structure intact. Add a small toggle-specific save path in `SettingsScreen`, leave the sync settings save button responsible for lookback days, and update the bilingual README to describe the upload-time coordinate rewrite behavior.

**Tech Stack:** Flutter, Dart, existing widget tests, markdown documentation

---

## File Map

### Modified files

- `README.md`
  - Document the optional coordinate rewrite feature for both sync and share uploads.
- `lib/screens/settings_screen.dart`
  - Add immediate persistence for the GCJ rewrite toggle, including rollback on save failure.
- `test/screens/settings_screen_test.dart`
  - Add widget coverage for immediate persistence and rollback-on-failure behavior.

## Task 1: Make the rewrite toggle auto-save immediately

**Files:**
- Modify: `lib/screens/settings_screen.dart`
- Test: `test/screens/settings_screen_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Add tests covering:

- tapping the rewrite switch immediately persists `GCJ_CORRECTION_ENABLED`
- if toggle persistence fails, the switch reverts and shows `设置保存失败: ...`

- [ ] **Step 2: Run the target test file to verify failure**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: FAIL because the toggle currently updates local state only and does not auto-save or roll back on failure.

- [ ] **Step 3: Implement the minimal toggle-specific save flow**

Update `lib/screens/settings_screen.dart` to:

- add a small async helper for persisting only `GCJ_CORRECTION_ENABLED`
- optimistically update the switch state when tapped
- persist immediately
- revert the state and show `设置保存失败: ...` if persistence fails
- keep `保存同步设置` responsible for `lookbackDays`

- [ ] **Step 4: Run the target test file again**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS.

## Task 2: Document the coordinate rewrite feature in README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update the bilingual README**

Add concise documentation for:

- optional upload-time `GCJ-02 -> WGS84` conversion
- support in both automatic OneLap sync and shared FIT upload
- guidance to enable it only when the source track is GCJ-02 or visibly offset

- [ ] **Step 2: Verify README wording and placement**

Check that the new content is consistent with the existing bilingual format and placed in the feature/usage sections rather than in unrelated areas.

## Task 3: Verify and commit the follow-up changes

**Files:**
- Modify only if verification exposes defects

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib/screens/settings_screen.dart test/screens/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 2: Run the targeted widget test file**

Run: `flutter test test/screens/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 3: Review git diff for the follow-up scope**

Run: `git diff -- README.md lib/screens/settings_screen.dart test/screens/settings_screen_test.dart`
Expected: only README and toggle auto-save changes are present.

- [ ] **Step 4: Commit**

```bash
git add README.md lib/screens/settings_screen.dart test/screens/settings_screen_test.dart
git commit -m "Auto-save coordinate rewrite setting"
```
