# Design: OTM FIT Download Redesign

**Date:** 2026-04-01  
**Status:** Draft  
**Scope:** `lib/services/onelap_client.dart`, `lib/models/onelap_activity.dart`, `test/services/onelap_client_test.dart`, sync path integration

## Goal

Replace the current OneLap FIT retrieval flow with a new OTM-first implementation that uses the real OTM web endpoints for:

1. listing ride records,
2. loading per-record detail,
3. downloading the actual FIT binary.

The new flow must stop depending on the old `u.onelap.cn/analysis/list` activity source and stop treating OTM analysis JSON as a FIT download.

## Verified OTM Endpoints

Using the real OTM web app with a real account, the following endpoints were confirmed:

### Record List

`POST https://otm.onelap.cn/api/otm/ride_record/list`

Returns paginated ride summaries including:

- `id`
- `start_riding_time`
- distance and duration summary fields

### Record Detail

`GET https://otm.onelap.cn/api/otm/ride_record/analysis/{id}`

Returns `data.ridingRecord`, which includes the fields needed for sync:

- `_id`
- `id`
- `startRidingTime`
- `fileKey`
- `fitUrl`
- `durl`

### FIT Binary Download

`GET https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/{base64Utf8(fitUrl)}`

Headers:

- `Authorization: <token>`

Observed response shape:

- `Content-Type: application/octet-stream`
- `Content-Disposition: attachment; filename="...fit"`
- body is real FIT binary data

### Non-Download Analysis Endpoint

`GET https://otm.onelap.cn/api/otm/ride_record/analysis/fit/{base64Utf8(fitUrl)}`

This returns JSON analysis points, not FIT bytes. The app must not use this endpoint for file download.

## Chosen Architecture

### Authentication Model

Keep using the existing OneLap login credentials from settings, but shift runtime access to OTM token-based requests.

`OneLapClient` should log in once, extract the OTM `token` from the login response, and use that token on all OTM API requests.

This token shape is already reflected by the current `_fetchOtmToken()` implementation, which reads `payload.data.first.token` from the existing login response.

The redesign must keep a bounded re-login path:

1. attempt request with cached token,
2. if OTM returns `401` or `403`, perform one fresh login,
3. retry the request once,
4. if it still fails, surface an authentication error.

Cookie-based fallback behavior that exists only to support the old site is no longer part of the primary design.

### Activity Discovery Flow

Replace the current old-site list fetch with this sequence:

```text
login
  -> get OTM token
  -> POST /api/otm/ride_record/list
  -> filter records by since date
  -> for each candidate record, GET /api/otm/ride_record/analysis/{id}
  -> build OneLapActivity from ridingRecord
```

The detail request is part of the core design, not an optional fallback, because it is the stable source of `fitUrl`, `fileKey`, and `durl`.

Because the list endpoint is paginated, the implementation must page until one of these stop conditions is met:

1. the returned page is empty,
2. the configured `limit` has been satisfied,
3. the page contains only records older than `since`.

The implementation should request pages in the same newest-first order used by the web app. If the endpoint does not expose explicit sort options, preserve the server order and stop only after condition 1, 2, or 3 is reached.

### FIT Download Flow

Replace the current multi-host URL guessing flow with this OTM-specific sequence:

```text
activity.fitUrl
  -> base64 UTF-8 encode fitUrl exactly like OTM web
  -> GET /api/otm/ride_record/analysis/fit_content/{encodedFitUrl}
  -> save response bytes as .fit
```

`durl` may still be kept in the model for debugging, but it is no longer the primary download path.

## Data Model Changes

### `OneLapActivity`

Keep the model small, but shift it toward OTM-native fields.

Required fields should remain:

- `activityId`
- `startTime`
- `fitUrl`
- `recordKey`
- `sourceFilename`

Raw/debug fields should be updated to reflect OTM detail data rather than old mixed sources. The useful retained fields are:

- `rawDurl`
- `rawFileKey`
- OTM record identifier if separate from `activityId`

The old `rawFitUrlAlt` field is only justified if still needed by tests or temporary migration work. If not needed after the redesign, it should be removed instead of carried forward.

### Record Identity

`recordKey` must remain compatible with existing dedupe fingerprints.

Recommended priority:

1. `fileKey:<fileKey>` when `fileKey` exists,
2. `fitUrl:<fitUrl>` when `fileKey` is missing,
3. `_id:<otm _id>` only when neither `fileKey` nor `fitUrl` exists.

