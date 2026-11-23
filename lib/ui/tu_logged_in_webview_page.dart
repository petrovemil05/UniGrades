import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/tu_api_service.dart';
import '../services/url_launcher_factory/url_launcher_factory.dart';

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
    if (!kIsWeb) {
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
  }

  Future<void> _load() async {
    if (kIsWeb) return;

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
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Презареди',
              onPressed: _loading ? null : _load,
            ),
        ],
      ),
      body: kIsWeb
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.open_in_new,
                      size: 64,
                      color: Color(0xFF3498DB),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Портал Е-Студент (ТУ-София)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'За да отворите портала на ТУ-София в браузъра, натиснете бутона по-долу.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3498DB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () {
                        openExternalUrl(
                          'https://e-university.tu-sofia.bg/ETUS/studenti/index.php',
                        );
                      },
                      icon: const Icon(Icons.launch),
                      label: const Text('Отвори портала'),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
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
