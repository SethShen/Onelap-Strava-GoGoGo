# Design: Android 1.0.9 Release

**Date:** 2026-04-02  
**Status:** Draft  
**Scope:** Version bump, Android APK build, and GitHub Release publication for version 1.0.9

## Goal

Publish a new Android release for this project by:

1. updating the app version from `1.0.8+8` to `1.0.9+9`,
2. building a release APK from the updated source,
3. creating a new GitHub Release for `1.0.9`,
4. uploading the built APK as the release asset.

## Chosen Approach

Use the version declared in `pubspec.yaml` as the single source of truth.

The release will be prepared by editing `pubspec.yaml` directly to `1.0.9+9`, committing that version change so the tagged source matches the release contents, then running the normal verification flow, then building the Android release APK with the repository's documented command:

```bash
flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false
```

After the build succeeds, create a GitHub Release for tag `v1.0.9` and attach the generated APK.

## Why This Approach

- It keeps the release version visible in source control.
- It ensures Flutter's `build-name` and Android `versionCode` both advance together.
- It avoids a mismatch between the repository version, built artifact, and published release.

## Alternatives Considered

### 1. Override version only at build time

Rejected because the repository would still show `1.0.8+8` while the published APK and release would claim `1.0.9`.

### 2. Bump only the display version and keep build number unchanged

Rejected because Android releases should keep incrementing the build number (`versionCode`) for clean upgrades.

### 3. Create the GitHub Release before building

Rejected because the release should only be published after verification and successful artifact generation.

## Execution Design

### Versioning

Update `pubspec.yaml`:

- from `version: 1.0.8+8`
- to `version: 1.0.9+9`

Commit the `pubspec.yaml` change before creating the release tag so the source snapshot referenced by the release already contains `1.0.9+9`.

No other persisted version sources should be changed unless the build tooling proves they are derived separately.

### Verification

Run the standard repository checks before publishing:

```bash
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

If any of these fail, stop before creating the release and report the blocker.

### APK Build

Build the Android release APK with:

```bash
flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false
```

Expected output artifact:

```text
build/app/outputs/flutter-apk/app-release.apk
```

### GitHub Release

Create a new GitHub Release using tag `v1.0.9` as the release identity.

Release expectations:

- tag: `v1.0.9`, matching existing repository tags `v1.0.0` through `v1.0.8`,
- title: `v1.0.9`,
- asset: the built Android APK,
- body: concise release notes for this version.

## Error Handling

- If formatting, analysis, or tests fail, do not publish the release.
- If APK build fails, do not create or update the release.
- If GitHub authentication or release creation fails, keep the built APK locally and report the exact failure.
- If the target release tag already exists, inspect it first and only update it if that is clearly intended by the user or necessary for completion.

## Files Expected To Change

| File | Change |
|---|---|
| `pubspec.yaml` | Bump version to `1.0.9+9` |
| Git commit / tag / GitHub Release metadata | Commit version bump, then create release `v1.0.9` |

## Non-Goals

- modifying app behavior beyond version metadata,
- changing iOS, macOS, Windows, Linux, or web release packaging,
- introducing CI automation for releases.
