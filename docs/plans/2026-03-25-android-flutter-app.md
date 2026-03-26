# Android Flutter App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Android app that replicates the OneLap → Strava sync logic, with a single-page UI and a settings screen for credentials.

**Architecture:** A new `android/` Flutter project lives at the repo root. Business logic (OneLap client, Strava client, sync engine, dedup, state store) is ported 1:1 from the existing Python modules into Dart service classes. Two screens: `HomeScreen` (sync button + result) and `SettingsScreen` (credential input). UI state managed with `setState`.

**Tech Stack:** Flutter (Dart), `dio` + `dio_cookie_manager` + `cookie_jar` for HTTP, `crypto` for MD5/SHA-256, `flutter_secure_storage` for credentials, `path_provider` for file paths.

**Spec:** `docs/superpowers/specs/2026-03-25-android-flutter-app-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `android/pubspec.yaml` | Create | Flutter project manifest + dependencies |
| `android/android/app/src/main/AndroidManifest.xml` | Modify | Add INTERNET permission + cleartext traffic |
| `android/lib/main.dart` | Create | App entry point, `MaterialApp` with routes |
| `android/lib/models/onelap_activity.dart` | Create | `OneLapActivity` data class |
| `android/lib/models/sync_summary.dart` | Create | `SyncSummary` data class |
| `android/lib/services/settings_service.dart` | Create | Read/write credentials via `flutter_secure_storage` |
| `android/lib/services/state_store.dart` | Create | JSON-backed sync state persistence |
| `android/lib/services/dedupe_service.dart` | Create | `makeFingerprint()` function |
| `android/lib/services/onelap_client.dart` | Create | OneLap login, list activities, download FIT |
| `android/lib/services/strava_client.dart` | Create | Strava token refresh, FIT upload, poll |
| `android/lib/services/sync_engine.dart` | Create | Core sync loop |
| `android/lib/screens/settings_screen.dart` | Create | Credential input form |
| `android/lib/screens/home_screen.dart` | Create | Sync button + result display |

---

## Task 1: Scaffold Flutter Project

**Files:**
- Create: `android/pubspec.yaml`
- Create: `android/lib/main.dart`
- Modify: `android/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Create the Flutter project scaffold**

Run from repo root:
```bash
flutter create --org cn.onelap --project-name onelap_strava_sync android
```

Expected: Flutter project created in `android/`, with default counter app. Flutter also generates `android/.gitignore` automatically — confirm it exists after scaffolding (it will exclude `build/` already).

- [ ] **Step 2: Replace `pubspec.yaml` dependencies**

Edit `android/pubspec.yaml` — replace the `dependencies:` section with:

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.7.0
  dio_cookie_manager: ^3.1.1
  cookie_jar: ^4.0.8
  crypto: ^3.0.3
  flutter_secure_storage: ^9.2.2
  path_provider: ^2.1.4
```

Remove `dev_dependencies` entries except `flutter_test` and `flutter_lints`.

- [ ] **Step 3: Add INTERNET permission and cleartext traffic**

Open `android/android/app/src/main/AndroidManifest.xml`.

Add before `<application`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Add `android:usesCleartextTraffic="true"` to the `<application` tag.

- [ ] **Step 4: Get dependencies**

```bash
cd android && flutter pub get
```

Expected: `Running "flutter pub get"...` with no errors.

- [ ] **Step 5: Verify default app builds**

```bash
cd android && flutter build apk --debug
```

Expected: Build succeeds, APK at `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 6: Commit**

```bash
git add android/
git commit -m "chore: scaffold Flutter project with dependencies"
```

---

## Task 2: Models

**Files:**
- Create: `android/lib/models/onelap_activity.dart`
- Create: `android/lib/models/sync_summary.dart`

- [ ] **Step 1: Create `OneLapActivity`**

Create `android/lib/models/onelap_activity.dart`:

```dart
class OneLapActivity {
  final String activityId;
  final String startTime;
  final String fitUrl;
  final String recordKey;
  final String sourceFilename;

  const OneLapActivity({
    required this.activityId,
    required this.startTime,
    required this.fitUrl,
    required this.recordKey,
    required this.sourceFilename,
  });
}
```

