import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/sync_summary.dart';
import 'package:onelap_strava_sync/services/sync_failure_formatter.dart';

void main() {
  group('SyncFailureFormatter.toUserMessage', () {
    test('returns friendly message for OneLap 404 download failures', () {
      const String raw =
          '下载失败 (demo.fit): HTTP 404 | URL: https://www.onelap.cn/geo/demo.fit';

      final String result = SyncFailureFormatter.toUserMessage(raw);

      expect(result, contains('OneLap 源文件可能已过期或已删除'));
    });

    test('returns friendly message for Strava 5xx upload failures', () {
      const String raw =
          '上传失败 (demo.fit): StravaRetriableError: strava upload 5xx: 503';

      final String result = SyncFailureFormatter.toUserMessage(raw);

      expect(result, contains('Strava 服务暂时不可用'));
    });
  });

  group('SyncFailureFormatter.buildClipboardText', () {
    test('includes sync stats and raw failure details', () {
      const SyncSummary summary = SyncSummary(
        fetched: 2,
        deduped: 0,
        success: 0,
        failed: 2,
        failureReasons: <String>[
          '下载失败 (a.fit): HTTP 404 | URL: https://www.onelap.cn/geo/a.fit',
          '上传失败 (b.fit): StravaRetriableError: strava upload 5xx: 503',
        ],
      );

      final String text = SyncFailureFormatter.buildClipboardText(summary);

      expect(text, contains('fetched=2'));
      expect(text, contains('failed=2'));
      expect(text, contains('下载失败 (a.fit): HTTP 404'));
      expect(text, contains('上传失败 (b.fit): StravaRetriableError'));
    });

    test('includes app version and generated timestamp when provided', () {
      const SyncSummary summary = SyncSummary(
        fetched: 1,
        deduped: 0,
        success: 0,
        failed: 1,
        failureReasons: <String>[
          '上传失败 (c.fit): StravaRetriableError: strava upload 5xx: 503',
        ],
      );

      final String text = SyncFailureFormatter.buildClipboardTextWithMeta(
        summary: summary,
        appVersion: '1.0.1+2',
        generatedAt: DateTime.utc(2026, 3, 30, 10, 20, 30),
      );

      expect(text, contains('app_version=1.0.1+2'));
      expect(text, contains('generated_at_utc=2026-03-30T10:20:30.000Z'));
    });
  });
}
