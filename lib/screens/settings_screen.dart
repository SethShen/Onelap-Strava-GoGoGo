import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import 'strava_auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _controllers = <String, TextEditingController>{};
  bool _loading = true;

  static const _obscured = {
    SettingsService.keyOneLapPassword,
    SettingsService.keyStravaClientSecret,
  };

  static const _labels = {
    SettingsService.keyOneLapUsername: 'OneLap 用户名',
    SettingsService.keyOneLapPassword: 'OneLap 密码',
    SettingsService.keyStravaClientId: 'Strava Client ID',
    SettingsService.keyStravaClientSecret: 'Strava Client Secret',
    SettingsService.keyStravaRefreshToken: 'Strava Refresh Token',
    SettingsService.keyStravaAccessToken: 'Strava Access Token',
    SettingsService.keyStravaExpiresAt: 'Strava Expires At (Unix timestamp)',
    SettingsService.keyLookbackDays: '同步最近几天（默认 3）',
  };

  @override
  void initState() {
    super.initState();
    for (final key in SettingsService.allKeys) {
      _controllers[key] = TextEditingController();
    }
    _load();
  }

  Future<void> _load() async {
    final values = await _settingsService.loadSettings();
    for (final key in SettingsService.allKeys) {
      _controllers[key]!.text = values[key] ?? '';
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    final values = {
      for (final key in SettingsService.allKeys)
        key: _controllers[key]!.text.trim(),
    };
    await _settingsService.saveSettings(values);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    }
  }

  Future<void> _authorizeStrava() async {
    final clientId = _controllers[SettingsService.keyStravaClientId]!.text
        .trim();
    final clientSecret = _controllers[SettingsService.keyStravaClientSecret]!
        .text
        .trim();

    if (clientId.isEmpty || clientSecret.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先填写 Strava Client ID 和 Client Secret'),
          ),
        );
      }
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            StravaAuthScreen(clientId: clientId, clientSecret: clientSecret),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Strava 授权成功')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('授权取消或失败')));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showStravaApiInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于 Strava API 凭证'),
        content: const SingleChildScrollView(
          child: Text(
            'Strava 对个人开发者的 API 访问有严格限制，每个应用每 15 分钟最多 200 次请求、每天 2000 次。\n\n'
            '为了不让所有用户共享同一个配额，本应用需要你使用自己的 Strava API 应用凭证。\n\n'
            '注册步骤：\n'
            '1. 登录 https://www.strava.com/settings/api\n'
            '2. 创建一个新应用，"Authorization Callback Domain" 填写 localhost\n'
            '3. 创建后复制 Client ID 和 Client Secret 填入此处\n'
            '4. 点击"授权 Strava"按钮完成授权，Access Token 和 Refresh Token 将自动填入',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'OneLap 账号',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          for (final key in [
            SettingsService.keyOneLapUsername,
            SettingsService.keyOneLapPassword,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[key],
                obscureText: _obscured.contains(key),
                decoration: InputDecoration(
                  labelText: _labels[key],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            '同步设置',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _controllers[SettingsService.keyLookbackDays],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _labels[SettingsService.keyLookbackDays],
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Strava 凭证',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '为什么需要填写 Strava 凭证？',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline),
                tooltip: '查看说明',
                onPressed: _showStravaApiInfo,
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: _authorizeStrava,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('授权 Strava'),
          ),
          const SizedBox(height: 12),
          for (final key in [
            SettingsService.keyStravaClientId,
            SettingsService.keyStravaClientSecret,
            SettingsService.keyStravaRefreshToken,
            SettingsService.keyStravaAccessToken,
            SettingsService.keyStravaExpiresAt,
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _controllers[key],
                obscureText: _obscured.contains(key),
                decoration: InputDecoration(
                  labelText: _labels[key],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _save, child: const Text('保存')),
        ],
      ),
    );
  }
}
