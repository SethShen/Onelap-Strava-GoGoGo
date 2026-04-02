# OTM FIT Download Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the old OneLap FIT list/download flow with the verified OTM list, detail, and `fit_content` download endpoints while preserving sync dedupe behavior.

**Architecture:** `OneLapClient` becomes OTM-first: it will fetch and cache an OTM token from login, page through OTM ride records, hydrate records through the OTM detail endpoint, and download FIT binaries only from the OTM `fit_content` endpoint. The sync engine contract stays the same, while tests shift from old URL fallback behavior to OTM-native behavior and validation.

**Tech Stack:** Flutter, Dart, Dio, flutter_test

---

### Task 1: Add failing tests for OTM list and pagination

**Files:**
- Modify: `test/services/onelap_client_test.dart`
- Test: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests covering:
- OTM list parsing from `POST /api/otm/ride_record/list`
- pagination stop when records are older than `since`
- detail hydration through `GET /api/otm/ride_record/analysis/{id}`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "OneLapClient.listFitActivities"`
Expected: FAIL because implementation still uses the old list path.

- [ ] **Step 3: Write minimal implementation**

Modify `lib/services/onelap_client.dart` to:
- fetch OTM token for authenticated requests,
- call OTM list endpoint,
- page until stop conditions are met,
- hydrate each record through OTM detail,
- map detail to `OneLapActivity`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "OneLapClient.listFitActivities"`
Expected: PASS

### Task 2: Add failing tests for OTM download and validation

**Files:**
- Modify: `test/services/onelap_client_test.dart`
- Test: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests covering:
- `fit_content` download path using base64 UTF-8 encoded `fitUrl`
- rejection of JSON payloads
- rejection of empty body
- rejection of invalid non-FIT payloads
- one retry after `401/403`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "OneLapClient.downloadFit"`
Expected: FAIL because implementation still uses old download candidates.

- [ ] **Step 3: Write minimal implementation**

Modify `lib/services/onelap_client.dart` to:
- base64-encode `fitUrl` exactly like OTM web,
- request `/api/otm/ride_record/analysis/fit_content/{encodedFitUrl}`,
- validate downloaded bytes before accepting them,
- keep SHA-256 file dedupe behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "OneLapClient.downloadFit"`
Expected: PASS

### Task 3: Align data model with OTM detail data

**Files:**
- Modify: `lib/models/onelap_activity.dart`
- Modify: `lib/services/onelap_client.dart`
- Test: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Write the failing test**

Add or update a test asserting:
- legacy-compatible `recordKey` prefers `fileKey:` then `fitUrl:`
- OTM id is retained where useful for diagnostics or hydration

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "recordKey"`
Expected: FAIL if model/mapper is not aligned.

- [ ] **Step 3: Write minimal implementation**

Update `OneLapActivity` fields only as needed for the OTM design. Remove fields that are no longer justified.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "recordKey"`
Expected: PASS

### Task 4: Regression coverage for skip-and-continue behavior

**Files:**
- Modify: `test/services/onelap_client_test.dart`
- Modify: `lib/services/onelap_client.dart`

- [ ] **Step 1: Write the failing test**

Add a test where one detail request fails and another succeeds. Assert the successful activity still returns.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "skip"`
Expected: FAIL

- [ ] **Step 3: Write minimal implementation**

Handle per-record detail failure by skipping that record without failing the full list request.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "skip"`
Expected: PASS

### Task 5: Narrow integration check in sync path

**Files:**
- Modify: `lib/services/sync_engine.dart` only if needed
- Test: existing targeted tests

- [ ] **Step 1: Check whether sync diagnostics need a minimal update**

Keep changes minimal. Only adjust failure text if the OTM path changes the useful debug output.

- [ ] **Step 2: Run targeted tests**

Run: `flutter test test/services/onelap_client_test.dart`
Expected: PASS

### Task 6: Format and verify repository state

**Files:**
- Modify: files changed above

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib test`
Expected: Files formatted successfully.

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No analyzer errors.

- [ ] **Step 3: Run full tests**

Run: `flutter test`
Expected: All tests pass.

### Task 7: Build release artifacts

**Files:**
- Build outputs only

- [ ] **Step 1: Build Android APK**

Run: `flutter build apk --release --dart-define=FLUTTER_IMPELLER_ENABLED=false`
Expected: Release APK generated successfully.

- [ ] **Step 2: Build iOS IPA**

Run: `flutter build ipa`
Expected: IPA build completes successfully, or if signing blocks it, capture the exact failure and stop with evidence.
