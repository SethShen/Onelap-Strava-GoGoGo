import 'dart:io';

import 'settings_service.dart';
import 'strava_client.dart';
import '../models/shared_fit_draft.dart';

enum SharedFitUploadStatus {
  missingConfiguration,
  invalidFile,
  success,
  failure,
}

class SharedFitUploadResult {
  final SharedFitUploadStatus status;
  final String? message;

  const SharedFitUploadResult({required this.status, this.message});
}

typedef SharedFitSettingsLoader = Future<Map<String, String>> Function();
typedef SharedFitUploadExecutor =
    Future<void> Function({
      required File file,
      required Map<String, String> settings,
    });

class SharedFitUploadService {
  SharedFitUploadService({
    SharedFitSettingsLoader? loadSettings,
    SharedFitUploadExecutor? executeUpload,
  }) : _loadSettings = loadSettings ?? SettingsService().loadSettings,
       _executeUpload = executeUpload ?? _defaultExecuteUpload;

  final SharedFitSettingsLoader _loadSettings;
  final SharedFitUploadExecutor _executeUpload;

  Future<SharedFitUploadResult> uploadDraft(SharedFitDraft draft) async {
    if (!_hasFitExtension(draft)) {
      return const SharedFitUploadResult(
        status: SharedFitUploadStatus.invalidFile,
      );
    }

    final File file = File(draft.localFilePath);
    if (!await _isReadableFile(file)) {
      return const SharedFitUploadResult(
        status: SharedFitUploadStatus.invalidFile,
      );
    }

    final Map<String, String> settings = await _loadSettings();
    if (!_hasRequiredStravaConfiguration(settings)) {
      return const SharedFitUploadResult(
        status: SharedFitUploadStatus.missingConfiguration,
      );
    }

    try {
      await _executeUpload(file: file, settings: settings);
      return const SharedFitUploadResult(status: SharedFitUploadStatus.success);
    } on Exception catch (error) {
      return SharedFitUploadResult(
        status: SharedFitUploadStatus.failure,
        message: '$error'.replaceFirst('Exception: ', ''),
      );
    }
  }

  bool _hasFitExtension(SharedFitDraft draft) {
    final String fileName = draft.displayName.isNotEmpty
        ? draft.displayName
        : draft.localFilePath;
    return fileName.toLowerCase().endsWith('.fit');
  }

  bool _hasRequiredStravaConfiguration(Map<String, String> settings) {
    return _hasValue(settings, SettingsService.keyStravaClientId) &&
        _hasValue(settings, SettingsService.keyStravaClientSecret) &&
        _hasValue(settings, SettingsService.keyStravaRefreshToken);
  }

  bool _hasValue(Map<String, String> settings, String key) {
    return (settings[key] ?? '').trim().isNotEmpty;
  }

  Future<bool> _isReadableFile(File file) async {
    if (!await file.exists()) {
      return false;
    }

    try {
      await file.length();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  static Future<void> _defaultExecuteUpload({
    required File file,
    required Map<String, String> settings,
  }) async {
    final StravaClient client = StravaClient(
      clientId: settings[SettingsService.keyStravaClientId] ?? '',
      clientSecret: settings[SettingsService.keyStravaClientSecret] ?? '',
      refreshToken: settings[SettingsService.keyStravaRefreshToken] ?? '',
      accessToken: settings[SettingsService.keyStravaAccessToken] ?? '',
      expiresAt:
          int.tryParse(settings[SettingsService.keyStravaExpiresAt] ?? '') ?? 0,
    );
    final int uploadId = await client.uploadFit(file);
    final Map<String, dynamic> result = await client.pollUpload(uploadId);
    final Object? activityId = result['activity_id'];
    final Object? error = result['error'];
    if (activityId != null) {
      return;
    }
    if (error != null) {
      throw Exception('$error');
    }
    throw Exception('Strava upload did not complete');
  }
}
