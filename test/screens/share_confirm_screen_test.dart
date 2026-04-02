import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/shared_fit_draft.dart';
import 'package:onelap_strava_sync/models/shared_fit_event.dart';
import 'package:onelap_strava_sync/screens/share_confirm_screen.dart';
import 'package:onelap_strava_sync/services/share_navigation_coordinator.dart';
import 'package:onelap_strava_sync/services/shared_fit_upload_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpScreen(
    WidgetTester tester, {
    required SharedFitEvent event,
    required SharedFitUploadService uploadService,
    ShareFlowUploadActivity? uploadActivity,
    Duration? successFeedbackDuration,
    VoidCallback? onOpenSettings,
    VoidCallback? onDismissToHome,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShareConfirmScreen(
          event: event,
          uploadService: uploadService,
          uploadActivity: uploadActivity ?? ShareFlowUploadActivity(),
          successFeedbackDuration:
              successFeedbackDuration ?? const Duration(seconds: 1),
          onOpenSettings: onOpenSettings,
          onDismissToHome: onDismissToHome,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows success feedback before returning home', (
    WidgetTester tester,
  ) async {
    bool dismissed = false;

    await pumpScreen(
      tester,
      event: const SharedFitEvent.draft(
        SharedFitDraft(localFilePath: '/tmp/ride.fit', displayName: 'ride.fit'),
      ),
      uploadService: _FakeUploadService.withResult(
        const SharedFitUploadResult(status: SharedFitUploadStatus.success),
      ),
      successFeedbackDuration: const Duration(milliseconds: 300),
      onDismissToHome: () {
        dismissed = true;
      },
    );

    await tester.tap(find.text('上传到 Strava'));
    await tester.pump();

    expect(find.text('上传成功'), findsOneWidget);
    expect(find.text('FIT 文件已经上传到 Strava。'), findsOneWidget);
    expect(dismissed, isFalse);

    await tester.pump(const Duration(milliseconds: 300));

    expect(dismissed, isTrue);
  });

  testWidgets('shows missing settings state and opens settings on request', (
    WidgetTester tester,
  ) async {
    bool openedSettings = false;

    await pumpScreen(
      tester,
      event: const SharedFitEvent.draft(
        SharedFitDraft(localFilePath: '/tmp/ride.fit', displayName: 'ride.fit'),
      ),
      uploadService: _FakeUploadService.withResult(
        const SharedFitUploadResult(
          status: SharedFitUploadStatus.missingConfiguration,
        ),
      ),
      onOpenSettings: () {
        openedSettings = true;
      },
    );

    await tester.tap(find.text('上传到 Strava'));
    await tester.pumpAndSettle();

    expect(find.text('去设置'), findsOneWidget);
    expect(find.textContaining('Strava'), findsOneWidget);

    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();

    expect(openedSettings, isTrue);
  });

  testWidgets('shows invalid file state with a dismiss-to-home action', (
    WidgetTester tester,
  ) async {
    bool dismissed = false;

    await pumpScreen(
      tester,
      event: const SharedFitEvent.draft(
        SharedFitDraft(localFilePath: '/tmp/ride.fit', displayName: 'ride.fit'),
      ),
      uploadService: _FakeUploadService.withResult(
        const SharedFitUploadResult(status: SharedFitUploadStatus.invalidFile),
      ),
      onDismissToHome: () {
        dismissed = true;
      },
    );

    await tester.tap(find.text('上传到 Strava'));
    await tester.pumpAndSettle();

    expect(find.text('这个共享文件不是可上传的 FIT 文件。'), findsOneWidget);
    expect(find.text('返回首页'), findsOneWidget);

    await tester.tap(find.text('返回首页'));
    await tester.pumpAndSettle();

    expect(dismissed, isTrue);
  });

  testWidgets(
    'renders native intake errors as an error-only confirmation flow',
    (WidgetTester tester) async {
      bool dismissed = false;

      await pumpScreen(
        tester,
        event: const SharedFitEvent.error('Unable to read shared FIT file'),
        uploadService: _FakeUploadService.withResult(
          const SharedFitUploadResult(status: SharedFitUploadStatus.success),
        ),
        onDismissToHome: () {
          dismissed = true;
        },
      );

      expect(find.text('Unable to read shared FIT file'), findsOneWidget);
      expect(find.text('返回首页'), findsOneWidget);
      expect(find.text('上传到 Strava'), findsNothing);

      await tester.tap(find.text('返回首页'));
      await tester.pumpAndSettle();

      expect(dismissed, isTrue);
    },
  );

  testWidgets('shows uploading state while the upload is active', (
    WidgetTester tester,
  ) async {
    final Completer<SharedFitUploadResult> completer =
        Completer<SharedFitUploadResult>();
    final ShareFlowUploadActivity uploadActivity = ShareFlowUploadActivity();

    await pumpScreen(
      tester,
      event: const SharedFitEvent.draft(
        SharedFitDraft(localFilePath: '/tmp/ride.fit', displayName: 'ride.fit'),
      ),
      uploadService: _FakeUploadService.withFuture(completer.future),
      uploadActivity: uploadActivity,
      successFeedbackDuration: Duration.zero,
    );

    await tester.tap(find.text('上传到 Strava'));
    await tester.pump();

    expect(find.text('上传中...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(uploadActivity.isUploadActive, isTrue);

    completer.complete(
      const SharedFitUploadResult(status: SharedFitUploadStatus.success),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('keeps failures retryable on the same page', (
    WidgetTester tester,
  ) async {
    int attempts = 0;
    bool dismissed = false;

    await pumpScreen(
      tester,
      event: const SharedFitEvent.draft(
        SharedFitDraft(localFilePath: '/tmp/ride.fit', displayName: 'ride.fit'),
      ),
      uploadService: _FakeUploadService.withHandler(() async {
        attempts += 1;
        if (attempts == 1) {
          return const SharedFitUploadResult(
            status: SharedFitUploadStatus.failure,
            message: 'network error',
          );
        }
        return const SharedFitUploadResult(
          status: SharedFitUploadStatus.success,
        );
      }),
      successFeedbackDuration: Duration.zero,
      onDismissToHome: () {
        dismissed = true;
      },
    );

    await tester.tap(find.text('上传到 Strava'));
    await tester.pumpAndSettle();

    expect(find.text('network error'), findsOneWidget);
    expect(find.text('重新上传'), findsOneWidget);
    expect(dismissed, isFalse);

    await tester.tap(find.text('重新上传'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(dismissed, isTrue);
  });
}

class _FakeUploadService extends SharedFitUploadService {
  _FakeUploadService._({required Future<SharedFitUploadResult> Function() call})
    : _call = call,
      super(
        loadSettings: () async => <String, String>{},
        executeUpload: ({required file, required settings}) =>
            throw UnimplementedError(),
      );

  final Future<SharedFitUploadResult> Function() _call;

  factory _FakeUploadService.withResult(SharedFitUploadResult result) {
    return _FakeUploadService._(call: () async => result);
  }

  factory _FakeUploadService.withFuture(Future<SharedFitUploadResult> future) {
    return _FakeUploadService._(call: () => future);
  }

  factory _FakeUploadService.withHandler(
    Future<SharedFitUploadResult> Function() call,
  ) {
    return _FakeUploadService._(call: call);
  }

  @override
  Future<SharedFitUploadResult> uploadDraft(SharedFitDraft draft) {
    return _call();
  }
}
