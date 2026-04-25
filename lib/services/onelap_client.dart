import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../models/onelap_activity.dart';

class OnelapRiskControlError implements Exception {
  final String message;
  const OnelapRiskControlError(this.message);
  @override
  String toString() => 'OnelapRiskControlError: $message';
}

class OneLapClient {
  final String baseUrl;
  final String username;
  final String password;
  final List<String> geoFallbackBaseUrls;
  final String otmBaseUrl;
  late final Dio _dio;
  String? _token;

  OneLapClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.geoFallbackBaseUrls = const <String>[
      'https://u.onelap.cn',
      'https://www.onelap.cn',
    ],
    this.otmBaseUrl = 'https://otm.onelap.cn',
    Dio? dio,
  }) {
    final cookieJar = CookieJar();
    _dio =
        dio ??
        Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
          ),
        );
    _dio.interceptors.add(CookieManager(cookieJar));
  }

  Future<void> login() async {
    final response = await _dio.post(
      '$baseUrl/api/login',
      data: FormData.fromMap({'account': username, 'password': _passwordHash}),
    );
    final payload = response.data as Map<String, dynamic>;
    final code = payload['code'];
    if (code != 0 && code != 200) {
      final errorMsg = payload['msg'] ?? payload['message'] ?? payload['error'] ?? 'unknown';
      throw Exception('OneLap login failed: $errorMsg');
    }
    final List<dynamic> data = payload['data'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic>? first = data.isNotEmpty
        ? data.first as Map<String, dynamic>
        : null;
    _token = '${first?['token'] ?? ''}'.trim();
  }

  String get _passwordHash => md5.convert(utf8.encode(password)).toString();

  Future<List<OneLapActivity>> listFitActivities({
    required DateTime since,
    int limit = 50,
  }) async {
    final payload = await _fetchActivitiesPayload();
    final items = (payload['data']['list'] as List? ?? []);
    final cutoff = since.toIso8601String().substring(0, 10);
    final result = <OneLapActivity>[];

    for (final raw in items) {
      final map = raw as Map<String, dynamic>;
      final activityId = '${map['id'] ?? map['activity_id'] ?? ''}';
      final startTime = _parseStartTime(map);
      final distanceKm = _parseDistanceKm(map);
      final timeSeconds = _parseTimeSeconds(map);

      if (activityId.isEmpty) continue;
      if (startTime.isEmpty) continue;
      if (startTime.substring(0, 10).compareTo(cutoff) < 0) continue;

      result.add(
        OneLapActivity(
          activityId: activityId,
          startTime: startTime,
          fitUrl: '',
          recordKey: activityId,
          sourceFilename: 'activity.fit',
          distanceKm: distanceKm,
          timeSeconds: timeSeconds,
        ),
      );
      if (result.length >= limit) break;
    }
    return result;
  }

  Future<Map<String, dynamic>> _fetchActivitiesPayload() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      Response response;
      try {
        response = await _dio.post(
          'http://u.onelap.cn/api/otm/ride_record/list',
          data: jsonEncode({}),
          options: Options(
            contentType: Headers.jsonContentType,
            headers: {
              'Authorization': _token ?? '',
              'Origin': 'http://u.onelap.cn',
              'Referer': 'http://u.onelap.cn/record',
            },
          ),
        );
      } on DioException catch (e) {
        if (attempt == 0) {
          await login();
          continue;
        }
        rethrow;
      }

      if (_requiresLogin(response)) {
        if (attempt == 1) {
          throw Exception('OneLap activities request requires login');
        }
        await login();
        continue;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final code = data['code'];
        final msg = '${data['msg'] ?? data['message'] ?? data['error'] ?? ''}';
        if (code == -2 ||
            msg.toLowerCase().contains('risk') ||
            msg.toLowerCase().contains('风控')) {
          throw OnelapRiskControlError(
            msg.isEmpty ? 'risk control triggered' : msg,
          );
        }
        return data;
      }
      if (attempt == 0) {
        await login();
        continue;
      }
      throw Exception('OneLap activities payload is invalid');
    }
    throw Exception('failed to fetch OneLap activities');
  }

  Future<OneLapActivityDetail?> getActivityDetail(String activityId) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      Response response;
      try {
        response = await _dio.get(
          'http://u.onelap.cn/api/otm/ride_record/analysis/$activityId',
          options: Options(
            headers: {
              'Authorization': _token ?? '',
              'Origin': 'http://u.onelap.cn',
              'Referer': 'http://u.onelap.cn/record/details?id=$activityId',
            },
          ),
        );
      } on DioException catch (e) {
        if (attempt == 0) {
          await login();
          continue;
        }
        rethrow;
      }

      if (_requiresLogin(response)) {
        if (attempt == 1) {
          return null;
        }
        await login();
        continue;
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final code = data['code'];
        if (code != 200) {
          return null;
        }
        final ridingRecord = (data['data'] as Map<String, dynamic>?)?['ridingRecord'] as Map<String, dynamic>?;
        if (ridingRecord == null) {
          return null;
        }
        final durl = '${ridingRecord['durl'] ?? ''}'.trim();
        final fileKey = '${ridingRecord['fileKey'] ?? ''}'.trim();
        // fit_content 已废弃，改用 fileKey + fit_content API
        return OneLapActivityDetail(
          activityId: activityId,
          durl: durl,
          fileKey: fileKey,
          startRidingTime: ridingRecord['startRidingTime'],
          totalDistance: ridingRecord['totalDistance'],
          time: ridingRecord['time'],
        );
      }
      return null;
    }
    return null;
  }

  bool _requiresLogin(Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) return true;
    final ct = (response.headers.value('content-type') ?? '').toLowerCase();
    if (ct.contains('text/html')) return true;
    return false;
  }

  String _parseStartTime(Map<String, dynamic> raw) {
    final value = raw['start_riding_time'];
    if (value != null) return '$value';

    final startTime = raw['start_time'];
    if (startTime != null) return '$startTime';

    final createdAt = raw['created_at'];
    if (createdAt is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        createdAt * 1000,
        isUtc: true,
      ).toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');
    }
    if (createdAt is String) {
      final ts = int.tryParse(createdAt);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          ts * 1000,
          isUtc: true,
        ).toIso8601String().replaceFirst(RegExp(r'\.\d+'), '');
        }
      return createdAt;
    }
    return '';
  }

  double? _parseDistanceKm(Map<String, dynamic> raw) {
    final value = raw['distance_km'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _parseTimeSeconds(Map<String, dynamic> raw) {
    final value = raw['time_seconds'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  (String, String) _buildRecordIdentity(Map<String, dynamic> raw) {
    final fileKey = '${raw['fileKey'] ?? ''}'.trim();
    if (fileKey.isNotEmpty) return ('fileKey:$fileKey', fileKey);

    final fitUrl = '${raw['fit_url'] ?? raw['fitUrl'] ?? ''}'.trim();
    if (fitUrl.isNotEmpty) return ('fitUrl:$fitUrl', fitUrl);

    final durl = '${raw['durl'] ?? ''}'.trim();
    if (durl.isNotEmpty) return ('durl:$durl', durl);

    return ('', '');
  }

  String _normalizeFitFilename(String value) {
    var text = value.trim();
    if (text.isEmpty) text = 'activity.fit';

    final uri = Uri.tryParse(text);
    var filename = (uri != null && uri.path.isNotEmpty)
        ? uri.path.split('/').last
        : text.split('/').last;

    filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_').trim();
    if (filename.isEmpty) filename = 'activity';
    if (!filename.toLowerCase().endsWith('.fit')) filename = '$filename.fit';
    return filename;
  }

  Future<File> downloadFit(
    String fitUrl,
    String sourceFilename,
    Directory outputDir, {
    OneLapActivity? activity,
  }) async {
    if (activity != null) {
      final detail = await getActivityDetail(activity.activityId);
      if (detail != null && detail.fileKey.isNotEmpty) {
        // 使用新的 fit_content 接口下载
        final encodedFileKey = base64.encode(utf8.encode(detail.fileKey));
        final fitContentUrl = 'http://u.onelap.cn/api/otm/ride_record/analysis/fit_content/$encodedFileKey';
        return _downloadFromUrl(fitContentUrl, detail.fileKey, outputDir, activityId: activity.activityId);
      }
    }

    if (fitUrl.isNotEmpty) {
      return _downloadFromUrl(fitUrl, sourceFilename, outputDir);
    }

    throw Exception('No download URL available');
  }

  Future<File> _downloadFromUrl(
    String durl,
    String fileKey,
    Directory outputDir, {
    String? activityId,
  }) async {
    final safeName = _normalizeFitFilename(fileKey.isNotEmpty ? fileKey : durl);
    await outputDir.create(recursive: true);
    final targetPath = File('${outputDir.path}/$safeName');

    final tempPath = File(
      '${outputDir.path}/.${safeName}_${DateTime.now().millisecondsSinceEpoch}.tmp',
    );

    try {
      await _dio.download(
        durl, 
        tempPath.path,
        options: Options(
          headers: {
            'Authorization': _token ?? '',
            'Origin': 'http://u.onelap.cn',
            'Referer': activityId != null 
                ? 'http://u.onelap.cn/record/details?id=$activityId' 
                : 'http://u.onelap.cn',
          },
        ),
      );
    } on DioException catch (e) {
      await tempPath.delete().catchError((_) => tempPath);
      rethrow;
    }

    final tempBytes = await tempPath.readAsBytes();
    final tempHash = sha256.convert(tempBytes).toString();

    if (await targetPath.exists()) {
      final existingHash = sha256
          .convert(await targetPath.readAsBytes())
          .toString();
      if (existingHash == tempHash) {
        await tempPath.delete();
        return targetPath;
      }
      var index = 2;
      while (true) {
        final stem = safeName.replaceAll(
          RegExp(r'\.fit$', caseSensitive: false),
          '',
        );
        final candidate = File('${outputDir.path}/$stem-$index.fit');
        if (!await candidate.exists()) {
          await tempPath.rename(candidate.path);
          return candidate;
        }
        final candidateHash = sha256
            .convert(await candidate.readAsBytes())
            .toString();
        if (candidateHash == tempHash) {
          await tempPath.delete();
          return candidate;
        }
        index++;
      }
    }

    await tempPath.rename(targetPath.path);
    return targetPath;
  }
}

class OneLapActivityDetail {
  final String activityId;
  final String durl;
  final String fileKey;
  final dynamic startRidingTime;
  final dynamic totalDistance;
  final dynamic time;

  OneLapActivityDetail({
    required this.activityId,
    required this.durl,
    required this.fileKey,
    this.startRidingTime,
    this.totalDistance,
    this.time,
  });
}