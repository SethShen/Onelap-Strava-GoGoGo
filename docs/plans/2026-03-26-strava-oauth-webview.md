# Strava OAuth WebView Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an in-app WebView OAuth flow to the Flutter app so users can authorize Strava with one tap instead of manually pasting tokens.

**Architecture:** Add `webview_flutter` dependency. New `StravaOAuthService` handles URL building and code exchange. New `StravaAuthScreen` hosts the WebView and intercepts the `http://localhost/callback` redirect. `SettingsScreen` gains an "授权 Strava" button that launches the auth screen and reloads tokens on success. Existing manual token fields and `StravaClient` token-refresh logic are untouched.

**Tech Stack:** Flutter (Dart), `webview_flutter ^4.x`, existing `dio`, `flutter_secure_storage`.

**Spec:** `docs/superpowers/specs/2026-03-26-strava-oauth-webview-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `android/pubspec.yaml` | Modify | Add `webview_flutter` dependency |
| `android/lib/services/strava_oauth_service.dart` | Create | Build authorize URL; exchange code for tokens |
| `android/lib/screens/strava_auth_screen.dart` | Create | WebView page; intercept callback; call exchange |
| `android/lib/screens/settings_screen.dart` | Modify | Add "授权 Strava" button + result handling |

---

## Task 1: Add `webview_flutter` dependency

**Files:**
- Modify: `android/pubspec.yaml`

- [ ] **Step 1: Add dependency**

In `android/pubspec.yaml`, under `dependencies:`, add:

```yaml
  webview_flutter: ^4.10.0
```

- [ ] **Step 2: Fetch packages**

```bash
cd android && flutter pub get
```

Expected: output includes `webview_flutter` with no errors.

- [ ] **Step 3: Verify analyze still passes**

```bash
cd android && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add android/pubspec.yaml android/pubspec.lock
git commit -m "chore: add webview_flutter dependency"
```

---

## Task 2: `StravaOAuthService`

**Files:**
- Create: `android/lib/services/strava_oauth_service.dart`

- [ ] **Step 1: Create the service**

Create `android/lib/services/strava_oauth_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'settings_service.dart';

class StravaOAuthException implements Exception {
  final String message;
  const StravaOAuthException(this.message);
  @override
  String toString() => 'StravaOAuthException: $message';
}

class StravaOAuthService {
  static const _redirectUri = 'http://localhost/callback';
  static const _scope = 'read,activity:write';

  final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  final _settingsService = SettingsService();

  /// Returns the Strava OAuth authorization URL.
  String buildAuthorizeUrl(String clientId) {
    final params = Uri(queryParameters: {
      'client_id': clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'approval_prompt': 'auto',
      'scope': _scope,
    }).query;
    return 'https://www.strava.com/oauth/authorize?$params';
  }

  /// Exchanges an authorization code for tokens and persists them.
  /// Throws [StravaOAuthException] on failure.
  Future<void> exchangeCode(
    String clientId,
    String clientSecret,
    String code,
  ) async {
    Response response;
    try {
      response = await _dio.post(
        'https://www.strava.com/oauth/token',
        data: FormData.fromMap({
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
        }),
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode ?? 0;
      final detail = '${e.response?.data ?? e.message}';
      throw StravaOAuthException('token exchange failed: $status $detail');
    }

    final payload = response.data as Map<String, dynamic>;
    final accessToken = payload['access_token'] as String? ?? '';
    final refreshToken = payload['refresh_token'] as String? ?? '';
    final expiresAt = payload['expires_at'] as int? ?? 0;

    await _settingsService.saveSettings({
      SettingsService.keyStravaAccessToken: accessToken,
      SettingsService.keyStravaRefreshToken: refreshToken,
      SettingsService.keyStravaExpiresAt: '$expiresAt',
    });
  }
}
```

- [ ] **Step 2: Verify analyze passes**

```bash
cd android && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add android/lib/services/strava_oauth_service.dart
git commit -m "feat: add StravaOAuthService (URL builder + code exchange)"
```

---

## Task 3: `StravaAuthScreen`

**Files:**
- Create: `android/lib/screens/strava_auth_screen.dart`

- [ ] **Step 1: Create the screen**

Create `android/lib/screens/strava_auth_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/strava_oauth_service.dart';

class StravaAuthScreen extends StatefulWidget {
  final String clientId;
  final String clientSecret;

  const StravaAuthScreen({
    super.key,
    required this.clientId,
    required this.clientSecret,
  });

