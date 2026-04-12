import 'dart:io';
import 'dart:typed_data';

import 'package:fit_tool/fit_tool.dart';
import 'package:path_provider/path_provider.dart';

import 'coordinate_converter.dart';

typedef CacheDirectoryLoader = Future<Directory> Function();

class FitCoordinateRewriteService {
  FitCoordinateRewriteService({CacheDirectoryLoader? loadCacheDirectory})
    : _loadCacheDirectory = loadCacheDirectory ?? getApplicationCacheDirectory;

  final CacheDirectoryLoader _loadCacheDirectory;

  Future<File> rewrite(File inputFile) async {
    final Uint8List bytes = await inputFile.readAsBytes();
    final FitFile fitFile = FitFile.fromBytes(bytes);

    for (final Record record in fitFile.records) {
      final Message message = record.message;
      if (message is RecordMessage) {
        _rewriteCoordinatePair(
          readLatitude: () => message.positionLat,
          readLongitude: () => message.positionLong,
          writeLatitude: (double? value) => message.positionLat = value,
          writeLongitude: (double? value) => message.positionLong = value,
        );
      } else if (message is LapMessage) {
        _rewriteCoordinatePair(
          readLatitude: () => message.startPositionLat,
          readLongitude: () => message.startPositionLong,
          writeLatitude: (double? value) => message.startPositionLat = value,
          writeLongitude: (double? value) => message.startPositionLong = value,
        );
        _rewriteCoordinatePair(
          readLatitude: () => message.endPositionLat,
          readLongitude: () => message.endPositionLong,
          writeLatitude: (double? value) => message.endPositionLat = value,
          writeLongitude: (double? value) => message.endPositionLong = value,
        );
      } else if (message is SessionMessage) {
        _rewriteCoordinatePair(
          readLatitude: () => message.startPositionLat,
          readLongitude: () => message.startPositionLong,
          writeLatitude: (double? value) => message.startPositionLat = value,
          writeLongitude: (double? value) => message.startPositionLong = value,
        );
        _rewriteCoordinatePair(
          readLatitude: () => message.necLat,
          readLongitude: () => message.necLong,
          writeLatitude: (double? value) => message.necLat = value,
          writeLongitude: (double? value) => message.necLong = value,
        );
        _rewriteCoordinatePair(
          readLatitude: () => message.swcLat,
          readLongitude: () => message.swcLong,
          writeLatitude: (double? value) => message.swcLat = value,
          writeLongitude: (double? value) => message.swcLong = value,
        );
      }
    }

    fitFile.crc = null;

    final Directory cacheDirectory = await _loadCacheDirectory();
    final File outputFile = await _createOutputFile(cacheDirectory);
    await outputFile.writeAsBytes(fitFile.toBytes());
    return outputFile;
  }

  void _rewriteCoordinatePair({
    required double? Function() readLatitude,
    required double? Function() readLongitude,
    required void Function(double? value) writeLatitude,
    required void Function(double? value) writeLongitude,
  }) {
    final double? latitude = readLatitude();
    final double? longitude = readLongitude();

    if (latitude == null || longitude == null) {
      return;
    }

    final (double convertedLatitude, double convertedLongitude) =
        CoordinateConverter.gcj02ToWgs84Exact(latitude, longitude);

    if (!_isValidLatitude(convertedLatitude) ||
        !_isValidLongitude(convertedLongitude)) {
      return;
    }

    writeLatitude(_roundToFitCoordinatePrecision(convertedLatitude));
    writeLongitude(_roundToFitCoordinatePrecision(convertedLongitude));
  }

  bool _isValidLatitude(double value) {
    return value >= -90 && value <= 90;
  }

  bool _isValidLongitude(double value) {
    return value >= -180 && value <= 180;
  }

  double _roundToFitCoordinatePrecision(double value) {
    final int semicircles = (value * 2147483648 / 180.0).round();
    return semicircles * 180.0 / 2147483648;
  }

  Future<File> _createOutputFile(Directory cacheDirectory) async {
    await cacheDirectory.create(recursive: true);

    final Directory outputDirectory = await cacheDirectory.createTemp(
      'fit-coordinate-rewrite-',
    );
    return File('${outputDirectory.path}/rewritten.fit');
  }
}
