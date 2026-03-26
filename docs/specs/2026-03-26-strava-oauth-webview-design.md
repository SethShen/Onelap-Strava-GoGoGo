# Design: Strava OAuth WebView Authorization

**Date:** 2026-03-26  
**Status:** Approved  
**Scope:** Android Flutter app (`android/`)

## Goal

Replace manual Strava token entry with an in-app OAuth flow using an embedded WebView. Users can tap "授权 Strava" in Settings, complete the Strava login inside the app, and have tokens automatically saved. Manual token fields are retained as a fallback.

## Dependencies

Add `webview_flutter: ^4.x` to `android/pubspec.yaml`. This is the Flutter-team-maintained official WebView package.

## New Components

### `lib/services/strava_oauth_service.dart`

Single-responsibility service for the OAuth exchange step.

```
StravaOAuthService
  buildAuthorizeUrl(clientId) → String
    - redirect_uri: http://localhost/callback
    - scope: read,activity:write
    - response_type: code
  exchangeCode(clientId, clientSecret, code) → Future<void>
    - POST https://www.strava.com/oauth/token
    - Saves access_token, refresh_token, expires_at to SettingsService
    - Throws StravaOAuthException on non-2xx
```

### `lib/screens/strava_auth_screen.dart`

Full-screen WebView page. Receives `clientId` and `clientSecret` as constructor params.

- Loads the Strava authorize URL via `StravaOAuthService.buildAuthorizeUrl`
- `NavigationDelegate.onNavigationRequest` intercepts any URL starting with `http://localhost/callback`
  - Extracts `code` query param
  - Blocks WebView from navigating to that URL
  - Calls `StravaOAuthService.exchangeCode`
  - Pops with result `true` on success, `false` on error
- Shows a `CircularProgressIndicator` overlay while `exchangeCode` is running
- User can tap back to cancel; pops with result `false`

## Modified Components

### `lib/screens/settings_screen.dart`

In the "Strava 凭证" section, add an "授权 Strava" `ElevatedButton` above the existing token fields.

Button tap logic:
1. Read `clientId` and `clientSecret` from current controller values
2. If either is empty → show snackbar "请先填写 Strava Client ID 和 Client Secret"
3. Otherwise → `Navigator.push(StravaAuthScreen(clientId, clientSecret))`
4. Await result; if `true` → reload settings from storage → show snackbar "Strava 授权成功"
5. If `false` → show snackbar "授权取消或失败"

Existing `Access Token`, `Refresh Token`, `Expires At` fields are kept as-is (editable, no label change).

## Data Flow

```
用户点击"授权 Strava"
  → 验证 clientId / clientSecret 非空
  → push StravaAuthScreen
    → WebView 加载 Strava 授权页
    → 用户登录并点击授权
    → Strava redirect → http://localhost/callback?code=xxx
    → NavigationDelegate 拦截，阻止导航
    → StravaOAuthService.exchangeCode(clientId, clientSecret, code)
      → POST /oauth/token
      → 写入 secure storage
    → pop(true)
  → SettingsScreen 重新加载，snackbar "Strava 授权成功"
```

## Error Handling

| Scenario | Behavior |
|---|---|
| clientId or clientSecret empty | Snackbar, do not open WebView |
| User taps back (cancel) | pop(false), snackbar "授权取消或失败" |
| exchangeCode HTTP error | pop(false), snackbar shows error |
| WebView load error | Show error inside WebView page, allow retry or back |
| Existing token refresh (StravaClient) | Unchanged |

## What Does Not Change

- `StravaClient.ensureAccessToken()` — unchanged
- `SettingsService` key constants — unchanged
- Token fields in SettingsScreen — kept, still manually editable
- Python CLI codebase — untouched

## Files Touched

| File | Change |
|---|---|
| `android/pubspec.yaml` | Add `webview_flutter` dependency |
| `android/lib/services/strava_oauth_service.dart` | New |
| `android/lib/screens/strava_auth_screen.dart` | New |
| `android/lib/screens/settings_screen.dart` | Add auth button + result handling |
