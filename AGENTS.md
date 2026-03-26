# AGENTS.md

This file gives agentic coding assistants the minimum repository context needed to work safely and consistently in this project.

## Project Snapshot

- App name: `WanSync` / `onelap_strava_sync`
- Stack: Flutter + Dart
- Purpose: sync OneLap FIT files to Strava
- Main app entry: `lib/main.dart`
- Main UI screens: `lib/screens/`
- Core service logic: `lib/services/`
- Domain models: `lib/models/`
- Tests: `test/`

## Repository Layout

- `lib/main.dart` boots the app and wires the root `MaterialApp`
- `lib/screens/` contains user-facing screens such as home, settings, and OAuth flow
- `lib/services/` contains network, persistence, sync, and settings logic
- `lib/models/` contains small immutable data holders
- `test/` contains Flutter tests
- Platform folders (`android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`) should only be edited when the task actually requires platform-specific changes

## Setup Commands

Run from the repository root.

```bash
flutter pub get
```

Useful environment checks:

```bash
flutter --version
dart --version
```

## Build Commands

- Debug run on connected device/emulator: `flutter run`
- Release APK build: `flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false`
- Debug APK build: `flutter build apk --debug`
- Web build if needed: `flutter build web`

Prefer the exact release APK command from `README.md` when validating production Android builds.

## Lint And Static Analysis

- Run analyzer: `flutter analyze`
- Format a file or directory: `dart format lib test`
- Check formatting without rewriting: `dart format --output=none --set-exit-if-changed lib test`

The analyzer config is in `analysis_options.yaml` and currently includes `package:flutter_lints/flutter.yaml`.

## Test Commands

- Run all tests: `flutter test`
- Run a single test file: `flutter test test/widget_test.dart`
- Run a single named test: `flutter test --plain-name "App smoke test"`
- Run tests with expanded output: `flutter test -r expanded`

If you add more tests, prefer running the smallest relevant scope first, then `flutter test` before finishing.

## Recommended Verification Flow

For most code changes:

```bash
dart format lib test
flutter analyze
flutter test
```

For documentation-only changes such as `AGENTS.md`, formatting/analyzer/test runs are optional, but do not claim they passed unless you actually ran them.

## Existing Test Situation

- Current repo has a basic widget smoke test in `test/widget_test.dart`
- There is not yet broad unit coverage for services under `lib/services/`
- For service changes, add focused tests where practical instead of relying only on manual app runs

## Code Style Rules

Follow existing repository patterns first. When the codebase is silent, use standard Dart and Flutter conventions.

### Imports

- Use package imports for Flutter and external packages, e.g. `package:flutter/material.dart`
- Use relative imports for local project files, as the existing code does, e.g. `../services/settings_service.dart`
- Keep imports grouped in this order: Dart SDK, packages, local files
- Avoid unused imports; remove them immediately
- Do not introduce inconsistent import styles within the same file unless there is a strong reason

### Formatting

- Use `dart format`; do not hand-format against the formatter
- Keep files ASCII unless the file already uses Chinese text or the feature requires non-ASCII text
- Respect trailing commas and multiline wrapping produced by the formatter
- Keep whitespace and line breaks conventional rather than clever

### Types And Nullability

- Prefer explicit, concrete types for fields, parameters, locals, and return values when they improve readability
- Match the existing codebase style: explicit field types are common and preferred
- Use nullable types only when `null` is a real state that callers must handle
- Use `required` named parameters for mandatory constructor and method inputs
- Prefer `const` constructors and `const` widget/literal values where possible
- Preserve sound null safety; avoid `!` unless the code has already established the invariant

### Naming

- Types use `UpperCamelCase`
- Methods, variables, parameters, and top-level functions use `lowerCamelCase`
- Private members use a leading underscore, e.g. `_load`, `_syncing`
- Constants use `lowerCamelCase` for public constants and `_lowerCamelCase` for private constants, matching current code
- Storage keys may use all-caps string values when they represent external persisted identifiers, e.g. `ONELAP_USERNAME`
- Name files in `snake_case.dart`

### Widgets And UI

- Keep widgets focused; move non-UI logic into services when it starts growing
- Use `const` widgets aggressively when valid
- Check `mounted` before using `context` after `await` in stateful widgets
- Preserve the current Material 3 setup unless the task explicitly changes app theming
- Follow the existing UI language; the current app contains user-facing Chinese copy and some English documentation

### Services And Business Logic

- Keep network and persistence logic in `lib/services/`, not in widgets
- Prefer small service classes with clear responsibilities, similar to `SettingsService`, `StateStore`, and `SyncEngine`
- Inject dependencies through constructors when a service coordinates other services
- Keep model classes simple and immutable unless mutation is clearly necessary
- Reuse existing abstractions instead of duplicating API or state logic

### Error Handling

- Do not silently swallow errors unless there is an intentional fallback behavior
- Use typed exceptions when callers need to distinguish retryable vs permanent failures, as in `StravaRetriableError`, `StravaPermanentError`, and `OnelapRiskControlError`
- When catching broadly, either convert the error into a user-facing state or rethrow
- Preserve actionable error messages; include remote status/details when they help debugging and are safe to store/display
- In UI code, surface recoverable issues through state or `SnackBar`/dialogs instead of crashing

### State And Persistence

- Keep persisted key names stable once released
- Be careful when changing secure-storage keys in `SettingsService`
- Be careful when changing on-disk state shape in `StateStore`; preserve backward compatibility when possible
- Prefer additive migrations over destructive resets

### Networking

- Existing HTTP clients use `Dio`; follow that unless the task justifies a change
- Keep timeouts explicit
- Handle 4xx and 5xx responses intentionally
- Preserve auth-refresh behavior in `StravaClient`
- Avoid logging secrets, tokens, passwords, or client secrets

## Testing Guidelines For New Work

- Put tests under `test/` using `*_test.dart` filenames
- Prefer narrow unit or widget tests over broad manual-only validation
- For a new single test file, run `flutter test path/to/file_test.dart`
- For one specific test case, run `flutter test --plain-name "exact test name"`
- If you change parsing, dedupe, sync, or persistence logic, add regression coverage when practical

## Change Hygiene For Agents

- Read the surrounding file before editing; follow local patterns
- Make the smallest change that fully solves the task
- Do not rewrite unrelated files just to satisfy personal style preferences
- Do not remove or rename persisted keys, public methods, or user-visible copy without a task-driven reason
- If a task touches secrets or OAuth behavior, double-check for accidental credential exposure

## Git Guidance

- Check the worktree state before committing
- Ignore unrelated local modifications unless the task requires coordinating with them
- Do not overwrite user changes you did not make
- Do not amend existing commits unless explicitly requested
- Do not use destructive git commands unless explicitly requested

## Repo-Specific Notes

- `README.md` is bilingual Chinese/English; preserve that style when editing it
- The app currently uses relative imports for internal files; keep that convention for consistency
- The app theme seed color is deep orange in `lib/main.dart`; preserve current branding unless asked to change it
- Recent commits use concise imperative commit messages, e.g. `Fix disclaimer...`, `Show About dialog...`

## Cursor And Copilot Rules

Checked locations:

- `.cursor/rules/`
- `.cursorrules`
- `.github/copilot-instructions.md`

At the time this file was written, none of those rule files existed in this repository. If any are added later, update this `AGENTS.md` to incorporate their instructions.

## When In Doubt

- Prefer repo consistency over generic best practices
- Prefer small, verifiable changes over large refactors
- Run the narrowest useful test first, then broader verification
- Leave clear diffs for the next agent