This keeps the identity stable for the new OTM flow while avoiding a migration that would cause already-synced activities to appear new and be re-uploaded to Strava.

## Service Changes

### `OneLapClient.login()`

Update the login path so it can return or cache the OTM token needed for API calls. The design does not require a second login just to fetch the token if the original login response already includes it.

### `OneLapClient.listFitActivities()`

New behavior:

1. ensure authenticated OTM token,
2. call OTM list endpoint page by page,
3. stop paging when the page is empty, the limit is reached, or all items in a page are older than `since`,
4. hydrate each candidate through OTM detail endpoint,
5. map detail response into `OneLapActivity`.

The method should continue returning a flat `List<OneLapActivity>` so the sync engine interface does not need to change.

### `OneLapClient.downloadFit()`

New behavior:

1. derive encoded path from `activity.fitUrl`,
2. call OTM `fit_content` endpoint with `Authorization` header,
3. write bytes to temp file,
4. reuse existing SHA-256 dedupe and rename behavior.

The existing local file dedupe logic is still useful and should be retained.

## Validation Rules

Downloaded content must be validated before being accepted as a FIT file.

Minimum validation:

1. response body is non-empty,
2. response does not look like JSON or HTML,
3. bytes contain a valid FIT header signature near the beginning.

If validation fails, throw a clear error that includes the endpoint used and the detected content type when available.

This protects the sync pipeline from silently uploading the wrong content.

## Error Handling

### Token Problems

If OTM token retrieval fails or an OTM endpoint returns `401` or `403`, perform one re-login and one retry. If the retry still fails, surface a clear login/authentication failure.

### Detail Hydration Failure

If one record summary is listed but its detail fetch fails, skip that record and continue with the remaining records.

The redesign does not require new `SyncSummary` fields or a new diagnostics channel during list hydration. Logging/detail surfacing beyond existing sync behavior is out of scope unless a minimal implementation naturally supports it.

### Download Failure

If `fit_content` returns non-200, empty bytes, or invalid FIT content, treat it as a hard download failure for that activity.

### Risk Control

If the new OTM endpoints return a recognizable risk-control response, continue mapping that to `OnelapRiskControlError` so the existing sync summary behavior remains intact.

## Testing Strategy

### Replace Old Mainline Tests

The current tests are centered on `durl`, `fit_url`, host fallback, and old geo-path expansion. Those should no longer define the mainline behavior.

### Add OTM-Focused Tests

Add focused tests for:

1. `listFitActivities()` parses `POST /api/otm/ride_record/list`,
2. `listFitActivities()` paginates until the limit or `since` stop condition is reached,
3. `listFitActivities()` hydrates records through `GET /api/otm/ride_record/analysis/{id}`,
4. one detail request can fail while other listed records still hydrate and return successfully,
5. OTM `401/403` triggers one re-login and one retry,
6. `downloadFit()` requests `GET /api/otm/ride_record/analysis/fit_content/{base64Utf8(fitUrl)}`,
7. `downloadFit()` saves returned binary bytes successfully,
8. `downloadFit()` rejects JSON analysis payloads,
9. `downloadFit()` rejects empty-body responses,
10. `downloadFit()` rejects non-empty payloads with missing or invalid FIT header signature,
11. risk-control responses still map to `OnelapRiskControlError`,
12. `recordKey` preserves legacy-compatible `fileKey:` / `fitUrl:` identity when available.

Tests should continue to use the fake Dio adapter pattern already present in `test/services/onelap_client_test.dart`.

## What Does Not Change

- `SyncEngine.runOnce()` public behavior
- local SHA-256 duplicate file handling inside `downloadFit()`
- Strava upload flow
- secure settings storage for username/password

## Files Expected To Change

| File | Change |
|---|---|
| `lib/services/onelap_client.dart` | Replace list/download logic with OTM list, detail, and fit_content flow |
| `lib/models/onelap_activity.dart` | Align fields with OTM-native data |
| `test/services/onelap_client_test.dart` | Replace old-path tests with OTM-focused tests |
| `lib/services/sync_engine.dart` | Only if failure diagnostics need small updates |

## Non-Goals

- support old `u.onelap.cn` list flow as the primary path,
- keep multi-host geo URL guessing as a first-class download strategy,
- reconstruct FIT files from OTM analysis JSON,
- change Strava upload semantics.
