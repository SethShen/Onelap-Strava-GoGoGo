# Android Flutter App Design

**Date:** 2026-03-25  
**Status:** Draft  
**Goal:** Package the OneLap → Strava sync logic into an Android app built with Flutter.

---

## 1. Overview

The existing Python CLI tool syncs FIT activity files from the OneLap platform to Strava. This design adds a Flutter-based Android app that replicates the same sync logic in Dart, packaged as an APK installable on any Android phone.

**Scope for v1 (this spec):**
- Single-page UI with a "Sync Now" button and result display
- Settings screen to enter OneLap credentials and Strava tokens (manual paste)
- Core sync logic: OneLap login → list activities → download FIT → upload to Strava → deduplicate
- Persistent sync state (which activities have already been uploaded)

**Out of scope for v1:**
- Strava OAuth WebView flow (planned for v2)
- Automatic scheduled sync / background service
- Sync history screen

---

## 2. Project Structure

A new `android/` subdirectory is added at the repo root. The existing Python code is not modified.

```
onelap-strava-sync/
  src/sync_onelap_strava/          ← existing Python (unchanged)
  android/                         ← new Flutter project
    lib/
      main.dart                    ← app entry point, MaterialApp
      screens/
        home_screen.dart           ← "Sync Now" button + result display
        settings_screen.dart       ← credential input form
      services/
        onelap_client.dart         ← Dart port of onelap_client.py
        strava_client.dart         ← Dart port of strava_client.py
        sync_engine.dart           ← Dart port of sync_engine.py
        state_store.dart           ← Dart port of state_store.py
        dedupe_service.dart        ← Dart port of dedupe_service.py
        settings_service.dart      ← read/write credentials from secure storage
      models/
        onelap_activity.dart       ← OneLapActivity data class
        sync_summary.dart          ← SyncSummary data class
    pubspec.yaml
    android/
      app/src/main/AndroidManifest.xml  ← internet permission
```

---

## 3. UI Design

### Home Screen (`home_screen.dart`)

Minimal single-page layout:

```
┌─────────────────────────────────┐
│  OneLap → Strava Sync           │  ← AppBar
├─────────────────────────────────┤
│                                 │
│  上次同步: 2026-03-24 08:32     │  ← last sync time (from state store)
│                                 │
│  ┌───────────────────────┐      │
│  │     立即同步           │      │  ← ElevatedButton, disabled during sync
│  └───────────────────────┘      │
│                                 │
│  [CircularProgressIndicator]    │  ← shown during sync
│                                 │
│  获取: 3  去重: 1               │  ← result shown after sync
│  成功: 2  失败: 0               │
│                                 │
│  [error message if any]         │
│                                 │
└─────────────────────────────────┘
  ⚙ Settings                       ← IconButton in AppBar navigates to Settings
```

Lookback period is fixed at 3 days (not user-configurable in v1, matching the Python default).

- Button is disabled and a spinner shown while sync is in progress.
- On success, displays `SyncSummary` counts.
- On fatal error (missing credentials, network failure), displays the error message in red.
- If `aborted_reason == "risk-control"`, shows a specific warning message.

### Settings Screen (`settings_screen.dart`)

Two sections, each with labeled text fields and a Save button:

**OneLap 账号**
- Username (text)
- Password (obscured text)

**Strava 凭证**
- Client ID (text)
- Client Secret (obscured text)
- Refresh Token (text)
- Access Token (text)
- Expires At (text, Unix timestamp)

Save button writes all values to secure storage and shows a SnackBar confirmation. Fields are pre-filled from stored values on load.

---

## 4. Business Logic (Dart Ports)

Each Python module is ported 1:1 to Dart. Behavior is identical; only the language changes.

### `onelap_client.dart`

- `login()`: POST `https://www.onelap.cn/api/login` with MD5-hashed password, using `dio` cookie jar to maintain session.
- `listFitActivities(since, limit)`: GET `http://u.onelap.cn/analysis/list`; parse response; filter by `since` date; return `List<OneLapActivity>`.
- Auto-retry with login on 401/HTML response (max 1 retry), same as Python.
- `downloadFit(recordKey, outputDir)`: stream download FIT file to app cache directory; SHA-256 dedup to avoid overwriting identical files; return local `File` path.
- `_buildRecordIdentity()`: same priority as Python (`fileKey` > `fitUrl` > `durl`).

**Dart package:** `dio` + `dio_cookie_manager` + `cookie_jar` for session cookie handling.  
**MD5:** `crypto` package (`md5` function).

### `strava_client.dart`

- `ensureAccessToken()`: check `expires_at` vs current time; if expired, POST `https://www.strava.com/oauth/token` with `grant_type=refresh_token`; save new tokens to secure storage.
- `uploadFit(file)`: POST `https://www.strava.com/api/v3/uploads` as multipart with `data_type=fit`; retry up to 3 times on 5xx; raise on 4xx.
- `pollUpload(uploadId)`: GET status up to 10 times with 2s interval; return final payload map.

