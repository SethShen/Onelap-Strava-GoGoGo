import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/models/onelap_activity.dart';
import 'package:onelap_strava_sync/services/onelap_client.dart';

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }
}

void main() {
  group('OneLapClient.listFitActivities', () {
    test('parses ride_record/list response and respects limit', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/list') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'list': [
                  {
                    'id': 101,
                    'start_riding_time': '2026-03-29T10:00:00',
                    'distance_km': 42.5,
                    'time_seconds': 5400,
                  },
                  {
                    'id': 102,
                    'start_riding_time': '2026-03-30T08:00:00',
                    'distance_km': 30.0,
                    'time_seconds': 3600,
                  },
                  {
                    'id': 103,
                    'start_riding_time': '2026-03-31T09:00:00',
                    'distance_km': 55.2,
                    'time_seconds': 7200,
                  },
                ],
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final activities = await client.listFitActivities(
        since: DateTime.utc(2026, 3, 28),
        limit: 2,
      );

      expect(activities, hasLength(2));
      expect(activities[0].activityId, '101');
      expect(activities[0].startTime, '2026-03-29T10:00:00');
      expect(activities[0].distanceKm, 42.5);
      expect(activities[0].timeSeconds, 5400);
      expect(activities[0].fitUrl, isEmpty);
      expect(activities[1].activityId, '102');
    });

    test('skips activities before cutoff date', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/list') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'list': [
                  {'id': 1, 'start_riding_time': '2026-03-01T10:00:00'},
                  {'id': 2, 'start_riding_time': '2026-03-29T10:00:00'},
                ],
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final activities = await client.listFitActivities(
        since: DateTime.utc(2026, 3, 28),
      );

      expect(activities, hasLength(1));
      expect(activities.single.activityId, '2');
    });

    test('skips activities with empty activityId or startTime', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/list') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'list': [
                  {'id': null, 'start_riding_time': '2026-03-29T10:00:00'},
                  {'id': 2},
                  {'id': 3, 'start_riding_time': '2026-03-30T10:00:00'},
                ],
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final activities = await client.listFitActivities(
        since: DateTime.utc(2026, 3, 28),
      );

      expect(activities, hasLength(1));
      expect(activities.single.activityId, '3');
    });

    test('retries on 401 with login', () async {
      var callCount = 0;
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/list') {
          callCount++;
          if (callCount == 1) {
            return ResponseBody.fromString(
              'login required',
              401,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['text/html'],
              },
            );
          }
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'list': [
                  {'id': 1, 'start_riding_time': '2026-03-29T10:00:00'},
                ],
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        if (options.uri.toString() == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {'token': 'test-token'},
              ],
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final activities = await client.listFitActivities(
        since: DateTime.utc(2026, 3, 28),
      );

      expect(activities, hasLength(1));
      expect(callCount, 2);
    });
  });

  group('OneLapClient.getActivityDetail', () {
    test('returns detail with fileKey on success', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/analysis/42') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'ridingRecord': {
                  'durl': 'http://example.com/file.fit',
                  'fileKey': 'geo/20260329/ride.fit',
                  'startRidingTime': '2026-03-29T10:00:00',
                  'totalDistance': 42500,
                  'time': 5400,
                },
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final detail = await client.getActivityDetail('42');

      expect(detail, isNotNull);
      expect(detail!.fileKey, 'geo/20260329/ride.fit');
      expect(detail.durl, 'http://example.com/file.fit');
      expect(detail.activityId, '42');
    });

    test('returns null when ridingRecord is missing', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/analysis/99') {
          return ResponseBody.fromString(
            jsonEncode({'code': 200, 'data': {}}),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final detail = await client.getActivityDetail('99');

      expect(detail, isNull);
    });

    test('returns null on non-200 code', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() ==
            'http://u.onelap.cn/api/otm/ride_record/analysis/404') {
          return ResponseBody.fromString(
            jsonEncode({'code': 404, 'msg': 'not found'}),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final detail = await client.getActivityDetail('404');

      expect(detail, isNull);
    });
  });

  group('OneLapClient.downloadFit', () {
    test('uses fit_content endpoint when activity has fileKey', () async {
      final List<String> requests = <String>[];
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        final url = options.uri.toString();
        requests.add(url);

        if (url == 'http://u.onelap.cn/api/otm/ride_record/analysis/42') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': {
                'ridingRecord': {
                  'durl': '',
                  'fileKey': 'geo/20260329/ride.fit',
                },
              },
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }

        // fit_content endpoint
        final encodedFileKey = base64.encode(
          utf8.encode('geo/20260329/ride.fit'),
        );
        final fitContentUrl =
            'http://u.onelap.cn/api/otm/ride_record/analysis/fit_content/$encodedFileKey';
        if (url == fitContentUrl) {
          return ResponseBody.fromBytes(
            <int>[1, 2, 3, 4],
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/octet-stream'],
            },
          );
        }

        return ResponseBody.fromString('not found', 404);
      });

      final Directory outputDir = await Directory.systemTemp.createTemp(
        'onelap-client-download-',
      );
      addTearDown(() async {
        if (await outputDir.exists()) {
          await outputDir.delete(recursive: true);
        }
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      final File downloaded = await client.downloadFit(
        '',
        'ride.fit',
        outputDir,
        activity: const OneLapActivity(
          activityId: '42',
          startTime: '2026-03-29T10:00:00',
          fitUrl: '',
          recordKey: '42',
          sourceFilename: 'ride.fit',
        ),
      );

      expect(await downloaded.exists(), isTrue);
      expect(await downloaded.readAsBytes(), <int>[1, 2, 3, 4]);
      // Should have called getActivityDetail and then fit_content
      expect(
        requests,
        contains('http://u.onelap.cn/api/otm/ride_record/analysis/42'),
      );
      expect(requests.any((u) => u.contains('/fit_content/')), isTrue);
    });

    test('throws when no activity and no fitUrl', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        return ResponseBody.fromString('not found', 404);
      });

      final Directory outputDir = await Directory.systemTemp.createTemp(
        'onelap-client-no-url-',
      );
      addTearDown(() async {
        if (await outputDir.exists()) {
          await outputDir.delete(recursive: true);
        }
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'unused',
        password: 'unused',
        dio: dio,
      );

      await expectLater(
        client.downloadFit('', 'demo.fit', outputDir),
        throwsA(isA<Exception>()),
      );
    });

    test(
      'falls back to fitUrl when activity detail returns null fileKey',
      () async {
        final List<String> requests = <String>[];
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final url = options.uri.toString();
          requests.add(url);

          if (url == 'http://u.onelap.cn/api/otm/ride_record/analysis/42') {
            return ResponseBody.fromString(
              jsonEncode({
                'code': 200,
                'data': {
                  'ridingRecord': {'durl': '', 'fileKey': ''},
                },
              }),
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/json'],
              },
            );
          }

          if (url == 'http://example.com/fallback.fit') {
            return ResponseBody.fromBytes(
              <int>[5, 6, 7],
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          return ResponseBody.fromString('not found', 404);
        });

        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-fallback-',
        );
        addTearDown(() async {
          if (await outputDir.exists()) {
            await outputDir.delete(recursive: true);
          }
        });

        final OneLapClient client = OneLapClient(
          baseUrl: 'http://example.com',
          username: 'unused',
          password: 'unused',
          dio: dio,
        );

        final File downloaded = await client.downloadFit(
          'http://example.com/fallback.fit',
          'fallback.fit',
          outputDir,
          activity: const OneLapActivity(
            activityId: '42',
            startTime: '2026-03-29T10:00:00',
            fitUrl: 'http://example.com/fallback.fit',
            recordKey: '42',
            sourceFilename: 'fallback.fit',
          ),
        );

        expect(await downloaded.exists(), isTrue);
        expect(await downloaded.readAsBytes(), <int>[5, 6, 7]);
        // Should have tried getActivityDetail first, then fell back to fitUrl
        expect(
          requests,
          contains('http://u.onelap.cn/api/otm/ride_record/analysis/42'),
        );
        expect(requests, contains('http://example.com/fallback.fit'));
      },
    );
  });

  group('OneLapClient.login', () {
    test('extracts token from data[0].token', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {'token': 'abc123'},
              ],
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'user',
        password: 'pass',
        dio: dio,
      );

      await client.login();
      // If login succeeded without throwing, token was extracted
    });

    test('throws on non-200 code', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            jsonEncode({'code': 401, 'msg': 'invalid credentials'}),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        return ResponseBody.fromString('not found', 404);
      });

      final OneLapClient client = OneLapClient(
        baseUrl: 'http://example.com',
        username: 'user',
        password: 'wrong',
        dio: dio,
      );

      await expectLater(client.login(), throwsA(isA<Exception>()));
    });
  });
}
