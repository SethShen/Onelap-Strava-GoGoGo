# iPhone Installation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app installable on the user's own iPhone by validating device detection, applying a personal iOS bundle identifier, and completing a real-device build/install attempt.

**Architecture:** Keep the Flutter app code unchanged and limit work to iOS project configuration plus local Xcode device readiness. Use the existing automatic-signing flow, prefer Flutter CLI for verification, and only persist a personal `DEVELOPMENT_TEAM` in the Xcode project if the real-device build requires it.

**Tech Stack:** Flutter, Dart, Xcode, CocoaPods, iOS code signing, `xcrun`, `xcodebuild`

**Spec:** `docs/specs/2026-03-28-ios-iphone-installation-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | Modify | Persist personal bundle identifier and, if required, development team for real-device signing |
| `ios/Runner.xcworkspace` | Use only | Open workspace for CocoaPods-backed signing/build if Xcode UI is needed |

---

## Task 1: Confirm the iPhone is visible to the toolchain

**Files:**
- None

- [ ] **Step 1: List Apple-visible devices**

Run:

```bash
xcrun xctrace list devices
```

Expected: the user's iPhone appears in the list with an iOS version.

- [ ] **Step 2: List Flutter-visible devices**

Run:

```bash
flutter devices
```

Expected: the user's iPhone appears as an iOS device target.

- [ ] **Step 3: Stop and report exact blocker if the phone is missing**

If either command does not show the phone, do not edit signing yet. Report the missing prerequisite with concrete next actions, such as:

- unlock the phone,
- tap Trust on the device,
- enable Developer Mode,
- let Xcode finish preparing the device,
- reconnect the cable.

No commit for this task.

---

## Task 2: Inspect current iOS signing state

**Files:**
- Read: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Capture current bundle identifier and signing fields**

Run:

```bash
grep -nE "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM|CODE_SIGN_STYLE" ios/Runner.xcodeproj/project.pbxproj
```

Expected: current `Runner` bundle identifier is visible. `CODE_SIGN_STYLE = Automatic` may appear only in some target sections, so the important check is that no manual-signing override is already forcing a different setup.

- [ ] **Step 2: Record the personal bundle identifier to use**

Use the agreed default:

```text
cn.onelap.onelapStravaSync.yintianan
```

Expected: this identifier is unique enough for a personal team signing attempt.

- [ ] **Step 3: Stop and report if no personal Xcode team is available**

If the install flow or Xcode account state shows no available personal team, stop and report:

- sign into `Xcode > Settings > Accounts`,
- select the Apple ID team in signing,
- retry device installation after the team appears.

No commit for this task.

---

## Task 3: Persist the personal bundle identifier

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Replace the `Runner` app bundle identifier in all app build configurations**

Update every `Runner` target app configuration entry (`Debug`, `Release`, `Profile`) from:

```text
cn.onelap.onelapStravaSync
```

to:

```text
cn.onelap.onelapStravaSync.yintianan
```

Do not change the `RunnerTests` bundle identifier unless Xcode requires it.

- [ ] **Step 2: Keep automatic signing enabled**

Verify the change does not introduce a manual-signing override for the main app target.

- [ ] **Step 3: Format-free verification of the diff**

Run:

```bash
git diff -- ios/Runner.xcodeproj/project.pbxproj
```

Expected: only the intended signing/bundle identifier changes appear.

- [ ] **Step 4: Commit the bundle identifier change**

Run:

```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "Update iOS bundle identifier for personal signing"
```

Expected: one commit containing only the project signing change.

---

## Task 4: Attempt a real-device build with automatic signing

**Files:**
- Use: `ios/Runner.xcworkspace`

- [ ] **Step 1: Refresh Flutter dependencies**

Run:

```bash
flutter pub get
```

Expected: dependencies resolve without errors.

- [ ] **Step 2: Attempt real-device install with Flutter**

Run:

```bash
flutter run -d <iphone-device-id>
```

Expected: either the app installs on the device, or Flutter/Xcode returns a concrete signing or provisioning error.

- [ ] **Step 3: If Flutter lacks enough detail, run Xcode-backed build evidence**

Run:

```bash
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -destination 'id=<iphone-device-udid>' -showBuildSettings
```

Expected: build settings resolve for the actual device destination.

- [ ] **Step 4: Capture the exact result**

Record one of these outcomes with evidence:

- install succeeded,
- device detected but signing failed,
- team selection missing,
- Developer Mode / trust issue,
- provisioning conflict.

No commit for this task unless Task 5 becomes necessary.

---

## Task 5: Persist the development team only if required

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Confirm the failure is specifically missing team persistence**

Only continue if Task 4 shows a team-selection or signing-identity error that Xcode resolves by selecting the user's personal team.

- [ ] **Step 2: Let Xcode write the team value, or edit only the required `DEVELOPMENT_TEAM` field**

Persist the selected personal team in `ios/Runner.xcodeproj/project.pbxproj` for the main app target.

- [ ] **Step 3: Record the exact team identifier that was persisted**

Capture and report the exact `DEVELOPMENT_TEAM` value written to the project file so the user knows a personal team ID entered repo-tracked configuration.

- [ ] **Step 4: Re-run the real-device install**

Run:

```bash
flutter run -d <iphone-device-id>
```

Expected: installation succeeds, or a new concrete provisioning error appears.

- [ ] **Step 5: Commit the team persistence change**

Run:

```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "Persist iOS personal team signing configuration"
```

Expected: one commit containing only the team persistence change.

Skip this entire task if Task 4 succeeds without persisting a team.

---

## Task 6: Final verification and handoff

**Files:**
- None

- [ ] **Step 1: Re-check detected devices**

Run:

```bash
flutter devices
```

Expected: the iPhone still appears.

- [ ] **Step 2: Verify final repo state**

Run:

```bash
git status --short
```

Expected: only expected iOS configuration files remain changed, if any.

- [ ] **Step 3: Report exact install status**

State one of the following with command evidence:

- app is installed on the iPhone,
- build reaches the device but signing still needs a manual Xcode step,
- device is not yet ready and needs a manual phone/Xcode action.

- [ ] **Step 4: Include the smallest next manual action if blocked**

Examples:

- open `ios/Runner.xcworkspace` and select the personal team,
- trust the developer certificate on the iPhone,
- enable Developer Mode and reconnect,
- accept a signing prompt in Xcode.

No commit for this task.
