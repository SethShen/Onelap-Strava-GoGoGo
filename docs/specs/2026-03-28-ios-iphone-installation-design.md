# Design: iPhone Signing And Installation

**Date:** 2026-03-28  
**Status:** Draft  
**Scope:** iOS project (`ios/`) and local Xcode device setup

## Goal

Make this Flutter app installable on the user's own iPhone for testing and personal use by:

1. confirming the phone is visible to Xcode and Flutter,
2. switching the app to a user-owned bundle identifier,
3. configuring automatic signing with the user's personal Apple team,
4. attempting a real device build/install and capturing the exact blocker if it fails.

## Current State

- The project already has an iOS target and CocoaPods installed.
- `Runner` uses automatic code signing.
- The current app bundle identifier is `cn.onelap.onelapStravaSync`.
- The local machine has a working Xcode toolchain, but iOS simulator runtimes are not installed.
- The user wants real-device installation, so simulator support is not required for this task.

## Chosen Approach

Use the user's currently signed-in personal Xcode team and change the app to a unique personal bundle identifier, following a pattern like `cn.onelap.onelapStravaSync.<personalSuffix>`.

For this session, the default personal suffix is `yintianan` unless Xcode or device signing requires a different value.

This is the lowest-friction path because it avoids bundle identifier ownership conflicts, keeps the existing automatic-signing workflow, and matches the user's short-term goal of testing and self-use on one iPhone.

## Alternatives Considered

### 1. Keep the existing bundle identifier

Not recommended. Automatic signing often fails if the identifier is already associated with another team or app registration.

### 2. Wait for a paid Apple Developer account and distribute later

Useful for long-term installation and TestFlight, but not required for first-device testing.

### 3. Use manual signing and provisioning profiles

Too much overhead for a single-user installation path and unnecessary while automatic signing is available.

## Planned Changes

### Device Detection

- Check whether the user's iPhone appears in `xcrun xctrace list devices` and `flutter devices`.
- If the phone is missing, stop and report the exact missing prerequisite, such as:
  - cable trust prompt not accepted,
  - developer mode not enabled on iPhone,
  - Xcode has not finished preparing the device,
  - phone is locked.

### Signing Configuration

- Update the `Runner` target bundle identifier from `cn.onelap.onelapStravaSync` to `cn.onelap.onelapStravaSync.<personalSuffix>`.
- Keep `CODE_SIGN_STYLE = Automatic`.
- Prefer letting Xcode own the team selection locally.
- If real-device CLI builds fail because the team is not persisted, allow Xcode to write the selected `DEVELOPMENT_TEAM` into `ios/Runner.xcodeproj/project.pbxproj` and treat that as an expected local-repo change for this task.
- Any such team identifier should be reported clearly so the user knows a personal signing value entered the project file.

### Install Attempt

- First verify the device can be targeted.
- Then attempt install using Flutter CLI first.
- If lower-level Xcode invocation is needed, use the CocoaPods workspace at `ios/Runner.xcworkspace`, not the bare project file.
- If signing succeeds, the app should appear on the iPhone.
- If signing or provisioning fails, capture the exact Xcode error and report the smallest next action.

## Files Expected To Change

| File | Change |
|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | Update `Runner` signing settings such as bundle identifier and, if required, team selection |

These changes are expected to be project-configuration changes only. No Dart or Flutter app logic changes are planned for this task.

## Error Handling

| Scenario | Handling |
|---|---|
| iPhone not detected | Report detection output and stop before editing signing |
| Personal team unavailable in Xcode | Ask user to sign into Xcode Accounts and retry |
| Bundle ID conflict | Keep personal suffix and retry signing |
| Developer Mode disabled | Tell user to enable it on the device and reconnect |
| Trust / pairing issue | Tell user to unlock phone, trust Mac, and retry |
| Free Apple ID signing limit | Report that installation may work only as a short-lived personal build |

## Verification Plan

Successful completion requires fresh evidence for all of the following:

1. device appears in a local Apple or Flutter device listing,
2. iOS build command reaches a valid device destination,
3. install attempt succeeds or fails with a concrete signing/provisioning error,
4. final report includes the exact result and remaining manual steps, if any.

## Non-Goals

- Add TestFlight distribution
- Configure App Store release metadata
- Refactor Flutter app code
- Support multiple Apple teams or multiple bundle IDs in one pass
