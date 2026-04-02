import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/shared_fit_draft.dart';
import 'package:onelap_strava_sync/services/settings_service.dart';
import 'package:onelap_strava_sync/services/shared_fit_upload_service.dart';

void main() {
  group('SharedFitUploadService.uploadDraft', () {
    test(
      'returns missingConfiguration when Strava settings are incomplete',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'shared-fit-upload-missing-config-',
        );
        final File fitFile = File('${tempDir.path}/activity.fit');
        await fitFile.writeAsBytes(<int>[1, 2, 3]);

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final SharedFitUploadService service = SharedFitUploadService(
          loadSettings: () async => <String, String>{
            SettingsService.keyStravaClientId: '',
            SettingsService.keyStravaClientSecret: 'client-secret',
            SettingsService.keyStravaRefreshToken: 'refresh-token',
          },
          executeUpload:
              ({required File file, required Map<String, String> settings}) {
                fail(
                  'executeUpload should not be called when configuration is missing',
                );
              },
        );

        final SharedFitDraft draft = SharedFitDraft(
          localFilePath: fitFile.path,
          displayName: 'activity.fit',
        );

        final SharedFitUploadResult result = await service.uploadDraft(draft);

        expect(result.status, SharedFitUploadStatus.missingConfiguration);
      },
    );

    test('returns invalidFile for a non-fit extension', () async {
      final SharedFitUploadService service = SharedFitUploadService(
        loadSettings: () async => <String, String>{
          SettingsService.keyStravaClientId: 'client-id',
          SettingsService.keyStravaClientSecret: 'client-secret',
          SettingsService.keyStravaRefreshToken: 'refresh-token',
        },
        executeUpload:
            ({required File file, required Map<String, String> settings}) {
              fail('executeUpload should not be called for invalid files');
            },
      );

      const SharedFitDraft draft = SharedFitDraft(
        localFilePath: '/tmp/activity.gpx',
        displayName: 'activity.gpx',
      );

      final SharedFitUploadResult result = await service.uploadDraft(draft);

      expect(result.status, SharedFitUploadStatus.invalidFile);
    });

    test('returns invalidFile when the local file is not readable', () async {
      final SharedFitUploadService service = SharedFitUploadService(
        loadSettings: () async => <String, String>{
          SettingsService.keyStravaClientId: 'client-id',
          SettingsService.keyStravaClientSecret: 'client-secret',
          SettingsService.keyStravaRefreshToken: 'refresh-token',
        },
        executeUpload:
            ({required File file, required Map<String, String> settings}) {
              fail('executeUpload should not be called for unreadable files');
            },
      );

      const SharedFitDraft draft = SharedFitDraft(
        localFilePath: '/tmp/missing.fit',
        displayName: 'missing.fit',
      );

      final SharedFitUploadResult result = await service.uploadDraft(draft);

      expect(result.status, SharedFitUploadStatus.invalidFile);
    });

    test('returns success after the upload flow completes', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'shared-fit-upload-success-',
      );
      final File fitFile = File('${tempDir.path}/activity.fit');
      await fitFile.writeAsBytes(<int>[1, 2, 3]);

      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      File? uploadedFile;
      bool completed = false;
      final SharedFitUploadService service = SharedFitUploadService(
        loadSettings: () async => <String, String>{
          SettingsService.keyStravaClientId: 'client-id',
          SettingsService.keyStravaClientSecret: 'client-secret',
          SettingsService.keyStravaRefreshToken: 'refresh-token',
        },
        executeUpload:
            ({
              required File file,
              required Map<String, String> settings,
            }) async {
              uploadedFile = file;
              await Future<void>.delayed(Duration.zero);
              completed = true;
            },
      );

      final SharedFitDraft draft = SharedFitDraft(
        localFilePath: fitFile.path,
        displayName: 'activity.fit',
      );

      final SharedFitUploadResult result = await service.uploadDraft(draft);

      expect(result.status, SharedFitUploadStatus.success);
      expect(uploadedFile, isNotNull);
      expect(uploadedFile!.path, fitFile.path);
      expect(completed, isTrue);
    });

    test('returns failure when the upload flow throws', () async {
      final Directory tempDir = await Directory.systemTemp.createTemp(
        'shared-fit-upload-failure-',
      );
      final File fitFile = File('${tempDir.path}/activity.fit');
      await fitFile.writeAsBytes(<int>[1, 2, 3]);

      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      final SharedFitUploadService service = SharedFitUploadService(
        loadSettings: () async => <String, String>{
          SettingsService.keyStravaClientId: 'client-id',
          SettingsService.keyStravaClientSecret: 'client-secret',
          SettingsService.keyStravaRefreshToken: 'refresh-token',
        },
        executeUpload:
            ({
              required File file,
              required Map<String, String> settings,
            }) async {
              throw Exception('upload failed');
            },
      );

      final SharedFitDraft draft = SharedFitDraft(
        localFilePath: fitFile.path,
        displayName: 'activity.fit',
      );

      final SharedFitUploadResult result = await service.uploadDraft(draft);

      expect(result.status, SharedFitUploadStatus.failure);
      expect(result.message, 'upload failed');
    });

    test(
      'returns failure when upload succeeds but polling result is not ready',
      () async {
        final Directory tempDir = await Directory.systemTemp.createTemp(
          'shared-fit-upload-poll-failure-',
        );
        final File fitFile = File('${tempDir.path}/activity.fit');
        await fitFile.writeAsBytes(<int>[1, 2, 3]);

        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final SharedFitUploadService service = SharedFitUploadService(
          loadSettings: () async => <String, String>{
            SettingsService.keyStravaClientId: 'client-id',
            SettingsService.keyStravaClientSecret: 'client-secret',
            SettingsService.keyStravaRefreshToken: 'refresh-token',
          },
          executeUpload:
              ({
                required File file,
                required Map<String, String> settings,
              }) async {
                throw Exception('Strava is still processing the upload');
              },
        );

        final SharedFitDraft draft = SharedFitDraft(
          localFilePath: fitFile.path,
          displayName: 'activity.fit',
        );

        final SharedFitUploadResult result = await service.uploadDraft(draft);

        expect(result.status, SharedFitUploadStatus.failure);
        expect(result.message, 'Strava is still processing the upload');
      },
    );
  });
}
