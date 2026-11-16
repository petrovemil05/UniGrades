import 'package:http/http.dart' as http;

class TuApiService {
  final http.Client client = http.Client();
  final List<String> _cookies = [];

  List<String> get cookies => List.unmodifiable(_cookies);

  final Map<String, String> _headers = {
    "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/147.0.0.0 Safari/537.36 OPR/131.0.0.0",
    "Accept":
    "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Upgrade-Insecure-Requests": "1",
    "Connection": "keep-alive",
    "Sec-Fetch-Site": "same-origin",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-User": "?1",
    "Sec-Fetch-Dest": "document",
  };

  Future<String> getHtmlAsync(
      String fnum,
      String egn, {
        String deistvie = '1',
      }) async {
    const url = "https://e-university.tu-sofia.bg/ETUS/studenti/index.php";

    _cookies.clear();

    final loginResponse = await client.post(
      Uri.parse(url),
      headers: _headers,
      body: {
        "fnum": fnum,
        "egn": egn,
      },
    );

    if (loginResponse.statusCode != 200) {
      throw Exception("Login failed with status: ${loginResponse.statusCode}");
    }

    final rawSetCookie = loginResponse.headers['set-cookie'];
    if (rawSetCookie != null && rawSetCookie.isNotEmpty) {
      for (final cookie in _extractCookiePairs(rawSetCookie)) {
        if (!_cookies.contains(cookie)) {
          _cookies.add(cookie);
        }
      }
    }

    final Map<String, String> dataHeaders = Map.from(_headers);
    if (_cookies.isNotEmpty) {
      dataHeaders['Cookie'] = _cookies.join('; ');
    }

    final dataResponse = await client.post(
      Uri.parse(url),
      headers: dataHeaders,
      body: {
        "deistvie": deistvie,
      },
    );

    if (dataResponse.statusCode != 200) {
      throw Exception("Fetch data failed with status: ${dataResponse.statusCode}");
    }

    return dataResponse.body;
  }

  List<String> _extractCookiePairs(String header) {
    final result = <String>[];
    final parts = <String>[];
    final buffer = StringBuffer();
    var inExpires = false;

    for (var i = 0; i < header.length; i++) {
      final char = header[i];

      if (!inExpires &&
          i + 8 <= header.length &&
          header.substring(i, i + 8).toLowerCase() == 'expires=') {
        inExpires = true;
      }

      if (char == ',') {
        if (inExpires) {
          buffer.write(char);
        } else {
          parts.add(buffer.toString().trim());
          buffer.clear();
        }
        continue;
      }

      if (inExpires && char == ';') {
        inExpires = false;
      }

      buffer.write(char);
    }

    final last = buffer.toString().trim();
    if (last.isNotEmpty) {
      parts.add(last);
    }

    for (final part in parts) {
      final firstSegment = part.split(';').first.trim();
      final idx = firstSegment.indexOf('=');
      if (idx > 0) {
        final name = firstSegment.substring(0, idx).trim();
        final value = firstSegment.substring(idx + 1).trim();
        if (name.isNotEmpty && value.isNotEmpty) {
          result.add('$name=$value');
        }
      }
    }

    return result;
  }
}