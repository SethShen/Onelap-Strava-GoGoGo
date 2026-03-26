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
    final params = Uri(
      queryParameters: {
        'client_id': clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'approval_prompt': 'auto',
        'scope': _scope,
      },
    ).query;
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
