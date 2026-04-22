import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'settings_service.dart';
import 'package:http_parser/http_parser.dart';
import 'package:encrypt/encrypt.dart';

class XingzheRetriableError implements Exception {
  final String message;
  const XingzheRetriableError(this.message);
  @override
  String toString() => 'XingzheRetriableError: $message';
}

class XingzhePermanentError implements Exception {
  final String message;
  const XingzhePermanentError(this.message);
  @override
  String toString() => 'XingzhePermanentError: $message';
}

class XingzheClient {
  String username;
  String password;
  String? authToken;
  final Dio _dio;

  XingzheClient({
    required this.username,
    required this.password,
    this.authToken,
    Dio? dio,
    String? sessionId,
  }) : _dio = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
              'Accept-Encoding': 'gzip, deflate',
            },
          ),
        ) {
    if (sessionId != null && sessionId.isNotEmpty) {
      _dio.options.headers['Cookie'] = 'sessionid=$sessionId; _XingzheWeb_Token=true';
      print('[Xingzhe] 使用提供的 sessionid: $sessionId');
    }
  }

  static Future<XingzheClient> create({
    required String username,
    required String password,
    Dio? dio,
  }) async {
    final settingsService = SettingsService();
    final settings = await settingsService.loadSettings();
    final sessionId = settings[SettingsService.keyXingzheSessionId];
    
    return XingzheClient(
      username: username,
      password: password,
      dio: dio,
      sessionId: sessionId,
    );
  }

  static const String publicKey = '''-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDmuQkBbijudDAJgfffDeeIButq
WHZvUwcRuvWdg89393FSdz3IJUHc0rgI/S3WuU8N0VePJLmVAZtCOK4qe4FY/eKm
WpJmn7JfXB4HTMWjPVoyRZmSYjW4L8GrWmh51Qj7DwpTADadF3aq04o+s1b8LXJa
8r6+TIqqL5WUHtRqmQIDAQAB
-----END PUBLIC KEY-----
''';

  static String encryptPassword(String password) {
    print('[Xingzhe] encryptPassword 开始加密密码');
    print('[Xingzhe] 公钥长度: ${publicKey.length}');

    final parser = RSAKeyParser();
    final rsaPublicKey = parser.parse(publicKey) as RSAPublicKey;
    print('[Xingzhe] 公钥解析成功');

    // 使用 PKCS1_v1_5 加密模式，与 Python 版本一致
    final cipher = PKCS1Encoding(RSAEngine());
    cipher.init(true, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));
    print('[Xingzhe] 加密器初始化成功');

    final passwordBytes = utf8.encode(password);
    final encryptedBytes = cipher.process(passwordBytes);
    final encrypted = base64.encode(encryptedBytes);
    print('[Xingzhe] 密码加密成功，加密结果长度: ${encrypted.length}，加密结果: $encrypted');

    return encrypted;
  }

  static Future<XingzheClient> login({
    required String username,
    required String password,
    Dio? dio,
  }) async {
    print('[Xingzhe] login 开始登录，用户名: $username');

    final dioInstance = dio ?? Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
              'Accept-Encoding': 'gzip, deflate',
              'Content-Type': 'application/json',
            },
          ),
        );

    final encryptedPassword = encryptPassword(password);
    print('[Xingzhe] login 密码加密完成');

    print('[Xingzhe] login 发送登录请求到行者服务器');
    Response response;
    try {
      response = await dioInstance.post(
        'https://www.imxingzhe.com/api/v1/user/login/',
        data: {
          'account': username,
          'password': encryptedPassword,
        },
        options: Options(
          contentType: 'application/json',
        ),
      );
    } on DioException catch (e) {
      print('[Xingzhe] login 请求失败，错误: ${e.message}');
      print('[Xingzhe] login 响应状态码: ${e.response?.statusCode}');
      print('[Xingzhe] login 响应数据: ${e.response?.data}');
      throw XingzhePermanentError('行者登录失败: ${e.response?.statusCode} ${e.response?.data}');
    }
    print('[Xingzhe] login 收到响应，状态码: ${response.statusCode}');
    print('[Xingzhe] login 响应数据: ${response.data}');

    if (response.statusCode != 200) {
      print('[Xingzhe] login 登录失败，状态码: ${response.statusCode}');
      throw XingzhePermanentError('行者登录失败: ${response.statusCode}');
    }

    final payload = response.data as Map<String, dynamic>;
    if (payload['data'] == null) {
      print('[Xingzhe] login 登录失败，响应数据为空');
      throw XingzhePermanentError('行者登录失败: ${payload['message'] ?? '未知错误'}');
    }

    // 打印登录成功信息
    print('[Xingzhe] login 登录成功，用户名: ${payload['data']['username']}');

    // 从响应头中提取 cookies
    final setCookie = response.headers['set-cookie'];
    print('[Xingzhe] login Set-Cookie: $setCookie');
    final String extractedSessionId =
        setCookie != null ? _extractSessionId(setCookie) : '';

    if (extractedSessionId.isNotEmpty) {
      dioInstance.options.headers['Cookie'] =
          'sessionid=$extractedSessionId; _XingzheWeb_Token=true';
      print('[Xingzhe] login 设置 Cookie: ${dioInstance.options.headers['Cookie']}');
      final settingsService = SettingsService();
      await settingsService.saveSettings({
        SettingsService.keyXingzheSessionId: extractedSessionId,
        SettingsService.keyXingzheUsername: username,
        SettingsService.keyXingzhePassword: password,
      });
      print('[Xingzhe] login 持久化保存 sessionid=$extractedSessionId');
    }

    return XingzheClient(
      username: username,
      password: password,
      authToken: null,
      dio: dioInstance,
      sessionId: extractedSessionId.isNotEmpty ? extractedSessionId : null,
    );
  }

  /// 从 Set-Cookie header 列表中提取 sessionid
  static String _extractSessionId(List<String> setCookies) {
    for (final cookie in setCookies) {
      final match = RegExp(r'sessionid=([^;]+)').firstMatch(cookie);
      if (match != null) {
        return match.group(1)!;
      }
    }
    return '';
  }

  Future<void> ensureAuthenticated() async {
    // 依赖 session 保持认证状态，ensureAuthenticated 仅打日志
    print('[Xingzhe] ensureAuthenticated 检查认证状态');
  }

  Future<int> uploadFit(File file, {int retries = 3}) async {
    final String filename = file.path.split('/').last;
    print('[Xingzhe] uploadFit 开始上传文件，文件名: $filename');
    print('[Xingzhe] uploadFit 文件路径: ${file.path}');
    print('[Xingzhe] uploadFit 文件是否存在: ${await file.exists()}');
    if (await file.exists()) {
      final fileSize = await file.length();
      print('[Xingzhe] uploadFit 文件大小: $fileSize 字节');
    }

    // 检查当前会话状态
    print('[Xingzhe] uploadFit 当前 Cookies: ${_dio.options.headers['Cookie']}');

    for (var attempt = 1; attempt <= retries; attempt++) {
      print('[Xingzhe] uploadFit 尝试第 $attempt 次上传');
      
      Response response;
      try {
        // 计算文件的 MD5 哈希值
        print('[Xingzhe] uploadFit 读取文件内容');
        final fileBytes = await file.readAsBytes();
        print('[Xingzhe] uploadFit 文件读取完成，字节长度: ${fileBytes.length}');
        final md5Hash = md5.convert(fileBytes).toString();
        print('[Xingzhe] uploadFit 文件 MD5: $md5Hash');

        // 构建 FormData
        print('[Xingzhe] uploadFit 构建 FormData');
        final formData = FormData.fromMap({
          'file_source': 'undefined',
          'fit_filename': filename,
          'md5': md5Hash,
          'name': filename,
          'sport': '3',
          'fit_file': await MultipartFile.fromFile(
            file.path,
            filename: filename,
            contentType: MediaType('application', 'octet-stream'),
          ),
        });
        print('[Xingzhe] uploadFit FormData 构建完成');

        // 发送上传请求
        print('[Xingzhe] uploadFit 发送上传请求到行者服务器');
        response = await _dio.post(
          'https://www.imxingzhe.com/api/v1/fit/upload/',
          data: formData,
          options: Options(
            followRedirects: false,
            validateStatus: (status) => true,
          ),
        );
        print('[Xingzhe] uploadFit 收到上传响应，状态码: ${response.statusCode}');
        print('[Xingzhe] uploadFit 响应数据: ${response.data}');
      } on DioException catch (e) {
        print('[Xingzhe] uploadFit 请求失败，错误: ${e.message}');
        print('[Xingzhe] uploadFit 响应状态码: ${e.response?.statusCode}');
        print('[Xingzhe] uploadFit 响应数据: ${e.response?.data}');
        
        final status = e.response?.statusCode ?? 0;
        if (status >= 500 && attempt < retries) {
          print('[Xingzhe] uploadFit 服务器错误，重试上传');
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }
        if (status >= 500) {
          throw XingzheRetriableError('xingzhe upload 5xx: $status');
        }
        if (status >= 400) {
          String detail;
          try {
            detail = '${e.response?.data}';
          } catch (_) {
            detail = '';
          }
          throw XingzhePermanentError(
            'xingzhe upload failed: $status detail=$detail',
          );
        }
        rethrow;
      } catch (e) {
        print('[Xingzhe] uploadFit 发生未知错误: $e');
        rethrow;
      }
      
      try {
        print('[Xingzhe] uploadFit 响应状态码: ${response.statusCode}');
        if (response.statusCode == 500) {
          print('[Xingzhe] uploadFit 服务器内部错误，尝试重新登录');
          // 重新登录
          await login(username: username, password: password, dio: _dio);
          if (attempt < retries) {
            print('[Xingzhe] uploadFit 重新登录后重试');
            await Future.delayed(const Duration(seconds: 1));
            continue;
          }
          throw XingzheRetriableError('xingzhe upload 5xx: ${response.statusCode}');
        }
        
        final payload = response.data as Map<String, dynamic>;
        print('[Xingzhe] uploadFit 解析响应数据: $payload');

        // 9006 = 文件已上传（幂等成功），从 msg 中提取已存在的 activity_id
        if (payload['code'] == 9006) {
          final msg = '${payload['msg'] ?? ''}';
          final match = RegExp(r'(\d{4,})').firstMatch(msg);
          final existingId = match != null ? int.tryParse(match.group(1)!) ?? 0 : 0;
          print('[Xingzhe] uploadFit 文件已存在，activity_id=$existingId，视为幂等成功');
          return existingId;
        }

        if (payload['code'] != 0) {
          print('[Xingzhe] uploadFit 上传失败，错误信息: ${payload['msg'] ?? '未知错误'}');
          throw XingzhePermanentError('xingzhe upload failed: ${payload['msg'] ?? '未知错误'}');
        }

        // 行者上传成功后返回 workout_id，即真实活动 ID
        final data = payload['data'] as Map<String, dynamic>?;
        final workoutIdRaw = data?['workout_id'] ?? data?['id'];
        if (workoutIdRaw == null) {
          print('[Xingzhe] uploadFit 响应缺少 workout_id，返回 0');
          return 0;
        }
        final int workoutId = workoutIdRaw is int ? workoutIdRaw : int.tryParse('$workoutIdRaw') ?? 0;
        print('[Xingzhe] uploadFit 上传成功，workout_id=$workoutId');
        return workoutId;
      } catch (e) {
        print('[Xingzhe] uploadFit 解析响应失败: $e');
        rethrow;
      }
    }
    print('[Xingzhe] uploadFit 尝试次数用尽，上传失败');
    throw XingzheRetriableError('xingzhe upload exhausted retries');
  }



  Future<Map<String, dynamic>> pollUpload(
    int uploadId, {
    int maxAttempts = 10,
  }) async {
    // 行者上传接口是同步的，uploadFit 返回的 workout_id 就是真实活动 ID
    // pollUpload 在这里只做兜底：如果 uploadId 为 0（之前没拿到 workout_id），
    // 尝试通过 MD5 查一下已上传的活动。
    if (uploadId > 0) {
      print('[Xingzhe] pollUpload 行者同步上传，workout_id=$uploadId，直接返回');
      return {
        'status': 'complete',
        'activity_id': uploadId,
      };
    }

    // 兜底查询（uploadId=0 时才走到这里）
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final resp = await _dio.get('https://www.imxingzhe.com/api/v1/fit/list/');
        final payload = resp.data as Map<String, dynamic>;
        if (payload['code'] == 0) {
          final List<dynamic> items = payload['data'] as List<dynamic>? ?? [];
          if (items.isNotEmpty) {
            final latest = items.first as Map<String, dynamic>;
            final id = latest['id'] ?? latest['workout_id'];
            print('[Xingzhe] pollUpload 兜底查到活动 ID=$id');
            return {'status': 'complete', 'activity_id': id};
          }
        }
      } catch (e) {
        print('[Xingzhe] pollUpload 兜底查询失败: $e');
      }
      if (attempt < maxAttempts - 1) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return {'status': 'unknown', 'activity_id': null};
  }
}
