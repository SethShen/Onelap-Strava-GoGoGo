# Release Distribution Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prepare a GitHub Release that can safely publish a macOS unsigned archive while keeping iOS distribution source-only and removing any public personal signing details.

**Architecture:** Inspect built macOS artifacts before upload and treat personal signing metadata as a release blocker. Neutralize iOS signing configuration in tracked files, then update repository and release-facing documentation so users know how to run the unsigned macOS app and self-sign the iOS app from the tagged source snapshot.

**Tech Stack:** Flutter, Xcode, macOS code signing tools, Git, GitHub Release workflow, Markdown documentation

**Spec:** `docs/specs/2026-03-29-release-distribution-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `README.md` | Modify | Explain public macOS/iOS installation expectations |
| `ios/Runner.xcodeproj/project.pbxproj` | Modify if needed | Remove public personal bundle ID / team configuration |
| `build/macos/Build/Products/Release/onelap_strava_sync.app` | Inspect only | Verify whether the app is unsigned and free of personal signing identity |
| GitHub Release body | Create/update | Publish user-facing install instructions and asset list |

---

## Task 1: Verify the macOS app is safe to publish

**Files:**
- Use: `build/macos/Build/Products/Release/onelap_strava_sync.app`

- [ ] **Step 1: Confirm the release app exists**

Run:

```bash
ls "build/macos/Build/Products/Release/onelap_strava_sync.app"
```

Expected: the `.app` bundle exists.

- [ ] **Step 2: Inspect code signing details**

Run:

```bash
codesign -dv --verbose=4 "build/macos/Build/Products/Release/onelap_strava_sync.app"
```

Expected: either no signature is present, or the output proves the app is unsigned. If a personal signing identity appears, stop and treat it as a release blocker.

- [ ] **Step 3: Inspect Gatekeeper assessment**

Run:

```bash
spctl -a -vv "build/macos/Build/Products/Release/onelap_strava_sync.app"
```

Expected: output consistent with an unsigned app. Record the result for release notes.

- [ ] **Step 4: Inspect app metadata for personal identifiers**

Check the bundle metadata and artifact naming for personal suffixes or team-derived values.

Run:

```bash
defaults read "build/macos/Build/Products/Release/onelap_strava_sync.app/Contents/Info" CFBundleIdentifier
```

Expected: no personal username or personal suffix appears.

- [ ] **Step 5: Stop if any personal signing identity is present**

If Steps 2-4 show personal signing identity or public-facing personal identifiers, do not upload the app. Report the exact blocker first.

No commit for this task.

---

## Task 2: Neutralize public iOS signing configuration

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj`

- [ ] **Step 1: Inspect tracked iOS signing values**

Run:

```bash
grep -nE "PRODUCT_BUNDLE_IDENTIFIER|DEVELOPMENT_TEAM" ios/Runner.xcodeproj/project.pbxproj
```

Expected: any persisted personal team ID or personal bundle suffix becomes visible.

- [ ] **Step 2: Replace public personal bundle identifiers with neutral values**

If the tracked file contains a personal suffix like `.yintianan`, change it back to the public neutral repository value.

- [ ] **Step 3: Remove or neutralize persisted personal `DEVELOPMENT_TEAM` values**

If the tracked file contains the author's personal team ID, remove it or revert it to the repository's neutral state.

- [ ] **Step 4: Verify the diff only removes personal signing details**

Run:

```bash
git diff -- ios/Runner.xcodeproj/project.pbxproj
```

Expected: only the intended neutralization changes appear.

- [ ] **Step 5: Commit the public iOS signing cleanup**

Run:

```bash
git add ios/Runner.xcodeproj/project.pbxproj
git commit -m "Neutralize public iOS signing configuration"
```

Expected: one commit containing only public signing cleanup.

Skip Steps 2-5 if the file is already neutral.

---

## Task 3: Update repository-facing install guidance

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add macOS release guidance**

Document that the GitHub Release may include an unsigned macOS archive and that first launch may require right-click Open or Privacy & Security approval.

- [ ] **Step 2: Add iOS source-install guidance**

Document that iOS users must use the tagged release source snapshot, open `ios/Runner.xcworkspace`, set their own bundle identifier and Apple team, and build with Xcode.

- [ ] **Step 3: Keep bilingual style**

Ensure the added README text remains bilingual Chinese/English to match the existing repository style.

- [ ] **Step 4: Verify the README diff**

Run:

```bash
git diff -- README.md
```

Expected: only release/install guidance changes appear.

- [ ] **Step 5: Commit the README update**

Run:

```bash
git add README.md
git commit -m "Document macOS and iOS release installation paths"
```

Expected: one commit containing only documentation updates.

---

## Task 4: Prepare the macOS release archive

**Files:**
- Create: local release zip artifact

- [ ] **Step 1: Create a neutral archive filename**

Use a name such as:

```text
WanSync-macos-unsigned.zip
```

- [ ] **Step 2: Zip the app bundle**

Run a command that archives `build/macos/Build/Products/Release/onelap_strava_sync.app` into the neutral filename.

- [ ] **Step 3: Re-check the archive contents naming**

Verify the archive filename and the contained app bundle do not include personal identifiers.

- [ ] **Step 4: Treat archive creation as blocked if the app was signed**

If Task 1 found a personal signing identity, do not create or upload the archive until the signing issue is resolved.

No commit for this task.

---

## Task 5: Prepare GitHub Release text and upload decision

**Files:**
- Create/update: GitHub Release body

- [ ] **Step 1: Draft the release asset list**

Include:

- the exact tagged source snapshot,
- the unsigned macOS zip if Task 1 passed,
- no iOS `.ipa`.

- [ ] **Step 2: Draft macOS user instructions**

Explain first-launch behavior for an unsigned app.

- [ ] **Step 3: Draft iOS user instructions**

Explain source download, Xcode workspace usage, bundle identifier replacement, team selection, and self-signing.

- [ ] **Step 4: Upload the macOS asset only if verification passed**

If the macOS app is unsigned and free of personal identifiers, upload the zip to the GitHub Release. Otherwise, skip the upload and state why.

- [ ] **Step 5: Return the final release outcome**

State clearly whether:

- the macOS unsigned zip was uploaded,
- the macOS zip was blocked by signing/identity concerns,
- the iOS path is source-only as intended.

No commit for this task.
