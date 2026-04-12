# OTM MATCH FIT Fallback Design

## Goal

Fix OneLap sync for records whose OTM detail payload exposes FIT download data as
`MATCH_...` identifiers instead of `geo/...` paths.

The design keeps the existing fallback mechanism but broadens the allowed OTM
path patterns in a controlled way.

## Current State

`lib/services/onelap_client.dart` currently tries direct FIT downloads first and
falls back to OTM `fit_content` only when direct downloads fail.

The current fallback path extraction is intentionally narrow:

- `OneLapClient._downloadViaOtmFallback()` calls `_otmFitPath()`
- `_otmFitPath()` only accepts:
  - raw values that start with `geo/`
  - URL paths that start with `/geo/`

This works for traditional OneLap records whose fallback-compatible identifier is
a geo path, but it rejects records whose detail payload uses values such as
`MATCH_677767-2026-04-09-21-09-29-log.st`.

Browser investigation confirmed that these records are still downloadable through
the same OTM endpoint:

- `GET /api/otm/ride_record/analysis/fit_content/<base64(fitUrl)>`

For the failing example, OTM returned a valid FIT payload with
`content-type: application/octet-stream` and a `.fit` filename.

## Chosen Approach

Keep the existing OTM fallback flow, but replace the hard-coded `_otmFitPath()`
pattern check with a small internal rule layer.

The new rule layer allows three explicit input forms:

- `geo/...`
- URL paths whose normalized path is `geo/...`
- raw values that match `MATCH_*`

The fallback still uses the current request flow:

1. Extract an allowed fallback identifier from activity fields
2. Base64-encode that identifier
3. Call OTM `fit_content/<encoded>` with the existing token flow
4. Write the returned bytes to the temp FIT path

## Why This Approach

This is the smallest change that still improves maintainability.

- It fixes the confirmed bug without broadening fallback to all non-empty
  `fitUrl` values
- It keeps the allowlist explicit and easy to audit
- It gives the code a single place to add future approved patterns if more OTM
  variants appear
- It does not alter sync orchestration, dedupe, or Strava upload behavior

## Alternatives Considered

### 1. Minimal inline change

Add a direct `MATCH_` check inside `_otmFitPath()` and leave the rest as-is.

Pros:

- Smallest code diff

Cons:

- Pattern rules remain embedded in one function
- Future additions become harder to reason about

### 2. Selected approach: small explicit allowlist helper

Extract the fallback-allowed pattern logic into a tiny private helper and keep
`_otmFitPath()` as the candidate selection entrypoint.

Pros:

- Still a very small change
- Clearer separation between candidate selection and pattern acceptance
- Easier to cover through focused `OneLapClient` regression tests without
  changing public API

Cons:

- Slightly more code than the inline patch

### 3. Broad acceptance of any non-empty `fitUrl`

Treat any non-empty candidate as acceptable for OTM `fit_content`.

Pros:

- Largest compatibility surface

Cons:

- Too permissive for the currently verified evidence
- Higher regression risk for unknown OneLap value shapes
- Not aligned with the requested scoped fix

## Scope

This change is intentionally limited to OneLap OTM fallback path recognition.

Included:

- Support `MATCH_*` fallback identifiers
- Preserve existing `geo/...` fallback support
- Add regression tests for the new allowlist behavior

Excluded:

- Changes to OneLap activity list parsing
- Changes to direct download URL selection
- Changes to error message wording
- Broad support for unknown non-geo identifier families

Direct download ordering remains unchanged. `MATCH_*` records may still hit the
existing standard download attempts first and only enter OTM fallback after
those attempts fail.

## Design Details

### File

- `lib/services/onelap_client.dart`

### Structure

Keep `_otmFitPath(OneLapActivity activity)` as the public internal entrypoint for
OTM fallback extraction.

Add a small private helper that evaluates a single candidate string and returns a
normalized fallback identifier when the value is explicitly allowed.

Expected helper behavior:

- Input: raw candidate string
- Output:
  - normalized `geo/...` path when candidate is geo-based
  - original raw value when candidate matches the approved `MATCH_*` shape
  - `null` when candidate is not fallback-safe

`_otmFitPath()` continues to iterate through existing candidate fields in this
order:

- `activity.rawFileKey`
- `activity.rawFitUrl`
- `activity.rawFitUrlAlt`
- `activity.fitUrl`

The first candidate accepted by the helper is returned.

### Pattern Rules

Allowed candidate forms:

1. Exact raw prefix `geo/`
2. URL path whose normalized path becomes `geo/...`
3. A raw value that:
   - starts with case-sensitive `MATCH_`
   - contains no URI scheme
   - contains no leading slash
   - contains no whitespace
   - contains no `/`
   - contains no query string or fragment markers such as `?` or `#`

Rejected candidate forms:

- Empty strings
- Arbitrary filenames without an approved prefix
- Unknown identifiers that are neither geo-based nor `MATCH_*`

### Request Flow

No request-shape changes are needed.

`_downloadViaOtmFallback()` should continue to:

- fetch the OTM token through `_fetchOtmToken()`
- base64-encode the returned fallback identifier
- call `/api/otm/ride_record/analysis/fit_content/<encoded>`
- require a non-empty byte body before writing the temp file

## Testing

Add focused regression coverage in `test/services/onelap_client_test.dart`.

The helper remains private. Tests should verify public `OneLapClient` behavior
through `downloadFit(...)` and the resulting request sequence rather than
calling internal helpers directly.

Required test cases:

1. Existing regression coverage keeps `geo/...` fallback working
2. Existing regression coverage keeps absolute geo URL fallback working
3. A new regression forces standard downloads to fail for a `MATCH_...log.st`
   activity and asserts that the client requests:
   `https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/<base64(raw MATCH value)>`
4. The new regression asserts that the encoded OTM value is the original raw
   `MATCH_...` identifier, unchanged
5. A negative regression confirms that an unknown non-empty non-geo,
   non-`MATCH_*` candidate still does not become an OTM fallback identifier

The tests should stay narrow and avoid unrelated sync-engine or Strava behavior.

## Risks And Mitigations

### Risk: allowing a wrong identifier family

Mitigation:

- Only add explicit `MATCH_*`
- Keep rejection as the default for unknown values

### Risk: breaking existing geo fallback support

Mitigation:

- Preserve current geo recognition rules unchanged
- Add regression tests for both raw and URL-based geo inputs

### Risk: future OTM variants still fail

Mitigation:

- The helper isolates the allowlist in one place
- Future additions can be made deliberately without reopening the whole fallback
  design

## Verification Plan

After implementation, verify with:

1. A unit test run covering the new `OneLapClient` fallback cases
2. `dart format lib test`
3. `flutter analyze`
4. `flutter test`

## Expected Outcome

Records whose OTM payload uses `MATCH_*` FIT identifiers will be able to fall
back through `fit_content` in the same way that geo-path-based records already
do.

The resulting behavior remains deliberately scoped and consistent with the
repository's preference for small, explicit, low-risk changes.
