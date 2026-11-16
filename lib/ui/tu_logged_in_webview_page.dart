import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tu_api_service.dart';

class TuLoggedInWebViewPage extends StatefulWidget {
  final String fnum;
  final String egn;

  const TuLoggedInWebViewPage({
    super.key,
    required this.fnum,
    required this.egn,
  });

  @override
  State<TuLoggedInWebViewPage> createState() => _TuLoggedInWebViewPageState();
}

class _TuLoggedInWebViewPageState extends State<TuLoggedInWebViewPage> {
  late final WebViewController _controller;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
          onWebResourceError: (e) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = e.description;
            });
          },
        ),
      );
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final api = TuApiService();
      await api.getHtmlAsync(widget.fnum, widget.egn, deistvie: '9');

      await _cookieManager.clearCookies();

      for (final cookie in api.cookies) {
        final idx = cookie.indexOf('=');
        if (idx <= 0) continue;

        final name = cookie.substring(0, idx).trim();
        final value = cookie.substring(idx + 1).trim();

        await _cookieManager.setCookie(
          WebViewCookie(
            name: name,
            value: value,
            domain: 'e-university.tu-sofia.bg',
            path: '/',
          ),
        );
      }

      await _controller.loadRequest(
        Uri.parse('https://e-university.tu-sofia.bg/ETUS/studenti/index.php'),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        title: const Text('ТУ — Вход'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Презареди',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}