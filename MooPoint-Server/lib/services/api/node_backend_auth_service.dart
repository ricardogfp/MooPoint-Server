import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/api/node_backend_http_client.dart';

class NodeBackendAuthService {
  final http.Client _client;

  NodeBackendAuthService({http.Client? client})
      : _client = client ?? createNodeBackendHttpClient();

  String get _baseUrl => NodeBackendConfig.baseUrl.endsWith('/')
      ? NodeBackendConfig.baseUrl
          .substring(0, NodeBackendConfig.baseUrl.length - 1)
      : NodeBackendConfig.baseUrl;

  Future<String?> me() async {
    final url = Uri.parse('$_baseUrl/auth/me');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode == 200) {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final u = decoded['username'];
        return u?.toString();
      }
      return null;
    }
    if (resp.statusCode == 401) return null;
    throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
  }

  Future<void> login(
      {required String username, required String password}) async {
    final url = Uri.parse('$_baseUrl/auth/login');
    final resp = await _client
        .post(
          url,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({'username': username, 'password': password}),
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> logout() async {
    final url = Uri.parse('$_baseUrl/auth/logout');
    final resp = await _client.post(url, headers: const {
      'content-type': 'application/json'
    }).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  void dispose() {
    _client.close();
  }
}
