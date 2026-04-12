# OTM MATCH FIT Fallback Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the existing OTM FIT fallback so OneLap records with approved `MATCH_*` identifiers can download through `fit_content` after standard download URLs fail.

**Architecture:** Keep the current download orchestration unchanged. Make a small internal change inside `OneLapClient` so OTM fallback path extraction accepts both existing geo-based identifiers and the new approved `MATCH_*` shape, then prove the behavior through public `downloadFit(...)` regression tests.

**Tech Stack:** Flutter, Dart, Dio, existing `flutter test` unit test suite

---

## File Map

### Modified files

- `lib/services/onelap_client.dart`
  - Keep `_otmFitPath()` as the fallback entrypoint.
  - Add a tiny private helper for allowlisted fallback identifier recognition.
  - Preserve current request flow and token handling.
- `test/services/onelap_client_test.dart`
  - Add a regression for `MATCH_*` fallback through the public `downloadFit(...)` API.
  - Add a negative regression for unknown non-geo, non-`MATCH_*` identifiers.

### Unchanged by design

- `lib/services/sync_engine.dart`
  - No sync orchestration changes.
- `lib/models/onelap_activity.dart`
  - No model changes.
- `lib/services/sync_failure_formatter.dart`
  - No error copy changes.

## Task 1: Add the failing MATCH fallback regression

**Files:**
- Modify: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Write the failing MATCH fallback test**

Add a test next to the existing OTM fallback tests that:

- creates a `OneLapClient` with fake Dio transport
- forces standard download URLs to fail with `404`
- uses an activity whose `rawFileKey` is
  `MATCH_677767-2026-04-09-21-09-29-log.st`
- keeps the other fallback candidates non-matching so the test proves the
  current candidate ordering still works and the new allowlist change is what
  enables fallback
- expects the client to request:
  `https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/<base64(MATCH_677767-2026-04-09-21-09-29-log.st)>`
- expects the downloaded bytes to equal the fake OTM response body

- [ ] **Step 2: Run the focused fallback test to verify it fails**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "falls back to OTM fit content download for MATCH identifiers after standard URLs fail"`

Expected: FAIL because the current `_otmFitPath()` rejects `MATCH_*`.

## Task 2: Add the failing negative regression for unsupported identifiers

**Files:**
- Modify: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Write the negative regression**

Add a test that:

- creates an activity whose fallback candidate is an unknown non-empty string such as `sample.fit`
- forces standard download URLs to fail
- asserts that no OTM `fit_content` request is made
- asserts that `downloadFit(...)` still fails instead of silently treating the value as fallback-safe

- [ ] **Step 2: Run the negative regression before implementation**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "does not treat unsupported identifiers as OTM fit content fallback candidates"`

Expected: PASS.

- [ ] **Step 3: Re-run the MATCH regression before implementation**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "falls back to OTM fit content download for MATCH identifiers after standard URLs fail"`

Expected:

- FAIL because the current `_otmFitPath()` rejects `MATCH_*`.

## Task 3: Implement the minimal allowlist helper in `OneLapClient`

**Files:**
- Modify: `lib/services/onelap_client.dart`
- Test: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Implement the smallest safe production change**

Update `lib/services/onelap_client.dart` to:

- keep `_otmFitPath()` as the candidate iteration entrypoint
- add a tiny private helper that normalizes and validates one candidate value
- keep existing geo behavior unchanged:
  - raw `geo/...`
  - URL path normalized from `/geo/...`
- add approved `MATCH_*` handling only when the raw value:
  - starts with case-sensitive `MATCH_`
  - has no URI scheme
  - has no leading slash
  - has no whitespace
  - has no `/`
  - has no `?` or `#`
- return the original raw `MATCH_*` value unchanged when accepted
- leave direct download ordering, token fetching, base64 encoding, and byte-writing flow untouched

- [ ] **Step 2: Run the focused MATCH fallback regression**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "falls back to OTM fit content download for MATCH identifiers after standard URLs fail"`

Expected: PASS.

- [ ] **Step 3: Run the negative regression**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "does not treat unsupported identifiers as OTM fit content fallback candidates"`

Expected: PASS.

## Task 4: Re-run the existing geo regressions

**Files:**
- Modify: none
- Test: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Run the existing geo fallback regression**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "falls back to OTM fit content download after standard URLs fail"`

Expected: PASS.

- [ ] **Step 2: Run the absolute geo URL regression**

Run: `flutter test test/services/onelap_client_test.dart --plain-name "uses absolute geo URL path for OTM fit content fallback"`

Expected: PASS.

- [ ] **Step 3: Run the full `OneLapClient` test file**

Run: `flutter test test/services/onelap_client_test.dart`

Expected: PASS.

## Task 5: Run repository verification for the scoped change

**Files:**
- Modify: none

- [ ] **Step 1: Format the touched code**

Run: `dart format lib/services/onelap_client.dart test/services/onelap_client_test.dart`

Expected: formatter completes successfully.

- [ ] **Step 2: Verify formatting is stable**

Run: `dart format --output=none --set-exit-if-changed lib/services/onelap_client.dart test/services/onelap_client_test.dart`

Expected: exit code 0.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze`

Expected: no new analyzer issues.

- [ ] **Step 4: Run the full test suite**

Run: `flutter test`

Expected: PASS.

## Task 6: Prepare the change for review

**Files:**
- Modify: `lib/services/onelap_client.dart`
- Modify: `test/services/onelap_client_test.dart`

- [ ] **Step 1: Review the final diff for scope control**

Confirm the diff only contains:

- the small allowlist helper and `_otmFitPath()` adjustment
- the new MATCH fallback regression
- the new negative regression

Confirm it does not contain unrelated cleanup or behavior changes.

- [ ] **Step 2: Summarize verification evidence**

Capture the exact commands run and whether each passed:

- `flutter test test/services/onelap_client_test.dart`
- `dart format ...`
- `flutter analyze`
- `flutter test`

- [ ] **Step 3: Commit when explicitly requested**

If the user asks for a commit, stage only the intended files and create a concise message such as:

`Allow OTM MATCH fit fallback`