**Dart package:** `dio` for HTTP.

### `sync_engine.dart`

- `runOnce(sinceDate)`: identical logic to Python `SyncEngine.run_once()`.
  1. Fetch activity list from OneLap.
  2. For each: download FIT → compute fingerprint → check state store.
  3. If already synced: increment `deduped`.
  4. Else: upload to Strava → poll.
  5. If Strava "duplicate of" error: treat as deduped, record in state.
  6. Return `SyncSummary`.
- Catches `OnelapRiskControlError`, returns `SyncSummary(abortedReason: "risk-control")`.

### `dedupe_service.dart`

```dart
String makeFingerprint(File file, String startTime, String recordKey) async {
  final bytes = await file.readAsBytes();  // async I/O, do not use readAsBytesSync
  final hash = sha256.convert(bytes).toString();
  return '$recordKey|$hash|$startTime';
}
```

**Dart package:** `crypto` for SHA-256.

### `state_store.dart`

- Backed by a JSON file in `getApplicationDocumentsDirectory()` named `state.json`.
- Same format as Python `state.json`.
- Methods: `isSynced(fingerprint)`, `markSynced(fingerprint, stravaActivityId)`, `lastSuccessSyncTime()`.

### `settings_service.dart`

- Wraps `flutter_secure_storage`.
- Methods: `saveSettings(map)`, `loadSettings() → Map<String, String>`.
- Keys: `ONELAP_USERNAME`, `ONELAP_PASSWORD`, `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, `STRAVA_REFRESH_TOKEN`, `STRAVA_ACCESS_TOKEN`, `STRAVA_EXPIRES_AT`.

---

## 5. Dependencies (`pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `dio` | `^5.0.0` | HTTP client |
| `dio_cookie_manager` | `^3.0.0` | Session cookie handling for OneLap |
| `cookie_jar` | `^4.0.0` | Cookie storage |
| `crypto` | `^3.0.0` | MD5 (OneLap login) + SHA-256 (fingerprint) |
| `flutter_secure_storage` | `^9.0.0` | Encrypted credential storage |
| `path_provider` | `^2.0.0` | App cache + documents directory |

**State management:** No state management library. Use Flutter's built-in `setState` — the UI is simple enough.

---

## 6. Android Manifest

Add `INTERNET` permission in `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

OneLap activity list endpoint uses HTTP (not HTTPS). Add `usesCleartextTraffic` to allow plain HTTP:

```xml
<application android:usesCleartextTraffic="true" ...>
```

---

## 7. Error Handling

| Scenario | Behavior |
|---|---|
| Missing credentials | Show "请先在设置中填写凭证" on home screen |
| OneLap login fails | Show error message from exception |
| OneLap risk control | Show "OneLap 风控拦截，请稍后再试" |
| Strava token expired | Auto-refresh silently; save new tokens to secure storage |
| Strava 4xx permanent error | Show error detail, increment `failed` count |
| Strava 5xx retriable | Retry 3× with 1s backoff; if still failing, show error |
| Network timeout | Show generic network error message |

---

## 8. Data Flow

```
User taps "立即同步"
  │
  ▼
SyncEngine.runOnce(since: today - 3 days)
  │
  ├─ OneLapClient.login()          → POST /api/login (MD5 password)
  ├─ OneLapClient.listFitActivities() → GET u.onelap.cn/analysis/list
  │
  └─ for each activity:
       │
       ├─ OneLapClient.downloadFit() → stream to cache dir
       ├─ makeFingerprint()          → recordKey|sha256|startTime
       ├─ StateStore.isSynced()      → check state.json
       │
       └─ if not synced:
            ├─ StravaClient.ensureAccessToken() → refresh if needed
            ├─ StravaClient.uploadFit()         → POST /api/v3/uploads
            ├─ StravaClient.pollUpload()        → GET /api/v3/uploads/{id}
            └─ StateStore.markSynced()          → write state.json
  │
  ▼
Display SyncSummary on home screen
```

---

## 9. Build & Distribution

```bash
cd android/
flutter pub get
flutter build apk --release
# Output: android/build/app/outputs/flutter-apk/app-release.apk
```

Install on device via USB (`flutter install`) or transfer APK directly.

---

## 10. Future Work (v2)

- Strava OAuth WebView: embedded WebView opens `https://www.strava.com/oauth/authorize`, intercepts redirect callback, exchanges code for tokens automatically.
- Auto scheduled sync: Android `WorkManager` periodic task, runs sync every N hours in background.
- Sync history screen: list of past sync runs with counts and timestamps.
