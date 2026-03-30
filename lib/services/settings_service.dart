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
  static const keyLookbackDays = 'LOOKBACK_DAYS';

  static const allKeys = [
    keyOneLapUsername,
    keyOneLapPassword,
    keyStravaClientId,
    keyStravaClientSecret,
    keyStravaRefreshToken,
    keyStravaAccessToken,
    keyStravaExpiresAt,
    keyLookbackDays,
  ];

  Future<Map<String, String>> loadSettings() async {
    final storedValues = await _storage.readAll();
    return <String, String>{
      for (final key in allKeys) key: storedValues[key] ?? '',
    };
  }

  Future<void> saveSettings(Map<String, String> values) async {
    await Future.wait(
      values.entries.map(
        (entry) => _storage.write(key: entry.key, value: entry.value),
      ),
    );
  }
}
