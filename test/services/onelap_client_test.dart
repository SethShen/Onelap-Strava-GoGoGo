import 'dart:convert';
import 'dart:async';
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

class _DownloadRoute {
  _DownloadRoute({required this.statusCode, this.bytes});

  final int statusCode;
  final List<int>? bytes;
}

void main() {
  group('OneLapClient.listFitActivities', () {
    test('prefers durl over fit_url and fitUrl for download URL', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() == 'http://u.onelap.cn/analysis/list') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {
                  'id': 1,
                  'start_time': '2026-03-29T10:00:00',
                  'fileKey': 'demo.fit',
                  'fit_url': 'geo/20260329/wrong.fit',
                  'fitUrl': 'geo/20260329/also-wrong.fit',
                  'durl': 'http://fits.rfsvr.net/correct.fit?token=abc',
                },
              ],
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        if (options.uri.toString() == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            '{"code":200}',
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
      expect(
        activities.single.fitUrl,
        'http://fits.rfsvr.net/correct.fit?token=abc',
      );
      expect(activities.single.sourceFilename, 'demo.fit');
    });

    test('uses fileKey when no fit URL fields exist', () async {
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        if (options.uri.toString() == 'http://u.onelap.cn/analysis/list') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {
                  'id': 1,
                  'start_time': '2026-03-29T10:00:00',
                  'fileKey': 'geo/20260329/filekey.fit',
                },
              ],
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }
        if (options.uri.toString() == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            '{"code":200}',
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

      final List<OneLapActivity> activities = await client.listFitActivities(
        since: DateTime.utc(2026, 3, 28),
      );

      expect(activities, hasLength(1));
      expect(activities.single.fitUrl, 'geo/20260329/filekey.fit');
      expect(activities.single.rawFileKey, 'geo/20260329/filekey.fit');
      expect(activities.single.recordKey, 'fileKey:geo/20260329/filekey.fit');
    });
  });

  group('OneLapClient.downloadFit', () {
    test('falls back from absolute durl to raw fit_url after 404', () async {
      final List<String> requests = <String>[];
      final Map<String, _DownloadRoute> routes = <String, _DownloadRoute>{
        'http://fits.rfsvr.net/correct.fit?token=abc': _DownloadRoute(
          statusCode: HttpStatus.notFound,
        ),
        'http://example.com/geo/20260329/wrong.fit': _DownloadRoute(
          statusCode: HttpStatus.ok,
          bytes: <int>[9, 8, 7],
        ),
      };
      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        final String url = options.uri.toString();
        requests.add(url);
        final _DownloadRoute route =
            routes[url] ?? _DownloadRoute(statusCode: HttpStatus.notFound);
        return ResponseBody.fromBytes(
          route.bytes ?? <int>[],
          route.statusCode,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/octet-stream'],
          },
        );
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
        'http://fits.rfsvr.net/correct.fit?token=abc',
        'demo.fit',
        outputDir,
        activity: const OneLapActivity(
          activityId: '1',
          startTime: '2026-03-29T10:00:00',
          fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
          recordKey: 'fileKey:demo.fit',
          sourceFilename: 'demo.fit',
          rawFitUrl: 'geo/20260329/wrong.fit',
          rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
          rawFileKey: 'demo.fit',
        ),
      );

      expect(requests, <String>[
        'http://fits.rfsvr.net/correct.fit?token=abc',
        'http://example.com/geo/20260329/wrong.fit',
      ]);
      expect(await downloaded.readAsBytes(), <int>[9, 8, 7]);
    });

    test(
      'falls back to raw fileKey path after durl and raw fit urls 404',
      () async {
        final List<String> requests = <String>[];
        final Map<String, _DownloadRoute> routes = <String, _DownloadRoute>{
          'http://fits.rfsvr.net/correct.fit?token=abc': _DownloadRoute(
            statusCode: HttpStatus.notFound,
          ),
          'http://example.com/geo/20260329/wrong.fit': _DownloadRoute(
            statusCode: HttpStatus.notFound,
          ),
          'http://u.onelap.cn/geo/20260329/wrong.fit': _DownloadRoute(
            statusCode: HttpStatus.notFound,
          ),
          'https://u.onelap.cn/geo/20260329/wrong.fit': _DownloadRoute(
            statusCode: HttpStatus.notFound,
          ),
          'https://www.onelap.cn/geo/20260329/wrong.fit': _DownloadRoute(
            statusCode: HttpStatus.notFound,
          ),
          'http://example.com/geo/20260329/filekey.fit': _DownloadRoute(
            statusCode: HttpStatus.ok,
            bytes: <int>[1, 2, 3],
          ),
        };
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final String url = options.uri.toString();
          requests.add(url);
          final _DownloadRoute route =
              routes[url] ?? _DownloadRoute(statusCode: HttpStatus.notFound);
          return ResponseBody.fromBytes(
            route.bytes ?? <int>[],
            route.statusCode,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/octet-stream'],
            },
          );
        });
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-filekey-fallback-',
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
          'http://fits.rfsvr.net/correct.fit?token=abc',
          'demo.fit',
          outputDir,
          activity: const OneLapActivity(
            activityId: '1',
            startTime: '2026-03-29T10:00:00',
            fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            recordKey: 'fileKey:geo/20260329/filekey.fit',
            sourceFilename: 'demo.fit',
            rawFitUrl: 'geo/20260329/wrong.fit',
            rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            rawFileKey: 'geo/20260329/filekey.fit',
          ),
        );

        expect(
          requests,
          contains('http://example.com/geo/20260329/filekey.fit'),
        );
        expect(await downloaded.readAsBytes(), <int>[1, 2, 3]);
      },
    );

    test(
      'falls back to secondary geo host after primary returns 404',
      () async {
        final HttpServer primaryServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final HttpServer fallbackServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-test-',
        );

        primaryServer.listen((HttpRequest request) async {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        });

        const List<int> expectedBytes = <int>[1, 2, 3, 4, 5];
        fallbackServer.listen((HttpRequest request) async {
          request.response.statusCode = HttpStatus.ok;
          request.response.add(expectedBytes);
          await request.response.close();
        });

        final String primaryBaseUrl =
            'http://${primaryServer.address.host}:${primaryServer.port}';
        final String fallbackBaseUrl =
            'http://${fallbackServer.address.host}:${fallbackServer.port}';

        final OneLapClient client = OneLapClient(
          baseUrl: primaryBaseUrl,
          username: 'unused',
          password: 'unused',
          geoFallbackBaseUrls: <String>[fallbackBaseUrl],
        );

        addTearDown(() async {
          await primaryServer.close(force: true);
          await fallbackServer.close(force: true);
          if (await outputDir.exists()) {
            await outputDir.delete(recursive: true);
          }
        });

        final File downloaded = await client.downloadFit(
          'geo/20260329/sample.fit',
          'sample.fit',
          outputDir,
        );

        expect(await downloaded.exists(), isTrue);
        expect(await downloaded.readAsBytes(), expectedBytes);
      },
    );

    test(
      'falls back to OTM fit content download after standard URLs fail',
      () async {
        final List<String> requests = <String>[];
        final Map<String, Object> authHeadersByUrl = <String, Object>{};
        final String otmFitPath =
            'geo/20260331/Magene_C506_1774941676_93825_1774942570550.fit';
        final String otmFitContentUrl =
            'https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/'
            'Z2VvLzIwMjYwMzMxL01hZ2VuZV9DNTA2XzE3NzQ5NDE2NzZfOTM4MjVfMTc3NDk0MjU3MDU1MC5maXQ=';
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final String url = options.uri.toString();
          requests.add(url);
          authHeadersByUrl[url] = options.headers['Authorization'] ?? '';

          if (url == 'http://example.com/api/login') {
            return ResponseBody.fromString(
              jsonEncode({
                'code': 200,
                'data': [
                  {
                    'token': 'otm-token-123',
                    'refresh_token': 'otm-refresh-456',
                  },
                ],
              }),
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/json'],
              },
            );
          }

          if (url == 'http://fits.rfsvr.net/correct.fit?token=abc' ||
              url == 'http://example.com/geo/20260329/wrong.fit' ||
              url == 'http://u.onelap.cn/geo/20260329/wrong.fit' ||
              url == 'https://u.onelap.cn/geo/20260329/wrong.fit' ||
              url == 'https://www.onelap.cn/geo/20260329/wrong.fit') {
            return ResponseBody.fromBytes(
              <int>[],
              HttpStatus.notFound,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          if (url == otmFitContentUrl) {
            return ResponseBody.fromBytes(
              <int>[4, 5, 6, 7],
              HttpStatus.ok,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          return ResponseBody.fromString('not found', 404);
        });
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-otm-fallback-',
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
          'http://fits.rfsvr.net/correct.fit?token=abc',
          'demo.fit',
          outputDir,
          activity: OneLapActivity(
            activityId: '93825',
            startTime: '2026-03-31T15:21:16',
            fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            recordKey: 'fileKey:$otmFitPath',
            sourceFilename: 'demo.fit',
            rawFitUrl: 'geo/20260329/wrong.fit',
            rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            rawFileKey: otmFitPath,
          ),
        );

        expect(requests, contains('http://example.com/api/login'));
        expect(requests, contains(otmFitContentUrl));
        expect(authHeadersByUrl[otmFitContentUrl], 'otm-token-123');
        expect(await downloaded.readAsBytes(), <int>[4, 5, 6, 7]);
      },
    );

    test('uses absolute geo URL path for OTM fit content fallback', () async {
      final List<String> requests = <String>[];
      const String absoluteGeoUrl =
          'https://u.onelap.cn/geo/20260331/'
          'Magene_C506_1774941676_93825_1774942570550.fit';
      const String otmFitContentUrl =
          'https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/'
          'Z2VvLzIwMjYwMzMxL01hZ2VuZV9DNTA2XzE3NzQ5NDE2NzZfOTM4MjVfMTc3NDk0MjU3MDU1MC5maXQ=';

      final Dio dio = Dio();
      dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
        final String url = options.uri.toString();
        requests.add(url);

        if (url == 'http://example.com/api/login') {
          return ResponseBody.fromString(
            jsonEncode({
              'code': 200,
              'data': [
                {'token': 'otm-token-123'},
              ],
            }),
            200,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/json'],
            },
          );
        }

        if (url == absoluteGeoUrl) {
          return ResponseBody.fromBytes(
            <int>[],
            HttpStatus.notFound,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/octet-stream'],
            },
          );
        }

        if (url == otmFitContentUrl) {
          return ResponseBody.fromBytes(
            <int>[8, 9, 10],
            HttpStatus.ok,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>['application/octet-stream'],
            },
          );
        }

        return ResponseBody.fromString('not found', 404);
      });
      final Directory outputDir = await Directory.systemTemp.createTemp(
        'onelap-client-otm-absolute-fallback-',
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
        absoluteGeoUrl,
        'demo.fit',
        outputDir,
        activity: const OneLapActivity(
          activityId: '93825',
          startTime: '2026-03-31T15:21:16',
          fitUrl: absoluteGeoUrl,
          recordKey:
              'fitUrl:https://u.onelap.cn/geo/20260331/Magene_C506_1774941676_93825_1774942570550.fit',
          sourceFilename: 'demo.fit',
        ),
      );

      expect(requests, contains(otmFitContentUrl));
      expect(await downloaded.readAsBytes(), <int>[8, 9, 10]);
    });

    test(
      'falls back to OTM fit content download for MATCH identifiers after standard URLs fail',
      () async {
        final List<String> requests = <String>[];
        final String matchIdentifier =
            'MATCH_677767-2026-04-09-21-09-29-log.st';
        final String otmFitContentUrl =
            'https://otm.onelap.cn/api/otm/ride_record/analysis/fit_content/'
            '${base64.encode(utf8.encode(matchIdentifier))}';
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final String url = options.uri.toString();
          requests.add(url);

          if (url == 'http://example.com/api/login') {
            return ResponseBody.fromString(
              jsonEncode({
                'code': 200,
                'data': [
                  {'token': 'otm-token-123'},
                ],
              }),
              200,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/json'],
              },
            );
          }

          if (url == 'http://fits.rfsvr.net/correct.fit?token=abc' ||
              url == 'http://example.com/not-match.fit' ||
              url == 'http://example.com/not-match-alt.fit' ||
              url == 'http://example.com/geo/20260329/not-used.fit' ||
              url == 'http://u.onelap.cn/geo/20260329/not-used.fit' ||
              url == 'https://u.onelap.cn/geo/20260329/not-used.fit' ||
              url == 'https://www.onelap.cn/geo/20260329/not-used.fit') {
            return ResponseBody.fromBytes(
              <int>[],
              HttpStatus.notFound,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          if (url == otmFitContentUrl) {
            return ResponseBody.fromBytes(
              <int>[7, 6, 5, 4],
              HttpStatus.ok,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          return ResponseBody.fromString('not found', 404);
        });
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-otm-match-fallback-',
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
          'http://fits.rfsvr.net/correct.fit?token=abc',
          'demo.fit',
          outputDir,
          activity: const OneLapActivity(
            activityId: '677767',
            startTime: '2026-04-09T21:09:29',
            fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            recordKey: 'fileKey:MATCH_677767-2026-04-09-21-09-29-log.st',
            sourceFilename: 'demo.fit',
            rawFitUrl: 'not-match.fit',
            rawFitUrlAlt: 'not-match-alt.fit',
            rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
            rawFileKey: 'MATCH_677767-2026-04-09-21-09-29-log.st',
          ),
        );

        expect(requests, contains(otmFitContentUrl));
        expect(await downloaded.readAsBytes(), <int>[7, 6, 5, 4]);
      },
    );

    test(
      'does not treat unsupported identifiers as OTM fit content fallback candidates',
      () async {
        final List<String> requests = <String>[];
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final String url = options.uri.toString();
          requests.add(url);

          if (url == 'http://fits.rfsvr.net/correct.fit?token=abc' ||
              url == 'http://example.com/not-match.fit' ||
              url == 'http://example.com/not-match-alt.fit') {
            return ResponseBody.fromBytes(
              <int>[],
              HttpStatus.notFound,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          return ResponseBody.fromString('not found', 404);
        });
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-otm-unsupported-fallback-',
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
          client.downloadFit(
            'http://fits.rfsvr.net/correct.fit?token=abc',
            'demo.fit',
            outputDir,
            activity: const OneLapActivity(
              activityId: '1',
              startTime: '2026-04-09T21:09:29',
              fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
              recordKey: 'fileKey:unsupported-fit-id.st',
              sourceFilename: 'demo.fit',
              rawFitUrl: 'not-match.fit',
              rawFitUrlAlt: 'not-match-alt.fit',
              rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
              rawFileKey: 'unsupported-fit-id.st',
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception error) => error.toString(),
              'message',
              contains('OTM fallback requires fileKey or fitUrl path'),
            ),
          ),
        );

        expect(requests, isNot(contains('http://example.com/api/login')));
        expect(
          requests.where((String url) => url.contains('/fit_content/')),
          isEmpty,
        );
      },
    );

    test(
      'does not treat malformed MATCH identifiers as OTM fit content fallback candidates',
      () async {
        final List<String> requests = <String>[];
        final Dio dio = Dio();
        dio.httpClientAdapter = _FakeHttpClientAdapter((options) async {
          final String url = options.uri.toString();
          requests.add(url);

          if (url == 'http://fits.rfsvr.net/correct.fit?token=abc' ||
              url == 'http://example.com/not-match.fit' ||
              url == 'http://example.com/not-match-alt.fit' ||
              url == 'http://example.com/MATCH_placeholder') {
            return ResponseBody.fromBytes(
              <int>[],
              HttpStatus.notFound,
              headers: <String, List<String>>{
                Headers.contentTypeHeader: <String>['application/octet-stream'],
              },
            );
          }

          return ResponseBody.fromString('not found', 404);
        });
        final Directory outputDir = await Directory.systemTemp.createTemp(
          'onelap-client-otm-malformed-match-fallback-',
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
          client.downloadFit(
            'http://fits.rfsvr.net/correct.fit?token=abc',
            'demo.fit',
            outputDir,
            activity: const OneLapActivity(
              activityId: '1',
              startTime: '2026-04-09T21:09:29',
              fitUrl: 'http://fits.rfsvr.net/correct.fit?token=abc',
              recordKey: 'fileKey:MATCH_placeholder',
              sourceFilename: 'demo.fit',
              rawFitUrl: 'not-match.fit',
              rawFitUrlAlt: 'not-match-alt.fit',
              rawDurl: 'http://fits.rfsvr.net/correct.fit?token=abc',
              rawFileKey: 'MATCH_placeholder',
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (Exception error) => error.toString(),
              'message',
              contains('OTM fallback requires fileKey or fitUrl path'),
            ),
          ),
        );

        expect(requests, isNot(contains('http://example.com/api/login')));
        expect(
          requests.where((String url) => url.contains('/fit_content/')),
          isEmpty,
        );
      },
    );
  });
}