- [ ] **Step 2: Create `SyncSummary`**

Create `android/lib/models/sync_summary.dart`:

```dart
class SyncSummary {
  final int fetched;
  final int deduped;
  final int success;
  final int failed;
  final String? abortedReason;

  const SyncSummary({
    required this.fetched,
    required this.deduped,
    required this.success,
    required this.failed,
    this.abortedReason,
  });
}
```

- [ ] **Step 3: Verify compilation**

```bash
cd android && flutter analyze lib/models/
```

Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add android/lib/models/
git commit -m "feat: add OneLapActivity and SyncSummary models"
```

---

## Task 3: SettingsService

**Files:**
- Create: `android/lib/services/settings_service.dart`

- [ ] **Step 1: Create `SettingsService`**

Create `android/lib/services/settings_service.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsService {
  static const _storage = FlutterSecureStorage();

  static const keyOneLapUsername = 'ONELAP_USERNAME';
  static const keyOneLapPassword = 'ONELAP_PASSWORD';
  static const keyStravaClientId = 'STRAVA_CLIENT_ID';
  static const keyStravaClientSecret = 'STRAVA_CLIENT_SECRET';
  static const keyStravaRefreshToken = 'STRAVA_REFRESH_TOKEN';
  static const keyStravaAccessToken = 'STRAVA_ACCESS_TOKEN';
  static const keyStravaExpiresAt = 'STRAVA_EXPIRES_AT';

  static const allKeys = [
    keyOneLapUsername,
    keyOneLapPassword,
    keyStravaClientId,
    keyStravaClientSecret,
    keyStravaRefreshToken,
    keyStravaAccessToken,
    keyStravaExpiresAt,
  ];

  Future<Map<String, String>> loadSettings() async {
    final result = <String, String>{};
    for (final key in allKeys) {
      result[key] = await _storage.read(key: key) ?? '';
    }
    return result;
  }

  Future<void> saveSettings(Map<String, String> values) async {
    for (final entry in values.entries) {
      await _storage.write(key: entry.key, value: entry.value);
    }
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/settings_service.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/settings_service.dart
git commit -m "feat: add SettingsService with secure storage"
```

---

## Task 4: StateStore

**Files:**
- Create: `android/lib/services/state_store.dart`

- [ ] **Step 1: Create `StateStore`**

Create `android/lib/services/state_store.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StateStore {
  Future<File> _stateFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/state.json');
  }

  Future<Map<String, dynamic>> _load() async {
    final file = await _stateFile();
    if (!await file.exists()) return {'synced': {}};
    try {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data.putIfAbsent('synced', () => <String, dynamic>{});
      return data;
    } catch (_) {
      return {'synced': {}};
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final file = await _stateFile();
    await file.writeAsString(jsonEncode(data));
  }

  Future<bool> isSynced(String fingerprint) async {
    final data = await _load();
    return (data['synced'] as Map).containsKey(fingerprint);
  }

  Future<void> markSynced(String fingerprint, int stravaActivityId) async {
    final data = await _load();
    (data['synced'] as Map)[fingerprint] = {
      'strava_activity_id': stravaActivityId,
      'synced_at': DateTime.now().toUtc().toIso8601String(),
    };
    await _save(data);
  }

  Future<String?> lastSuccessSyncTime() async {
    final data = await _load();
    final synced = data['synced'] as Map;
    if (synced.isEmpty) return null;
    return synced.values
        .map((e) => (e as Map)['synced_at'] as String)
        .reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/state_store.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/state_store.dart
git commit -m "feat: add StateStore with JSON persistence"
```

---

## Task 5: DedupeService

**Files:**
- Create: `android/lib/services/dedupe_service.dart`

- [ ] **Step 1: Create `makeFingerprint`**

Create `android/lib/services/dedupe_service.dart`:

```dart
import 'dart:io';
import 'package:crypto/crypto.dart';

Future<String> makeFingerprint(
  File file,
  String startTime,
  String recordKey,
) async {
  final bytes = await file.readAsBytes();
  final hash = sha256.convert(bytes).toString();
  return '$recordKey|$hash|$startTime';
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/dedupe_service.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/dedupe_service.dart
git commit -m "feat: add makeFingerprint dedupe service"
```

---

## Task 6: OneLapClient

**Files:**
- Create: `android/lib/services/onelap_client.dart`

- [ ] **Step 1: Create `OneLapClient`**

Create `android/lib/services/onelap_client.dart`:

```dart
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/onelap_activity.dart';

class OnelapRiskControlError implements Exception {
  final String message;
  const OnelapRiskControlError(this.message);
  @override
  String toString() => 'OnelapRiskControlError: $message';
}

class OneLapClient {
  final String baseUrl;
  final String username;
  final String password;
  late final Dio _dio;
  final _fitUrls = <String, (String, String)>{};

  OneLapClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    final cookieJar = CookieJar();
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<void> login() async {
    final pwdHash = md5.convert(utf8.encode(password)).toString();
    final response = await _dio.post(
      '$baseUrl/api/login',
      data: FormData.fromMap({'account': username, 'password': pwdHash}),
    );
    final payload = response.data as Map<String, dynamic>;
    final code = payload['code'];
    if (code != 0 && code != 200) {
      throw Exception('OneLap login failed: ${payload['error'] ?? 'unknown'}');
    }
  }

  Future<List<OneLapActivity>> listFitActivities({
    required DateTime since,
    int limit = 50,
  }) async {
    final payload = await _fetchActivitiesPayload();
    final items = (payload['data'] as List? ?? []);
    final cutoff = since.toIso8601String().substring(0, 10);
    final result = <OneLapActivity>[];

    for (final raw in items) {
      final map = raw as Map<String, dynamic>;
      final activityId = '${map['id'] ?? map['activity_id'] ?? ''}';
      final startTime = _parseStartTime(map);
      final fitUrl = '${map['fit_url'] ?? map['fitUrl'] ?? map['durl'] ?? ''}'.trim();
      final (recordKey, sourceFilename) = _buildRecordIdentity(map);

      if (activityId.isEmpty || startTime.isEmpty || fitUrl.isEmpty) continue;
      if (startTime.substring(0, 10).compareTo(cutoff) < 0) continue;
      if (recordKey.isEmpty) continue;

      _fitUrls[recordKey] = (fitUrl, sourceFilename);
      result.add(OneLapActivity(
        activityId: activityId,
        startTime: startTime,
        fitUrl: fitUrl,
        recordKey: recordKey,
        sourceFilename: sourceFilename,
      ));
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<Map<String, dynamic>> _fetchActivitiesPayload() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      Response response;
      try {
        response = await _dio.get('http://u.onelap.cn/analysis/list');
      } on DioException catch (e) {
        if (attempt == 0) { await login(); continue; }
        rethrow;
      }

      if (_requiresLogin(response)) {
        if (attempt == 1) throw Exception('OneLap activities request requires login');
        await login();
        continue;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (attempt == 0) { await login(); continue; }
      throw Exception('OneLap activities payload is invalid');
    }
    throw Exception('failed to fetch OneLap activities');
  }

  bool _requiresLogin(Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) return true;
    final ct = (response.headers.value('content-type') ?? '').toLowerCase();
    if (ct.contains('text/html')) return true;
    return false;
  }

  String _parseStartTime(Map<String, dynamic> raw) {
    final value = raw['start_time'];
    if (value != null) return '$value';

    final createdAt = raw['created_at'];
    if (createdAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(createdAt * 1000, isUtc: true)
          .toIso8601String()
          .replaceFirst('.000', '')
          .replaceFirst(RegExp(r'\.\d+'), '');
    }
    if (createdAt is String) {
      final ts = int.tryParse(createdAt);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true)
            .toIso8601String()
            .replaceFirst(RegExp(r'\.\d+'), '');
      }
      return createdAt;
    }
    return '';
  }

  (String, String) _buildRecordIdentity(Map<String, dynamic> raw) {
    final fileKey = '${raw['fileKey'] ?? ''}'.trim();
    if (fileKey.isNotEmpty) return ('fileKey:$fileKey', fileKey);

    final fitUrl = '${raw['fit_url'] ?? raw['fitUrl'] ?? ''}'.trim();
    if (fitUrl.isNotEmpty) return ('fitUrl:$fitUrl', fitUrl);

    final durl = '${raw['durl'] ?? ''}'.trim();
    if (durl.isNotEmpty) return ('durl:$durl', durl);

    return ('', '');
  }

  String _normalizeFitFilename(String value) {
    var text = value.trim();
    if (text.isEmpty) text = 'activity.fit';

    // Extract filename from URL path
    final uri = Uri.tryParse(text);
    var filename = (uri != null && uri.path.isNotEmpty)
        ? uri.path.split('/').last
        : text.split('/').last;

    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_').trim();
    if (filename.isEmpty) filename = 'activity';
    if (!filename.toLowerCase().endsWith('.fit')) filename = '$filename.fit';
    return filename;
  }

  Future<File> downloadFit(String recordKey, Directory outputDir) async {
    final meta = _fitUrls[recordKey];
    if (meta == null) throw Exception('missing fit_url for record $recordKey');
    final (fitUrl, sourceFilename) = meta;

    final downloadUrl = (fitUrl.startsWith('http://') || fitUrl.startsWith('https://'))
        ? fitUrl
        : '$baseUrl/${fitUrl.replaceFirst(RegExp(r'^/'), '')}';

    final safeName = _normalizeFitFilename(sourceFilename);
    await outputDir.create(recursive: true);
    final targetPath = File('${outputDir.path}/$safeName');

    // Download to temp file
    final tempPath = File('${outputDir.path}/.${safeName}_${DateTime.now().millisecondsSinceEpoch}.tmp');
    await _dio.download(downloadUrl, tempPath.path);

    // SHA-256 dedup
    final tempBytes = await tempPath.readAsBytes();
    final tempHash = sha256.convert(tempBytes).toString();

    if (await targetPath.exists()) {
      final existingHash = sha256.convert(await targetPath.readAsBytes()).toString();
      if (existingHash == tempHash) {
        await tempPath.delete();
        return targetPath;
      }
      // Different content — find a unique name
      var index = 2;
      while (true) {
        final stem = safeName.replaceAll(RegExp(r'\.fit$', caseSensitive: false), '');
        final candidate = File('${outputDir.path}/$stem-$index.fit');
        if (!await candidate.exists()) {
          await tempPath.rename(candidate.path);
          return candidate;
        }
        final candidateHash = sha256.convert(await candidate.readAsBytes()).toString();
        if (candidateHash == tempHash) {
          await tempPath.delete();
          return candidate;
        }
        index++;
      }
    }

    await tempPath.rename(targetPath.path);
    return targetPath;
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/onelap_client.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/onelap_client.dart
git commit -m "feat: add OneLapClient (login, list activities, download FIT)"
```

---

## Task 7: StravaClient

**Files:**
- Create: `android/lib/services/strava_client.dart`

- [ ] **Step 1: Create `StravaClient`**

Create `android/lib/services/strava_client.dart`:

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'settings_service.dart';

class StravaRetriableError implements Exception {
  final String message;
  const StravaRetriableError(this.message);
  @override
  String toString() => 'StravaRetriableError: $message';
}

class StravaPermanentError implements Exception {
  final String message;
  const StravaPermanentError(this.message);
  @override
  String toString() => 'StravaPermanentError: $message';
}

class StravaClient {
  final String clientId;
  final String clientSecret;
  String refreshToken;
  String accessToken;
  int expiresAt;

  final _settingsService = SettingsService();
  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  StravaClient({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
    required this.accessToken,
    required this.expiresAt,
  });

  Future<String> ensureAccessToken() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (accessToken.isNotEmpty && expiresAt > now) return accessToken;

    final response = await _dio.post(
      'https://www.strava.com/oauth/token',
      data: FormData.fromMap({
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      }),
    );
    final payload = response.data as Map<String, dynamic>;
    accessToken = payload['access_token'] as String;
    refreshToken = (payload['refresh_token'] as String?) ?? refreshToken;
    expiresAt = (payload['expires_at'] as int?) ?? expiresAt;

    await _settingsService.saveSettings({
      SettingsService.keyStravaAccessToken: accessToken,
      SettingsService.keyStravaRefreshToken: refreshToken,
      SettingsService.keyStravaExpiresAt: '$expiresAt',
    });
    return accessToken;
  }

  Map<String, String> _authHeaders() => {
    'Authorization': 'Bearer $accessToken',
  };

  Future<int> uploadFit(File file, {int retries = 3}) async {
    for (var attempt = 1; attempt <= retries; attempt++) {
      final token = await ensureAccessToken();
      Response response;
      try {
        response = await _dio.post(
          'https://www.strava.com/api/v3/uploads',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
          data: FormData.fromMap({
            'data_type': 'fit',
            'file': await MultipartFile.fromFile(
              file.path,
              filename: file.path.split('/').last,
            ),
          }),
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status >= 500 && attempt < retries) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        if (status >= 500) throw StravaRetriableError('strava upload 5xx: $status');
        if (status >= 400) {
          String detail;
          try { detail = '${e.response?.data}'; } catch (_) { detail = ''; }
          throw StravaPermanentError('strava upload failed: $status detail=$detail');
        }
        rethrow;
      }
      final payload = response.data as Map<String, dynamic>;
      return payload['id'] as int;
    }
    throw StravaRetriableError('strava upload exhausted retries');
  }

  Future<Map<String, dynamic>> pollUpload(int uploadId, {int maxAttempts = 10}) async {
    Map<String, dynamic> last = {
      'status': 'unknown',
      'error': 'poll timeout',
      'activity_id': null,
    };
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final token = await ensureAccessToken();
      Response response;
      try {
        response = await _dio.get(
          'https://www.strava.com/api/v3/uploads/$uploadId',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode ?? 0;
        if (status >= 500 && attempt < maxAttempts - 1) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        rethrow;
      }
      final payload = response.data as Map<String, dynamic>;
      last = payload;
      if (payload['error'] != null) return payload;
      if (payload['activity_id'] != null) return payload;
      final status = '${payload['status'] ?? ''}'.toLowerCase();
      if (status == 'ready' || status == 'complete') return payload;
      if (attempt < maxAttempts - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return last;
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/strava_client.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/strava_client.dart
git commit -m "feat: add StravaClient (token refresh, upload, poll)"
```

---

## Task 8: SyncEngine

**Files:**
- Create: `android/lib/services/sync_engine.dart`

- [ ] **Step 1: Create `SyncEngine`**

Create `android/lib/services/sync_engine.dart`:

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/sync_summary.dart';
import 'onelap_client.dart';
import 'strava_client.dart';
import 'state_store.dart';
import 'dedupe_service.dart';

class SyncEngine {
  final OneLapClient oneLapClient;
  final StravaClient stravaClient;
  final StateStore stateStore;

  SyncEngine({
    required this.oneLapClient,
    required this.stravaClient,
    required this.stateStore,
  });

  Future<SyncSummary> runOnce({DateTime? sinceDate}) async {
    final since = sinceDate ?? DateTime.now().subtract(const Duration(days: 3));
    final cacheDir = await getApplicationCacheDirectory();
    final downloadDir = Directory('${cacheDir.path}/fit_downloads');

    final List<OneLapActivity> activities;
    try {
      activities = await oneLapClient.listFitActivities(since: since);
    } on OnelapRiskControlError {
      return const SyncSummary(
        fetched: 0, deduped: 0, success: 0, failed: 0,
        abortedReason: 'risk-control',
      );
    }

    int deduped = 0, success = 0, failed = 0;

    for (final item in activities) {
      File fitFile;
      try {
        fitFile = await oneLapClient.downloadFit(item.recordKey, downloadDir);
      } catch (e) {
        failed++;
        continue;
      }

      final fingerprint = await makeFingerprint(fitFile, item.startTime, item.recordKey);
      if (await stateStore.isSynced(fingerprint)) {
        deduped++;
        continue;
      }

      try {
        final uploadId = await stravaClient.uploadFit(fitFile);
        final result = await stravaClient.pollUpload(uploadId);
        final activityId = result['activity_id'];
        final error = result['error'];

        if (activityId == null && error != null) {
          final errorStr = '$error'.toLowerCase();
          if (errorStr.contains('duplicate of')) {
            final match = RegExp(r'/activities/(\d+)').firstMatch('$error') ??
                RegExp(r'activity\s+(\d+)', caseSensitive: false).firstMatch('$error');
            final dupId = match != null ? int.tryParse(match.group(1)!) ?? -1 : -1;
            await stateStore.markSynced(fingerprint, dupId);
            deduped++;
          } else {
            failed++;
          }
          continue;
        }

        await stateStore.markSynced(fingerprint, (activityId as num).toInt());
        success++;
      } catch (_) {
        failed++;
      }
    }

    return SyncSummary(
      fetched: activities.length,
      deduped: deduped,
      success: success,
      failed: failed,
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/services/sync_engine.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/sync_engine.dart
git commit -m "feat: add SyncEngine core sync loop"
```

---

## Task 9: SettingsScreen

**Files:**
- Create: `android/lib/screens/settings_screen.dart`

- [ ] **Step 1: Create `SettingsScreen`**

Create `android/lib/screens/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _controllers = <String, TextEditingController>{};
  bool _loading = true;

  static const _obscured = {
    SettingsService.keyOneLapPassword,
    SettingsService.keyStravaClientSecret,
  };

  static const _labels = {
    SettingsService.keyOneLapUsername: 'OneLap 用户名',
    SettingsService.keyOneLapPassword: 'OneLap 密码',
    SettingsService.keyStravaClientId: 'Strava Client ID',
    SettingsService.keyStravaClientSecret: 'Strava Client Secret',
    SettingsService.keyStravaRefreshToken: 'Strava Refresh Token',
    SettingsService.keyStravaAccessToken: 'Strava Access Token',
    SettingsService.keyStravaExpiresAt: 'Strava Expires At (Unix timestamp)',
  };

  @override
  void initState() {
    super.initState();
    for (final key in SettingsService.allKeys) {
      _controllers[key] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    final values = await _settingsService.loadSettings();
    for (final key in SettingsService.allKeys) {
      _controllers[key]!.text = values[key] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final values = {
      for (final key in SettingsService.allKeys)
        key: _controllers[key]!.text.trim(),
    };
    await _settingsService.saveSettings(values);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('OneLap 账号', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final key in [SettingsService.keyOneLapUsername, SettingsService.keyOneLapPassword])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[key],
                obscureText: _obscured.contains(key),
                decoration: InputDecoration(
                  labelText: _labels[key],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text('Strava 凭证', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (final key in [
            SettingsService.keyStravaClientId,
            SettingsService.keyStravaClientSecret,
            SettingsService.keyStravaRefreshToken,
            SettingsService.keyStravaAccessToken,
            SettingsService.keyStravaExpiresAt,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[key],
                obscureText: _obscured.contains(key),
                decoration: InputDecoration(
                  labelText: _labels[key],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/screens/settings_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/screens/settings_screen.dart
git commit -m "feat: add SettingsScreen with credential form"
```

---

## Task 10: HomeScreen

**Files:**
- Create: `android/lib/screens/home_screen.dart`

- [ ] **Step 1: Create `HomeScreen`**

Create `android/lib/screens/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import '../models/sync_summary.dart';
import '../services/onelap_client.dart';
import '../services/settings_service.dart';
import '../services/state_store.dart';
import '../services/strava_client.dart';
import '../services/sync_engine.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stateStore = StateStore();
  final _settingsService = SettingsService();

  bool _syncing = false;
  SyncSummary? _lastSummary;
  String? _error;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final t = await _stateStore.lastSuccessSyncTime();
    if (mounted) setState(() => _lastSyncTime = t);
  }

  Future<void> _sync() async {
    setState(() { _syncing = true; _error = null; _lastSummary = null; });

    try {
      final settings = await _settingsService.loadSettings();
      final username = settings[SettingsService.keyOneLapUsername] ?? '';
      final password = settings[SettingsService.keyOneLapPassword] ?? '';
      final clientId = settings[SettingsService.keyStravaClientId] ?? '';
      final clientSecret = settings[SettingsService.keyStravaClientSecret] ?? '';
      final refreshToken = settings[SettingsService.keyStravaRefreshToken] ?? '';
      final accessToken = settings[SettingsService.keyStravaAccessToken] ?? '';
      final expiresAt = int.tryParse(settings[SettingsService.keyStravaExpiresAt] ?? '0') ?? 0;

      if (username.isEmpty || password.isEmpty ||
          clientId.isEmpty || clientSecret.isEmpty || refreshToken.isEmpty) {
        setState(() {
          _error = '请先在设置中填写凭证';
          _syncing = false;
        });
        return;
      }

      final oneLap = OneLapClient(
        baseUrl: 'https://www.onelap.cn',
        username: username,
        password: password,
      );
      final strava = StravaClient(
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        accessToken: accessToken,
        expiresAt: expiresAt,
      );
      final engine = SyncEngine(
        oneLapClient: oneLap,
        stravaClient: strava,
        stateStore: _stateStore,
      );

      final summary = await engine.runOnce();
      await _loadLastSyncTime();
      setState(() { _lastSummary = summary; _syncing = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _syncing = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneLap → Strava'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lastSyncTime != null)
              Text('上次同步: $_lastSyncTime',
                  style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _syncing ? null : _sync,
              child: const Text('立即同步'),
            ),
            const SizedBox(height: 24),
            if (_syncing) const Center(child: CircularProgressIndicator()),
            if (_lastSummary != null) ...[
              if (_lastSummary!.abortedReason == 'risk-control')
                const Text('OneLap 风控拦截，请稍后再试',
                    style: TextStyle(color: Colors.orange))
              else ...[
                Text('获取: ${_lastSummary!.fetched}   去重: ${_lastSummary!.deduped}'),
                Text('成功: ${_lastSummary!.success}   失败: ${_lastSummary!.failed}'),
              ],
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

```bash
cd android && flutter analyze lib/screens/home_screen.dart
```

Expected: No issues found.

- [ ] **Step 3: Commit**

```bash
git add android/lib/screens/home_screen.dart
git commit -m "feat: add HomeScreen with sync button and result display"
```

---

## Task 11: Wire Up `main.dart`

**Files:**
- Modify: `android/lib/main.dart`

- [ ] **Step 1: Replace `main.dart`**

Replace `android/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OneLapStravaApp());
}

class OneLapStravaApp extends StatelessWidget {
  const OneLapStravaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneLap → Strava',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
```

- [ ] **Step 2: Full analyze**

```bash
cd android && flutter analyze
```

Expected: No issues found.

- [ ] **Step 3: Build debug APK to verify full compilation**

```bash
cd android && flutter build apk --debug
```

Expected: Build succeeds, APK at `build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 4: Commit**

```bash
git add android/lib/main.dart
git commit -m "feat: wire up main.dart — Flutter app complete"
```

---

## Task 12: Build Release APK

- [ ] **Step 1: Build release APK**

```bash
cd android && flutter build apk --release
```

Expected: APK at `build/app/outputs/flutter-apk/app-release.apk`.

- [ ] **Step 2: (Optional) Install on connected device**

```bash
cd android && flutter install
```

- [ ] **Step 3: Commit build note (no binary committed)**

```bash
git commit --allow-empty -m "chore: release APK build verified"
```

---

## Summary

After completing all tasks:

- `android/` contains a fully functional Flutter Android app.
- Business logic is a faithful 1:1 Dart port of the Python modules.
- Credentials stored in Android Keystore via `flutter_secure_storage`.
- Sync state persisted in `state.json` in app documents directory.
- APK buildable with `flutter build apk --release` from `android/`.
