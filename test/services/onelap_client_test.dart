import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });

  group('OneLapClient.downloadFit', () {
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
  });
}
