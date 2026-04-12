import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/services/settings_service.dart';

class _ConcurrentUnsafeStore implements SettingsStore {
  final Map<String, String> _values = <String, String>{};
  bool _writeInFlight = false;

  @override
  Future<Map<String, String>> readAll() async =>
      Map<String, String>.from(_values);

  @override
  Future<void> write({required String key, required String value}) async {
    if (_writeInFlight) {
      await Future<void>.delayed(Duration.zero);
      return;
    }

    _writeInFlight = true;
    await Future<void>.delayed(Duration.zero);
    _values[key] = value;
    _writeInFlight = false;
  }
}

void main() {
  test(
    'loadSettings returns gcj correction setting while preserving existing keys',
    () async {
      final _ConcurrentUnsafeStore store = _ConcurrentUnsafeStore();
      final SettingsService service = SettingsService(store: store);

      await service.saveSettings(<String, String>{
        SettingsService.keyLookbackDays: '7',
        SettingsService.keyGcjCorrectionEnabled: 'true',
      });

      final Map<String, String> settings = await service.loadSettings();
      expect(settings[SettingsService.keyLookbackDays], '7');
      expect(settings[SettingsService.keyGcjCorrectionEnabled], 'true');
      expect(settings[SettingsService.keyStravaClientId], '');
    },
  );

  test(
    'saveSettings persists all values even when backend is concurrency-unsafe',
    () async {
      final _ConcurrentUnsafeStore store = _ConcurrentUnsafeStore();
      final SettingsService service = SettingsService(store: store);

      await service.saveSettings(<String, String>{
        SettingsService.keyStravaClientId: '12345',
        SettingsService.keyStravaClientSecret: 'secret-xyz',
        SettingsService.keyOneLapUsername: 'rider@example.com',
        SettingsService.keyOneLapPassword: 'pass-123',
      });

      final Map<String, String> settings = await service.loadSettings();
      expect(settings[SettingsService.keyStravaClientId], '12345');
      expect(settings[SettingsService.keyStravaClientSecret], 'secret-xyz');
      expect(settings[SettingsService.keyOneLapUsername], 'rider@example.com');
      expect(settings[SettingsService.keyOneLapPassword], 'pass-123');
    },
  );
}
