import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'http_client_factory/http_client_factory.dart';
import 'dart:convert';

class TuApiService {
  final http.Client client = createHttpClient();
  final List<String> _cookies = [];
  static const String webApiBaseUrl = 'http://localhost:3000';

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

  Future<http.Response> _postWebSafe(Uri uri,
      {Map<String, String>? headers, Map<String, String>? body}) async {
    final reqHeaders = _sanitizeHeaders(headers ?? {});
    try {
      final res = await client.post(uri, headers: reqHeaders, body: body);
      if (res.statusCode == 200) return res;
    } catch (_) {}


    // Direct fallback attempt
    return await client.post(uri, headers: reqHeaders, body: body);
  }

  Future<String> getHtmlAsync(String fnum,
      String egn, {
        String deistvie = '1',
      }) async {
    if (kIsWeb) {
      final response = await client.post(
        Uri.parse('$webApiBaseUrl/api/tu/grades'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fnum': fnum,
          'egn': egn,
          'deistvie': deistvie,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Could not load grades: ${response.statusCode}');
      }

      return response.body;
    }

    const url = "https://e-university.tu-sofia.bg/ETUS/studenti/index.php";

    _cookies.clear();

    try {
      final loginResponse = await _postWebSafe(
        Uri.parse(url),
        headers: _headers,
        body: {
          "fnum": fnum,
          "egn": egn,
        },
      );

      if (loginResponse.statusCode != 200) {
        throw Exception(
            "Login failed with status: ${loginResponse.statusCode}");
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

      final dataResponse = await _postWebSafe(
        Uri.parse(url),
        headers: dataHeaders,
        body: {
          "deistvie": deistvie,
        },
      );

      if (dataResponse.statusCode != 200) {
        throw Exception(
            "Fetch data failed with status: ${dataResponse.statusCode}");
      }

      return dataResponse.body;
    } catch (e) {
      if (kIsWeb) {
        throw Exception(
            "Грешка при връзката с ТУ-София: $e");
      }
      rethrow;
    }
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
