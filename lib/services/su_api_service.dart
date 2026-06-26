import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http/io_client.dart';

class SuApiService {
  static http.Client _createClient() {
    final ioClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(ioClient);
  }

  final http.Client client = _createClient();

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
    if (_cookies.isNotEmpty) 'Cookie':
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
      '<input[^>]*\\b(?:id|name)=["\']' +
          RegExp.escape(fieldId) +
          '["\'][^>]*>',
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

    // 1. GET login page
    var loginPageResponse = await client.get(
      Uri.parse(loginUrl),
      headers: _headersWithCookies,
    );
    if (loginPageResponse.statusCode != 200) {
      throw Exception('Failed to load login page: ${loginPageResponse.statusCode}');
    }
    _saveCookies(loginPageResponse);

    final vstate          = _extractHiddenField(loginPageResponse.body, '__VSTATE');
    final viewState       = _extractHiddenField(loginPageResponse.body, '__VIEWSTATE');
    final eventValidation = _extractHiddenField(loginPageResponse.body, '__EVENTVALIDATION');

    // 2. POST credentials
    var loginResponse = await client.post(
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
    var examsPageResponse = await client.get(
      Uri.parse(examsUrl),
      headers: _headersWithCookies,
    );
    if (examsPageResponse.statusCode != 200) {
      throw Exception('Failed to load exams page: ${examsPageResponse.statusCode}');
    }
    _saveCookies(examsPageResponse);

    final vstate2          = _extractHiddenField(examsPageResponse.body, '__VSTATE');
    final viewState2       = _extractHiddenField(examsPageResponse.body, '__VIEWSTATE');
    final eventValidation2 = _extractHiddenField(examsPageResponse.body, '__EVENTVALIDATION');

    // 4. POST grades postback
    var dataResponse = await client.post(
      Uri.parse(examsUrl),
      headers: _headersWithCookies,
      body: _encodeForm({
        'Report_Exams1:chkTaken':    'on',
        'Report_Exams1:chkNotTaken': 'on',
        '__EVENTTARGET':             r'Report_Exams1$btnReportExams',
        '__EVENTARGUMENT':           '',
        '__VSTATE':                  vstate2,
        '__VIEWSTATE':               viewState2,
        '__EVENTVALIDATION':         eventValidation2,
      }),
    );
    if (dataResponse.statusCode != 200) {
      throw Exception('Fetch grades failed with status: ${dataResponse.statusCode}');
    }
    _saveCookies(dataResponse);
    return dataResponse.body;
  }
}