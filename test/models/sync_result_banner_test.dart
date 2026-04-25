import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/sync_result_banner.dart';
import 'package:onelap_strava_sync/models/sync_summary.dart';

void main() {
  group('SyncResultBanner', () {
    test('preserves per-platform success/failed counts from summary', () {
      final SyncSummary summary = SyncSummary(
        fetched: 2,
        deduped: 0,
        success: 1,
        failed: 1,
        stravaSuccess: 1,
        stravaFailed: 0,
        xingzheSuccess: 0,
        xingzheFailed: 1,
      );

      final SyncResultBanner banner = SyncResultBanner.fromSyncSummary(summary);
      final SyncResultBanner restored = SyncResultBanner.fromJson(
        banner.toJson(),
      );

      expect(restored.stravaSuccess, 1);
      expect(restored.stravaFailed, 0);
      expect(restored.xingzheSuccess, 0);
      expect(restored.xingzheFailed, 1);
    });

    test('keeps a platform visible when it has results', () {
      final SyncSummary summary = SyncSummary(
        fetched: 2,
        deduped: 0,
        success: 1,
        failed: 1,
        stravaSuccess: 1,
        xingzheFailed: 1,
      );

      final SyncResultBanner banner = SyncResultBanner.fromSyncSummary(summary);

      expect(banner.stravaSuccess > 0 || banner.stravaFailed > 0, isTrue);
    });
  });
}
