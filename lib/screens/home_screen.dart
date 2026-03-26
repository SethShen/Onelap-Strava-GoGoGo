import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/sync_summary.dart';
import '../services/onelap_client.dart';
import '../services/settings_service.dart';
import '../services/state_store.dart';
import '../services/strava_client.dart';
import '../services/sync_engine.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _stateStore = StateStore();
  final _settingsService = SettingsService();

  bool _syncing = false;
  String? _error;
  String? _lastSyncTime;

  static const _githubUrl = 'https://github.com/Tyan66666/Onelap-Strava-GoGoGo';
  static const _xiaohongshuUrl = 'https://xhslink.com/m/2SMVhuDAzdq';

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final t = await _stateStore.lastSuccessSyncTime();
    if (mounted) setState(() => _lastSyncTime = t);
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
      }
    }
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _error = null;
    });

    try {
      final settings = await _settingsService.loadSettings();
      final username = settings[SettingsService.keyOneLapUsername] ?? '';
      final password = settings[SettingsService.keyOneLapPassword] ?? '';
      final clientId = settings[SettingsService.keyStravaClientId] ?? '';
      final clientSecret =
          settings[SettingsService.keyStravaClientSecret] ?? '';
      final refreshToken =
          settings[SettingsService.keyStravaRefreshToken] ?? '';
      final accessToken = settings[SettingsService.keyStravaAccessToken] ?? '';
      final expiresAt =
          int.tryParse(settings[SettingsService.keyStravaExpiresAt] ?? '0') ??
          0;

      if (username.isEmpty ||
          password.isEmpty ||
          clientId.isEmpty ||
          clientSecret.isEmpty ||
          refreshToken.isEmpty) {
        setState(() {
          _error = '请先在设置中填写凭证';
          _syncing = false;
        });
        return;
      }

      final oneLap = OneLapClient(
        baseUrl: 'https://www.onelap.cn',
        username: username,
        password: password,
      );
      final strava = StravaClient(
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        accessToken: accessToken,
        expiresAt: expiresAt,
      );
      final engine = SyncEngine(
        oneLapClient: oneLap,
        stravaClient: strava,
        stateStore: _stateStore,
      );

      final summary = await engine.runOnce(
        lookbackDays:
            int.tryParse(settings[SettingsService.keyLookbackDays] ?? '') ?? 3,
      );
      await _loadLastSyncTime();
      setState(() => _syncing = false);

      if (mounted) _showSyncResult(summary);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _syncing = false;
      });
    }
  }

  void _showSyncResult(SyncSummary summary) {
    // 风控中止
    if (summary.abortedReason == 'risk-control') {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('同步中止'),
          content: const Text('OneLap 风控拦截，请稍后再试'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
      return;
    }

    final bool hasFailures = summary.failed > 0;
    final bool hasSuccess = summary.success > 0;
    final bool nothingToSync = summary.success == 0 && summary.failed == 0;

    String title;
    if (hasFailures) {
      title = '同步完成';
    } else if (nothingToSync) {
      title = '没有要同步的啦🎉';
    } else {
      title = '成功同步 ${summary.success} 个🎉';
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 有失败时显示成功/失败计数
              if (hasFailures) ...[
                if (hasSuccess)
                  Text(
                    '成功：${summary.success} 个',
                    style: const TextStyle(color: Colors.green),
                  ),
                Text(
                  '失败：${summary.failed} 个',
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 8),
                const Text(
                  '本应用为个人开源项目，与 OneLap 及 Strava 官方无任何关联。'
                  '使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。\n\n'
                  '本应用不向任何第三方或作者服务器收集、传输用户数据。'
                  '活动数据仅在你主动触发同步时上传至 Strava。所有凭证仅保存在你的设备本地。',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 4),
                ...summary.failureReasons.map(
                  (r) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      r,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // 点赞引导
              const Text('顺手给项目点个赞吧~'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _launchUrl(_githubUrl),
                child: const Text(
                  'GitHub 开源地址',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _launchUrl(_xiaohongshuUrl),
                child: const Text(
                  '小红书主页',
                  style: TextStyle(
                    color: Colors.red,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showAbout() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于 顽爪爪同步'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '一款可以同步顽鹿 FIT 文件到 Strava 的小工具',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('免责声明', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                '本应用为个人开源项目，与 OneLap 及 Strava 官方无任何关联。'
                '使用本应用所产生的一切后果由用户自行承担，作者不承担任何责任。\n\n'
                '本应用不收集、不存储、不上传任何用户数据。所有凭证仅保存在你的设备本地。',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _launchUrl(_githubUrl),
            child: const Text('GitHub 项目主页'),
          ),
          TextButton(
            onPressed: () => _launchUrl(_xiaohongshuUrl),
            child: const Text('作者小红书'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('顽爪爪同步'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: '关于',
            onPressed: _showAbout,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_lastSyncTime != null)
              Text(
                '上次同步: $_lastSyncTime',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _syncing ? null : _sync,
              child: const Text('立即同步'),
            ),
            const SizedBox(height: 24),
            if (_syncing) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
