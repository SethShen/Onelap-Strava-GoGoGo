import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  SyncSummary? _lastSummary;
  String? _error;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
  }

  Future<void> _loadLastSyncTime() async {
    final t = await _stateStore.lastSuccessSyncTime();
    if (mounted) setState(() => _lastSyncTime = t);
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _error = null;
      _lastSummary = null;
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
      setState(() {
        _lastSummary = summary;
        _syncing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _syncing = false;
      });
    }
  }

  void _showAbout() {
    const repoUrl = 'https://github.com/Tyan66666/Onelap-Strava-GoGoGo';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '顽鹿 Strava 同步',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 8),
              Text('开源地址：\n$repoUrl'),
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
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: repoUrl));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('链接已复制到剪贴板')));
            },
            child: const Text('复制链接'),
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
        title: const Text('OneLap → Strava'),
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
            if (_lastSummary != null) ...[
              if (_lastSummary!.abortedReason == 'risk-control')
                const Text(
                  'OneLap 风控拦截，请稍后再试',
                  style: TextStyle(color: Colors.orange),
                )
              else ...[
                Text(
                  '获取: ${_lastSummary!.fetched}   去重: ${_lastSummary!.deduped}',
                ),
                Text(
                  '成功: ${_lastSummary!.success}   失败: ${_lastSummary!.failed}',
                ),
              ],
            ],
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }
}
