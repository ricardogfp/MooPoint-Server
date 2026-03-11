import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

final HttpClient _ioHttpClient = HttpClient();

class _CookieJarClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _cookies = <String, String>{};

  _CookieJarClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_cookies.isNotEmpty) {
      request.headers['cookie'] =
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }

    final resp = await _inner.send(request);

    final setCookie = resp.headers['set-cookie'];
    if (setCookie != null && setCookie.isNotEmpty) {
      // Multiple cookies may be present; splitting on comma is not fully RFC-compliant
      // but works for typical simple session cookies.
      for (final part in setCookie.split(',')) {
        final first = part.split(';').first.trim();
        final idx = first.indexOf('=');
        if (idx <= 0) continue;
        final name = first.substring(0, idx).trim();
        final value = first.substring(idx + 1).trim();
        if (name.isNotEmpty) {
          _cookies[name] = value;
        }
      }
    }

    return resp;
  }
}

http.Client createClientImpl() => _CookieJarClient(IOClient(_ioHttpClient));
