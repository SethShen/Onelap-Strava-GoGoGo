import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/onelap_activity.dart';
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

  Future<SyncSummary> runOnce({
    DateTime? sinceDate,
    int lookbackDays = 3,
  }) async {
    final since =
        sinceDate ?? DateTime.now().subtract(Duration(days: lookbackDays));
    final cacheDir = await getApplicationCacheDirectory();
    final downloadDir = Directory('${cacheDir.path}/fit_downloads');

    final List<OneLapActivity> activities;
    try {
      activities = await oneLapClient.listFitActivities(since: since);
    } on OnelapRiskControlError {
      return const SyncSummary(
        fetched: 0,
        deduped: 0,
        success: 0,
        failed: 0,
        abortedReason: 'risk-control',
      );
    }

    int deduped = 0, success = 0, failed = 0;
    final List<String> failureReasons = [];

    for (final item in activities) {
      File fitFile;
      try {
        fitFile = await oneLapClient.downloadFit(
          item.fitUrl,
          item.sourceFilename,
          downloadDir,
        );
      } on DioException catch (e) {
        failed++;
        final requestUrl = e.requestOptions.uri.toString();
        final statusCode = e.response?.statusCode;
        final message = e.message?.trim() ?? '';
        final details = <String>[
          if (statusCode != null) 'HTTP $statusCode',
          'URL: $requestUrl',
          if (item.rawDurl != null) 'raw_durl=${item.rawDurl}',
          if (item.rawFitUrl != null) 'raw_fit_url=${item.rawFitUrl}',
          if (item.rawFitUrlAlt != null) 'raw_fitUrl=${item.rawFitUrlAlt}',
          if (item.rawFileKey != null) 'raw_fileKey=${item.rawFileKey}',
          'selected_download_url=${item.fitUrl}',
          if (message.isNotEmpty) message,
        ].join(' | ');
        failureReasons.add('下载失败 (${item.sourceFilename}): $details');
        continue;
      } catch (e) {
        failed++;
        failureReasons.add('下载失败 (${item.sourceFilename}): $e');
        continue;
      }

      final fingerprint = await makeFingerprint(
        fitFile,
        item.startTime,
        item.recordKey,
      );
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
            final match =
                RegExp(r'/activities/(\d+)').firstMatch('$error') ??
                RegExp(
                  r'activity\s+(\d+)',
                  caseSensitive: false,
                ).firstMatch('$error');
            final dupId = match != null
                ? int.tryParse(match.group(1)!) ?? -1
                : -1;
            await stateStore.markSynced(fingerprint, dupId);
            deduped++;
          } else {
            failed++;
            failureReasons.add('上传失败 (${item.sourceFilename}): $error');
          }
          continue;
        }

        await stateStore.markSynced(fingerprint, (activityId as num).toInt());
        success++;
      } catch (e) {
        failed++;
        failureReasons.add('上传失败 (${item.sourceFilename}): $e');
      }
    }

    return SyncSummary(
      fetched: activities.length,
      deduped: deduped,
      success: success,
      failed: failed,
      failureReasons: failureReasons,
    );
  }
}