  @override
  State<StravaAuthScreen> createState() => _StravaAuthScreenState();
}

class _StravaAuthScreenState extends State<StravaAuthScreen> {
  late final WebViewController _controller;
  final _oauthService = StravaOAuthService();
  bool _exchanging = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    final authorizeUrl = _oauthService.buildAuthorizeUrl(widget.clientId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('http://localhost/callback')) {
              _handleCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Only surface error if we haven't already completed
            if (!_didComplete && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('页面加载失败: ${error.description}'),
                  action: SnackBarAction(
                    label: '重试',
                    onPressed: () => _controller.reload(),
                  ),
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(authorizeUrl));
  }

  Future<void> _handleCallback(String url) async {
    if (_exchanging || _didComplete) return;
    setState(() => _exchanging = true);

    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];

    if (code == null || code.isEmpty) {
      setState(() => _exchanging = false);
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    try {
      await _oauthService.exchangeCode(
        widget.clientId,
        widget.clientSecret,
        code,
      );
      _didComplete = true;
      if (mounted) Navigator.of(context).pop(true);
    } on StravaOAuthException catch (e) {
      setState(() => _exchanging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('授权失败: $e')),
        );
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权 Strava'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_exchanging)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify analyze passes**

```bash
cd android && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add android/lib/screens/strava_auth_screen.dart
git commit -m "feat: add StravaAuthScreen WebView OAuth flow"
```

---

## Task 4: Wire "授权 Strava" button into `SettingsScreen`

**Files:**
- Modify: `android/lib/screens/settings_screen.dart`

- [ ] **Step 1: Add import**

At the top of `android/lib/screens/settings_screen.dart`, add:

```dart
import 'strava_auth_screen.dart';
```

- [ ] **Step 2: Add `_authorizeStrava` method**

Inside `_SettingsScreenState`, add the following method (after `_save`):

```dart
Future<void> _authorizeStrava() async {
  final clientId =
      _controllers[SettingsService.keyStravaClientId]!.text.trim();
  final clientSecret =
      _controllers[SettingsService.keyStravaClientSecret]!.text.trim();

  if (clientId.isEmpty || clientSecret.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先填写 Strava Client ID 和 Client Secret'),
        ),
      );
    }
    return;
  }

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => StravaAuthScreen(
        clientId: clientId,
        clientSecret: clientSecret,
      ),
    ),
  );

  if (!mounted) return;

  if (result == true) {
    await _load(); // reload tokens from secure storage into controllers
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Strava 授权成功')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('授权取消或失败')),
    );
  }
}
```

- [ ] **Step 3: Add button in the build method**

In the `build` method of `_SettingsScreenState`, locate the Strava section header (`'Strava 凭证'`). Add an "授权 Strava" button immediately after `const SizedBox(height: 8)` that follows the header, before the token fields loop:

Replace:
```dart
          const SizedBox(height: 8),
          for (final key in [
            SettingsService.keyStravaClientId,
            SettingsService.keyStravaClientSecret,
            SettingsService.keyStravaRefreshToken,
            SettingsService.keyStravaAccessToken,
            SettingsService.keyStravaExpiresAt,
          ])
```

With:
```dart
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _authorizeStrava,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('授权 Strava'),
          ),
          const SizedBox(height: 12),
          for (final key in [
            SettingsService.keyStravaClientId,
            SettingsService.keyStravaClientSecret,
            SettingsService.keyStravaRefreshToken,
            SettingsService.keyStravaAccessToken,
            SettingsService.keyStravaExpiresAt,
          ])
```

- [ ] **Step 4: Verify analyze passes**

```bash
cd android && flutter analyze
```

Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add android/lib/screens/settings_screen.dart
git commit -m "feat: add '授权 Strava' OAuth button to SettingsScreen"
```

---

## Task 5: Build debug APK and install on device

- [ ] **Step 1: Build debug APK**

```bash
cd android && flutter build apk --debug --dart-define=FLUTTER_IMPELLER_ENABLED=false
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 2: Install on connected device**

```bash
adb install -r android/build/app/outputs/flutter-apk/app-debug.apk
```

Expected: `Success`

- [ ] **Step 3: Commit final state (only if files changed)**

```bash
git diff --quiet android/pubspec.yaml android/pubspec.lock || \
  git add android/pubspec.yaml android/pubspec.lock && \
  git commit -m "chore: debug APK build verified for Strava OAuth feature"
```

If there are no changes, skip this step — all work was committed in previous tasks.
