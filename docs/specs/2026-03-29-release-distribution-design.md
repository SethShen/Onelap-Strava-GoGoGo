# Design: GitHub Release Distribution Without Personal Signing

**Date:** 2026-03-29  
**Status:** Draft  
**Scope:** GitHub Release assets, release notes, and platform-specific installation guidance

## Goal

Publish a GitHub Release that:

1. includes a macOS desktop artifact only if it does not contain the author's personal signing identity,
2. does not publish an iOS `.ipa` or other author-signed iOS installable artifact,
3. gives end users clear instructions for running the unsigned macOS app and self-signing the iOS app with their own Apple account.

## Chosen Distribution Model

### macOS

Ship one unsigned macOS archive, using a neutral asset name such as `WanSync-macos-unsigned.zip`, but only after verifying that the bundled app does not carry a personal code signature or embedded author identity metadata.

For this task, verification must be operationalized with explicit checks on the built `.app`, including at minimum:

- `codesign -dv --verbose=4 <app>` to inspect whether a signing identity is present,
- `spctl -a -vv <app>` to inspect Gatekeeper assessment details,
- filename and bundle inspection to ensure no personal suffix or team-derived identity appears in the distributed artifact name or app metadata.

### iOS

Do not upload an `.ipa` or any iOS installable binary to the Release page. Instead, distribute the source repository and publish installation instructions that tell users to open `ios/Runner.xcworkspace`, set their own team, and sign with their own Apple ID.

The Release page should rely on the exact tagged source snapshot for that version so users build the same revision that the release notes describe.

## Why This Model

- It avoids redistributing binaries that carry the author's personal Apple signing identity.
- It keeps the macOS distribution path lightweight for users who are comfortable bypassing Gatekeeper warnings.
- It avoids the misleading impression that iOS users can directly install an unsigned GitHub-hosted package.

## Alternatives Considered

### 1. Publish signed macOS and iOS binaries

Rejected because signed binaries would carry the author's personal signing identity and do not match the privacy goal.

### 2. Publish source only for both platforms

Viable, but less user-friendly for macOS because desktop users can often run an unsigned app directly.

### 3. Publish an unsigned iOS `.ipa`

Rejected because that is not a practical end-user installation path. iOS users generally cannot directly install and re-sign a random GitHub-hosted `.ipa` without additional tooling and manual steps beyond the intended support scope.

## Verification Rules Before Upload

### macOS Asset Verification

Before upload, inspect the built `.app` bundle and archive to confirm:

- no Apple Development or Developer ID signature from the author is present,
- no personal bundle identifier suffix is present,
- no release filename includes personal identifiers.

If the app is signed with the author's personal identity, do not upload it. Either rebuild it unsigned or skip the binary upload.

### iOS Configuration Verification

Before publishing instructions, inspect the repository for public-facing iOS configuration leaks such as:

- personal bundle identifier suffixes,
- persisted `DEVELOPMENT_TEAM` values,
- any user-specific signing configuration.

If found, revert or neutralize them before treating the repo as release-ready.

This is a release blocker, not an optional cleanup. In particular, any persisted personal `DEVELOPMENT_TEAM` value or personal bundle identifier suffix in `ios/Runner.xcodeproj/project.pbxproj` must be removed or replaced with a neutral public configuration before publishing the release.

## Release Page Deliverables

### Required

- one macOS unsigned archive if verification passes,
- release notes describing macOS unsigned behavior,
- release notes explaining that iOS users must build and sign with their own Apple account,
- release notes that point users to the exact tagged source snapshot for the release version.

### Optional

- README updates so installation guidance also exists in the repository,
- a short checklist for maintainers describing what not to upload.

## User-Facing Guidance

### macOS

Tell users that the app is unsigned and may be blocked by Gatekeeper on first launch. Provide the simplest supported opening flow:

1. extract the zip,
2. right-click the app and choose Open,
3. if macOS blocks it, allow it in Privacy & Security and retry.

### iOS

Tell users to:

1. clone or download the repository source,
2. open `ios/Runner.xcworkspace` in Xcode,
3. replace any repo-provided bundle identifier with their own unique bundle identifier,
4. replace any repo-provided signing team with their own Apple team,
5. run on their own device.

## Files Expected To Change

| File | Change |
|---|---|
| `README.md` | Add or refine platform-specific installation and release guidance |
| release notes / GitHub Release body | Add user-facing distribution instructions |
| iOS project configuration files | Only if personal bundle IDs or team settings must be neutralized |

## Non-Goals

- notarize the macOS app,
- create App Store or TestFlight distribution,
- automate CI signing,
- support arbitrary third-party iOS re-sign workflows.
