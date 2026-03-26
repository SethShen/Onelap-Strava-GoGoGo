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
      final data =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
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
