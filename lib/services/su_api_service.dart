import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'http_client_factory/http_client_factory.dart';

class SuApiService {
  final http.Client client = createHttpClient();

  final Map<String, String> _cookies = {};

  final Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Upgrade-Insecure-Requests': '1',
    'Connection': 'keep-alive',
    'Sec-Fetch-Site': 'same-origin',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-User': '?1',
    'Sec-Fetch-Dest': 'document',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    if (!kIsWeb) return headers;
    final clean = Map<String, String>.from(headers);
    clean.removeWhere((key, value) {
      final k = key.toLowerCase();
      return k == 'user-agent' ||
          k == 'cookie' ||
          k.startsWith('sec-fetch-') ||
          k == 'connection' ||
          k == 'upgrade-insecure-requests' ||
          k == 'host';
    });
    return clean;
  }

  Future<http.Response> _getWebSafe(Uri uri, {Map<String, String>? headers}) async {
    final reqHeaders = _sanitizeHeaders(headers ?? {});
    try {
      final res = await client.get(uri, headers: reqHeaders);
      if (res.statusCode == 200) return res;
    } catch (_) {}

    if (kIsWeb) {
      try {
        final proxyUrl =
            'https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}';
        final proxyRes = await client.get(Uri.parse(proxyUrl), headers: reqHeaders);
        if (proxyRes.statusCode == 200) return proxyRes;
      } catch (_) {}

      try {
        final aoUrl =
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(uri.toString())}';
        final aoRes = await client.get(Uri.parse(aoUrl), headers: reqHeaders);
        if (aoRes.statusCode == 200) return aoRes;
      } catch (_) {}
    }

    return await client.get(uri, headers: reqHeaders);
  }

  Future<http.Response> _postWebSafe(Uri uri,
      {Map<String, String>? headers, Object? body}) async {
    final reqHeaders = _sanitizeHeaders(headers ?? {});
    try {
      final res = await client.post(uri, headers: reqHeaders, body: body);
      if (res.statusCode == 200 || res.statusCode == 302) return res;
    } catch (_) {}

    if (kIsWeb) {
      try {
        final proxyUrl =
            'https://corsproxy.io/?${Uri.encodeComponent(uri.toString())}';
        final proxyRes = await client.post(
          Uri.parse(proxyUrl),
          headers: reqHeaders,
          body: body,
        );
        if (proxyRes.statusCode == 200 || proxyRes.statusCode == 302) {
          return proxyRes;
        }
      } catch (_) {}

      try {
        final aoUrl =
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(uri.toString())}';
        final aoRes = await client.post(
          Uri.parse(aoUrl),
          headers: reqHeaders,
          body: body,
        );
        if (aoRes.statusCode == 200 || aoRes.statusCode == 302) {
          return aoRes;
        }
      } catch (_) {}
    }

    return await client.post(uri, headers: reqHeaders, body: body);
  }

  void _saveCookies(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    for (final part in setCookie.split(RegExp(r',(?=[^ ])'))) {
      final segment = part.split(';').first.trim();
      final eq = segment.indexOf('=');
      if (eq > 0) {
        _cookies[segment.substring(0, eq).trim()] =
            segment.substring(eq + 1).trim();
      }
    }
  }

  Map<String, String> get _headersWithCookies => {
        ..._headers,
        if (_cookies.isNotEmpty)
          'Cookie':
              _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

  String _encodeForm(Map<String, String> fields) => fields.entries
      .map((e) =>
          '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
      .join('&');

  String _htmlDecode(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");

  String _extractHiddenField(String html, String fieldId) {
    final tagRe = RegExp(
      '<input[^>]*\\b(?:id|name)=["\']${RegExp.escape(fieldId)}["\'][^>]*>',
      caseSensitive: false,
    );
    final tagMatch = tagRe.firstMatch(html);
    if (tagMatch == null) return '';
    final valueRe = RegExp('value=["\']([^"\']*)["\']', caseSensitive: false);
    final valueMatch = valueRe.firstMatch(tagMatch.group(0)!);
    return valueMatch != null ? _htmlDecode(valueMatch.group(1)!) : '';
  }

  bool _looksLikeLoginFailure(String html) =>
      html.contains('txtUserName') && html.contains('txtPassword');

  Future<String> getHtmlAsync(String username, String password) async {
    const loginUrl = 'https://susi.uni-sofia.bg/ISSU/forms/Login.aspx';
    const examsUrl =
        'https://susi.uni-sofia.bg/ISSU/forms/students/ReportExams.aspx';

    try {
      // 1. GET login page
      var loginPageResponse = await _getWebSafe(
        Uri.parse(loginUrl),
        headers: _headersWithCookies,
      );
      if (loginPageResponse.statusCode != 200) {
        throw Exception(
            'Failed to load login page: ${loginPageResponse.statusCode}');
      }
      _saveCookies(loginPageResponse);

      final vstate =
          _extractHiddenField(loginPageResponse.body, '__VSTATE');
      final viewState =
          _extractHiddenField(loginPageResponse.body, '__VIEWSTATE');
      final eventValidation =
          _extractHiddenField(loginPageResponse.body, '__EVENTVALIDATION');

      // 2. POST credentials
      var loginResponse = await _postWebSafe(
        Uri.parse(loginUrl),
        headers: _headersWithCookies,
        body: _encodeForm({
          'txtUserName': username,
          'txtPassword': password,
          '__VSTATE': vstate,
          '__VIEWSTATE': viewState,
          '__EVENTVALIDATION': eventValidation,
          'btnSubmit': 'Влез',
        }),
      );
      if (loginResponse.statusCode != 200 && loginResponse.statusCode != 302) {
        throw Exception('Login failed with status: ${loginResponse.statusCode}');
      }
      _saveCookies(loginResponse);
      if (_looksLikeLoginFailure(loginResponse.body)) {
        throw Exception('Login failed – check username and password.');
      }

      // 3. GET exams page
      var examsPageResponse = await _getWebSafe(
        Uri.parse(examsUrl),
        headers: _headersWithCookies,
      );
      if (examsPageResponse.statusCode != 200) {
        throw Exception(
            'Failed to load exams page: ${examsPageResponse.statusCode}');
      }
      _saveCookies(examsPageResponse);

      final vstate2 =
          _extractHiddenField(examsPageResponse.body, '__VSTATE');
      final viewState2 =
          _extractHiddenField(examsPageResponse.body, '__VIEWSTATE');
      final eventValidation2 =
          _extractHiddenField(examsPageResponse.body, '__EVENTVALIDATION');

      // 4. POST grades postback
      var dataResponse = await _postWebSafe(
        Uri.parse(examsUrl),
        headers: _headersWithCookies,
        body: _encodeForm({
          'Report_Exams1:chkTaken': 'on',
          'Report_Exams1:chkNotTaken': 'on',
          '__EVENTTARGET': r'Report_Exams1$btnReportExams',
          '__EVENTARGUMENT': '',
          '__VSTATE': vstate2,
          '__VIEWSTATE': viewState2,
          '__EVENTVALIDATION': eventValidation2,
        }),
      );
      if (dataResponse.statusCode != 200) {
        throw Exception(
            'Fetch grades failed with status: ${dataResponse.statusCode}');
      }
      _saveCookies(dataResponse);
      return dataResponse.body;
    } catch (e) {
      if (kIsWeb) {
        throw Exception(
            'Грешка при връзката със СУСИ: $e');
      }
      rethrow;
    }
  }
}
