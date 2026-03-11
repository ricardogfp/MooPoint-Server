import 'package:moo_point/services/storage/app_config.dart';
import 'package:flutter/foundation.dart';

class NodeBackendConfig {
  static String get baseUrl {
    final configured = AppConfig.backendBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    if (kIsWeb) {
      return 'https://loracow.daeron16.com';
    }
    return 'https://loracow.daeron16.com';
  }

  static String wsUrl() {
    final base = baseUrl;
    final isAbsolute =
        base.startsWith('http://') || base.startsWith('https://');
    final origin = Uri.base;

    final resolved = isAbsolute ? Uri.parse(base) : origin.resolve(base);

    final wsScheme = resolved.scheme == 'https' ? 'wss' : 'ws';
    final pathBase = resolved.path.endsWith('/')
        ? resolved.path.substring(0, resolved.path.length - 1)
        : resolved.path;
    final wsPath = '$pathBase/ws';

    return resolved
        .replace(scheme: wsScheme, path: wsPath, queryParameters: null)
        .toString();
  }
}
