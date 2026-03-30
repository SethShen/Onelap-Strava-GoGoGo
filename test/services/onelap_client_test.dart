import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/services/onelap_client.dart';

void main() {
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
