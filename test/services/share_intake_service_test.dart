import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/shared_fit_event.dart';
import 'package:onelap_strava_sync/services/share_intake_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel = MethodChannel(
    'onelap_strava_sync/share_intake',
  );
  const EventChannel eventChannel = EventChannel(
    'onelap_strava_sync/shared_fit_events',
  );

  late List<MethodCall> methodCalls;
  StreamController<Object?>? eventController;

  setUp(() {
    methodCalls = <MethodCall>[];
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(eventChannel.name, null);
    await eventController?.close();
    eventController = null;
  });

  group('ShareIntakeService.loadInitialEvent', () {
    test('returns null when no initial payload exists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            methodCalls.add(call);
            return null;
          });

      final ShareIntakeService service = ShareIntakeService();

      final SharedFitEvent? event = await service.loadInitialEvent();

      expect(event, isNull);
      expect(methodCalls, hasLength(1));
      expect(methodCalls.single.method, 'getInitialSharedFit');
    });

    test('normalizes an initial draft payload into a draft event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            methodCalls.add(call);
            return <String, Object?>{
              'type': 'fit',
              'localFilePath': '/tmp/activity.fit',
              'displayName': 'activity.fit',
              'sourcePlatform': 'android',
              'receivedAt': '2026-04-02T00:00:00.000Z',
            };
          });

      final ShareIntakeService service = ShareIntakeService();

      final SharedFitEvent? event = await service.loadInitialEvent();

      expect(event, isNotNull);
      expect(event!.type, SharedFitEventType.draft);
      expect(event.draft, isNotNull);
      expect(event.message, isNull);
      expect(event.draft!.localFilePath, '/tmp/activity.fit');
      expect(event.draft!.displayName, 'activity.fit');
    });

    test(
      'normalizes an initial native error payload into an error event',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
              methodCalls.add(call);
              return <String, Object?>{
                'message': 'Unable to read shared FIT file',
              };
            });

        final ShareIntakeService service = ShareIntakeService();

        final SharedFitEvent? event = await service.loadInitialEvent();

        expect(event, isNotNull);
        expect(event!.type, SharedFitEventType.error);
        expect(event.draft, isNull);
        expect(event.message, 'Unable to read shared FIT file');
      },
    );

    test('converts an initial malformed payload into an error event', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
            methodCalls.add(call);
            return <String, Object?>{'localFilePath': '/tmp/activity.fit'};
          });

      final ShareIntakeService service = ShareIntakeService();

      final SharedFitEvent? event = await service.loadInitialEvent();

      expect(event, isNotNull);
      expect(event!.type, SharedFitEventType.error);
      expect(event.message, 'Unable to read shared FIT file');
    });

    test(
      'converts an initial wrong-type payload into an error event',
      () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
              methodCalls.add(call);
              return 'unexpected payload';
            });

        final ShareIntakeService service = ShareIntakeService();

        final SharedFitEvent? event = await service.loadInitialEvent();

        expect(event, isNotNull);
        expect(event!.type, SharedFitEventType.error);
        expect(event.message, 'Unable to read shared FIT file');
      },
    );
  });

  group('ShareIntakeService.events', () {
    test('emits normalized live draft and error events', () async {
      eventController = StreamController<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(eventChannel.name, (ByteData? message) async {
            final MethodCall call = const StandardMethodCodec()
                .decodeMethodCall(message);
            if (call.method == 'listen') {
              eventController!.stream.listen((Object? event) {
                TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger
                    .handlePlatformMessage(
                      eventChannel.name,
                      const StandardMethodCodec().encodeSuccessEnvelope(event),
                      (_) {},
                    );
              });
            }
            return null;
          });

      final ShareIntakeService service = ShareIntakeService();

      final Future<List<SharedFitEvent>> collected = service.events
          .take(2)
          .toList();
      eventController!.add(<String, Object?>{
        'type': 'fit',
        'localFilePath': '/tmp/live.fit',
        'displayName': 'live.fit',
        'sourcePlatform': 'android',
        'receivedAt': '2026-04-02T00:00:00.000Z',
      });
      eventController!.add(<String, Object?>{'message': 'Share intent failed'});

      final List<SharedFitEvent> events = await collected;

      expect(events[0].type, SharedFitEventType.draft);
      expect(events[0].draft, isNotNull);
      expect(events[0].draft!.displayName, 'live.fit');
      expect(events[0].message, isNull);
      expect(events[1].type, SharedFitEventType.error);
      expect(events[1].draft, isNull);
      expect(events[1].message, 'Share intent failed');
    });

    test(
      'converts malformed live payloads into recoverable error events',
      () async {
        eventController = StreamController<Object?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(eventChannel.name, (
              ByteData? message,
            ) async {
              final MethodCall call = const StandardMethodCodec()
                  .decodeMethodCall(message);
              if (call.method == 'listen') {
                eventController!.stream.listen((Object? event) {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .handlePlatformMessage(
                        eventChannel.name,
                        const StandardMethodCodec().encodeSuccessEnvelope(
                          event,
                        ),
                        (_) {},
                      );
                });
              }
              return null;
            });

        final ShareIntakeService service = ShareIntakeService();

        final Future<List<SharedFitEvent>> collected = service.events
            .take(2)
            .toList();
        eventController!.add(<String, Object?>{
          'localFilePath': '/tmp/broken.fit',
        });
        eventController!.add(<String, Object?>{
          'type': 'fit',
          'localFilePath': '/tmp/live.fit',
          'displayName': 'live.fit',
          'sourcePlatform': 'android',
          'receivedAt': '2026-04-02T00:00:00.000Z',
        });

        final List<SharedFitEvent> events = await collected;

        expect(events[0].type, SharedFitEventType.error);
        expect(events[0].message, 'Unable to read shared FIT file');
        expect(events[1].type, SharedFitEventType.draft);
        expect(events[1].draft!.displayName, 'live.fit');
      },
    );

    test(
      'converts wrong-type live payloads into recoverable error events',
      () async {
        eventController = StreamController<Object?>();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler(eventChannel.name, (
              ByteData? message,
            ) async {
              final MethodCall call = const StandardMethodCodec()
                  .decodeMethodCall(message);
              if (call.method == 'listen') {
                eventController!.stream.listen((Object? event) {
                  TestDefaultBinaryMessengerBinding
                      .instance
                      .defaultBinaryMessenger
                      .handlePlatformMessage(
                        eventChannel.name,
                        const StandardMethodCodec().encodeSuccessEnvelope(
                          event,
                        ),
                        (_) {},
                      );
                });
              }
              return null;
            });

        final ShareIntakeService service = ShareIntakeService();

        final Future<List<SharedFitEvent>> collected = service.events
            .take(2)
            .toList();
        eventController!.add('unexpected payload');
        eventController!.add(<String, Object?>{
          'type': 'fit',
          'localFilePath': '/tmp/live.fit',
          'displayName': 'live.fit',
          'sourcePlatform': 'android',
          'receivedAt': '2026-04-02T00:00:00.000Z',
        });

        final List<SharedFitEvent> events = await collected;

        expect(events[0].type, SharedFitEventType.error);
        expect(events[0].message, 'Unable to read shared FIT file');
        expect(events[1].type, SharedFitEventType.draft);
        expect(events[1].draft!.displayName, 'live.fit');
      },
    );
  });
}
