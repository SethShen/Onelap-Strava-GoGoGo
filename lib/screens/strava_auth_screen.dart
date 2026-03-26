import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/strava_oauth_service.dart';

class StravaAuthScreen extends StatefulWidget {
  final String clientId;
  final String clientSecret;

  const StravaAuthScreen({
    super.key,
    required this.clientId,
    required this.clientSecret,
  });

  @override
  State<StravaAuthScreen> createState() => _StravaAuthScreenState();
}

class _StravaAuthScreenState extends State<StravaAuthScreen> {
  late final WebViewController _controller;
  final _oauthService = StravaOAuthService();
  bool _exchanging = false;
  bool _didComplete = false;

  @override
  void initState() {
    super.initState();
    final authorizeUrl = _oauthService.buildAuthorizeUrl(widget.clientId);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('http://localhost/callback')) {
              _handleCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            // Only surface page-level errors (not sub-resource failures)
            if (!_didComplete && mounted && error.isForMainFrame == true) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('页面加载失败: ${error.description}'),
                  action: SnackBarAction(
                    label: '重试',
                    onPressed: () => _controller.reload(),
                  ),
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(authorizeUrl));
  }

  Future<void> _handleCallback(String url) async {
    if (_exchanging || _didComplete) return;
    setState(() => _exchanging = true);

    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];

    if (code == null || code.isEmpty) {
      setState(() => _exchanging = false);
      if (mounted) Navigator.of(context).pop(false);
      return;
    }

    try {
      await _oauthService.exchangeCode(
        widget.clientId,
        widget.clientSecret,
        code,
      );
      _didComplete = true;
      if (mounted) Navigator.of(context).pop(true);
    } on StravaOAuthException catch (e) {
      setState(() => _exchanging = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('授权失败: $e')));
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('授权 Strava'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_exchanging)
            const ColoredBox(
              color: Color(0x88000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
