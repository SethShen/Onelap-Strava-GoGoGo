import 'package:flutter_test/flutter_test.dart';
import 'package:onelap_strava_sync/services/coordinate_converter.dart';

void main() {
  group('CoordinateConverter.gcj02ToWgs84Exact', () {
    test('returns the expected WGS84 coordinate for a point in China', () {
      final (double latitude, double longitude) result =
          CoordinateConverter.gcj02ToWgs84Exact(39.915, 116.404);

      expect(result.$1, closeTo(39.91359571849836, 1e-5));
      expect(result.$2, closeTo(116.39775550083061, 1e-5));
    });

    test('returns the original coordinate pair for a point outside China', () {
      final (double latitude, double longitude) result =
          CoordinateConverter.gcj02ToWgs84Exact(35.6762, 139.6503);

      expect(result, (35.6762, 139.6503));
    });
  });
}
