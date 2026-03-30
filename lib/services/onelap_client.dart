import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
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
  late final Dio _dio;

  OneLapClient({
    required this.baseUrl,
    required this.username,
    required this.password,
    this.geoFallbackBaseUrls = const <String>[
      'https://u.onelap.cn',
      'https://www.onelap.cn',
    ],
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
    final pwdHash = md5.convert(utf8.encode(password)).toString();
    final response = await _dio.post(
      '$baseUrl/api/login',
      data: FormData.fromMap({'account': username, 'password': pwdHash}),
    );
    final payload = response.data as Map<String, dynamic>;
    final code = payload['code'];
    if (code != 0 && code != 200) {
      throw Exception(
        'OneLap login failed: ${payload['msg'] ?? payload['message'] ?? payload['error'] ?? 'unknown'}',
      );
    }
  }

  Future<List<OneLapActivity>> listFitActivities({
    required DateTime since,
    int limit = 50,
  }) async {
    final payload = await _fetchActivitiesPayload();
    final items = (payload['data'] as List? ?? []);
    final cutoff = since.toIso8601String().substring(0, 10);
    final result = <OneLapActivity>[];

    for (final raw in items) {
      final map = raw as Map<String, dynamic>;
      final activityId = '${map['id'] ?? map['activity_id'] ?? ''}';
      final startTime = _parseStartTime(map);
      final fitUrl = '${map['fit_url'] ?? map['fitUrl'] ?? map['durl'] ?? ''}'
          .trim();
      final (recordKey, sourceFilename) = _buildRecordIdentity(map);

      if (activityId.isEmpty || startTime.isEmpty || fitUrl.isEmpty) continue;
      if (startTime.substring(0, 10).compareTo(cutoff) < 0) continue;
      if (recordKey.isEmpty) continue;

      result.add(
        OneLapActivity(
          activityId: activityId,
          startTime: startTime,
          fitUrl: fitUrl,
          recordKey: recordKey,
          sourceFilename: sourceFilename,
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
        response = await _dio.get('http://u.onelap.cn/analysis/list');
      } on DioException catch (_) {
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
        // Check for risk control response
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

  bool _requiresLogin(Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) return true;
    final ct = (response.headers.value('content-type') ?? '').toLowerCase();
    if (ct.contains('text/html')) return true;
    return false;
  }

  String _parseStartTime(Map<String, dynamic> raw) {
    final value = raw['start_time'];
    if (value != null) return '$value';

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

    // Extract filename from URL path
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
    Directory outputDir,
  ) async {
    final List<String> downloadUrls = _buildDownloadUrls(fitUrl);

    final safeName = _normalizeFitFilename(sourceFilename);
    await outputDir.create(recursive: true);
    final targetPath = File('${outputDir.path}/$safeName');

    // Download to temp file
    final tempPath = File(
      '${outputDir.path}/.${safeName}_${DateTime.now().millisecondsSinceEpoch}.tmp',
    );
    try {
      DioException? lastError;
      for (var i = 0; i < downloadUrls.length; i++) {
        final String downloadUrl = downloadUrls[i];
        try {
          await _dio.download(downloadUrl, tempPath.path);
          lastError = null;
          break;
        } on DioException catch (e) {
          lastError = e;
          final int? statusCode = e.response?.statusCode;
          final bool canFallback =
              i < downloadUrls.length - 1 && statusCode == 404;
          if (!canFallback) rethrow;
          if (await tempPath.exists()) {
            await tempPath.delete().catchError((_) => tempPath);
          }
        }
      }

      if (lastError != null) throw lastError;
    } catch (_) {
      await tempPath.delete().catchError((_) => tempPath);
      rethrow;
    }

    // SHA-256 dedup
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
      // Different content — find a unique name
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

  List<String> _buildDownloadUrls(String fitUrl) {
    final String value = fitUrl.trim();
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return <String>[value];
    }

    final Uri baseUri = Uri.parse(baseUrl);
    final Uri relativeUri = Uri.parse(
      value.startsWith('/') ? value : '/$value',
    );
    final String normalizedPath = relativeUri.path.replaceFirst(
      RegExp(r'^/'),
      '',
    );
    final List<String> urls = <String>[
      baseUri.resolveUri(relativeUri).toString(),
    ];

    if (normalizedPath.startsWith('geo/')) {
      for (final String fallbackBaseUrl in geoFallbackBaseUrls) {
        final Uri fallbackBaseUri = Uri.parse(fallbackBaseUrl);
        final Uri fallbackUri = fallbackBaseUri.resolveUri(relativeUri);
        final String fallbackUrl = fallbackUri.toString();
        if (!urls.contains(fallbackUrl)) {
          urls.add(fallbackUrl);
        }
      }
    }
    return urls;
  }
}
