import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppConfig {
  static String _backendBaseUrl = '';

  static String get backendBaseUrl => _backendBaseUrl;

  static Future<void> load() async {
    // Set a sensible default for web or local development
    _backendBaseUrl = 'https://loracow.daeron16.com';

    try {
      final resolved = Uri.base.resolve('config.json');
      final uri = resolved.replace(queryParameters: {
        ...resolved.queryParameters,
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode != 200) return;

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) return;

      final raw = decoded['backendBaseUrl'];
      if (raw is String && raw.trim().isNotEmpty) {
        _backendBaseUrl = raw.trim();
      }
    } catch (e) {
      debugPrint('AppConfig load error: $e');
    }
  }
}
