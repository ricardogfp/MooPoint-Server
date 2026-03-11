import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/api/node_backend_http_client.dart';

class NodeBackendAdminService {
  final http.Client _client;

  NodeBackendAdminService({http.Client? client})
      : _client = client ?? createNodeBackendHttpClient();

  String get _baseUrl => NodeBackendConfig.baseUrl.endsWith('/')
      ? NodeBackendConfig.baseUrl
          .substring(0, NodeBackendConfig.baseUrl.length - 1)
      : NodeBackendConfig.baseUrl;

  Map<String, String> get _headers =>
      const {'content-type': 'application/json'};

  Future<List<Map<String, dynamic>>> listNodes() async {
    final url = Uri.parse('$_baseUrl/admin/nodes');
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setFriendlyName(int nodeId, String friendlyName) async {
    final url = Uri.parse('$_baseUrl/admin/nodes/$nodeId');
    final resp = await _client
        .put(url,
            headers: _headers, body: jsonEncode({'friendlyName': friendlyName}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> updateNodeInfo(
    int nodeId, {
    String? friendlyName,
    String? nodeType,
    double? staticLat,
    double? staticLon,
    String? breed,
    int? age,
    String? healthStatus,
    String? comments,
    String? photoUrl,
  }) async {
    final body = <String, dynamic>{};
    if (friendlyName != null) body['friendlyName'] = friendlyName;
    if (nodeType != null) body['nodeType'] = nodeType;
    if (staticLat != null) body['staticLat'] = staticLat;
    if (staticLon != null) body['staticLon'] = staticLon;
    if (breed != null) body['breed'] = breed;
    if (age != null) body['age'] = age;
    if (healthStatus != null) body['healthStatus'] = healthStatus;
    if (comments != null) body['comments'] = comments;
    if (photoUrl != null) body['photoUrl'] = photoUrl;

    if (body.isEmpty) {
      throw Exception('At least one field must be provided');
    }

    final url = Uri.parse('$_baseUrl/admin/nodes/$nodeId');
    final resp = await _client
        .put(url, headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<List<Map<String, dynamic>>> listGeofences() async {
    final url = Uri.parse('$_baseUrl/admin/geofences');
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<int> createGeofence(
      {required String name, required Map<String, dynamic> geojson}) async {
    final url = Uri.parse('$_baseUrl/admin/geofences');
    final resp = await _client
        .post(url,
            headers: _headers,
            body: jsonEncode({'name': name, 'geojson': geojson}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) throw Exception('Unexpected response format');
    return (decoded['id'] as num).toInt();
  }

  Future<void> updateGeofence(int geofenceId,
      {required String name, required Map<String, dynamic> geojson}) async {
    final url = Uri.parse('$_baseUrl/admin/geofences/$geofenceId');
    final resp = await _client
        .put(url,
            headers: _headers,
            body: jsonEncode({'name': name, 'geojson': geojson}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> deleteGeofence(int geofenceId) async {
    final url = Uri.parse('$_baseUrl/admin/geofences/$geofenceId');
    final resp = await _client
        .delete(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> setGeofenceNodes(int geofenceId, List<int> nodeIds) async {
    final url = Uri.parse('$_baseUrl/admin/geofences/$geofenceId/nodes');
    final resp = await _client
        .put(url, headers: _headers, body: jsonEncode({'nodeIds': nodeIds}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<void> setNodeDeviceCredentials(int nodeId,
      {required int deviceId, required String deviceKey}) async {
    final url = Uri.parse('$_baseUrl/admin/nodes/$nodeId/device-credentials');
    final resp = await _client
        .put(url,
            headers: _headers,
            body: jsonEncode({'deviceId': deviceId, 'deviceKey': deviceKey}))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<List<Map<String, dynamic>>> listDeviceCredentials() async {
    final url = Uri.parse('$_baseUrl/admin/device-credentials');
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> publishDeviceMap({int gatewayId = 1}) async {
    final url =
        Uri.parse('$_baseUrl/admin/gateways/$gatewayId/device-map/publish');
    final resp = await _client
        .post(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  /// Upload a node photo (from bytes) and return the absolute URL.
  Future<String> uploadNodePhoto(
      int nodeId, List<int> bytes, String filename) async {
    final url = Uri.parse('$_baseUrl/admin/nodes/$nodeId/photo');

    // Determine MIME type from extension — multer rejects non-image types
    final ext = filename.split('.').last.toLowerCase();
    const mimeMap = {
      'jpg': 'jpeg',
      'jpeg': 'jpeg',
      'png': 'png',
      'webp': 'webp',
      'gif': 'gif',
    };
    final subtype = mimeMap[ext] ?? 'jpeg';

    final request = http.MultipartRequest('POST', url)
      ..files.add(http.MultipartFile.fromBytes(
        'photo',
        bytes,
        filename: filename,
        contentType: MediaType('image', subtype),
      ));
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 30));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception('Photo upload failed (${resp.statusCode}): ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    return decoded['photoUrl'] as String;
  }

  // Alias for backward compatibility
  @Deprecated('Use uploadNodePhoto instead')
  Future<String> uploadCowPhoto(int nodeId, List<int> bytes, String filename) =>
      uploadNodePhoto(nodeId, bytes, filename);

  /// List all firmware versions
  Future<List<Map<String, dynamic>>> listFirmware() async {
    final url = Uri.parse('$_baseUrl/admin/firmware/list');
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  /// Upload firmware .hex file
  Future<Map<String, dynamic>> uploadFirmware(
      List<int> bytes, String filename, String version,
      {String? notes}) async {
    final url = Uri.parse('$_baseUrl/admin/firmware/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['version'] = version
      ..fields['notes'] = notes ?? ''
      ..files.add(http.MultipartFile.fromBytes(
        'firmware',
        bytes,
        filename: filename,
        contentType: MediaType('application', 'octet-stream'),
      ));
    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode != 200) {
      throw Exception(
          'Firmware upload failed (${resp.statusCode}): ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Set active firmware version
  Future<void> setActiveFirmware(int firmwareId) async {
    final url = Uri.parse('$_baseUrl/admin/firmware/set_active/$firmwareId');
    final resp = await _client
        .post(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  /// Delete firmware version
  Future<void> deleteFirmware(int firmwareId) async {
    final url = Uri.parse('$_baseUrl/admin/firmware/$firmwareId');
    final resp = await _client
        .delete(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  /// Push configuration to trackers via gateways
  Future<Map<String, dynamic>> pushConfig(
    List<int> nodeIds,
    List<int> gatewayIds,
    Map<String, dynamic> config,
  ) async {
    final url = Uri.parse('$_baseUrl/admin/config/push');
    final resp = await _client
        .post(
          url,
          headers: _headers,
          body: jsonEncode({
            'nodeIds': nodeIds,
            'gatewayIds': gatewayIds,
            'config': config,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  /// Get config push status
  Future<List<Map<String, dynamic>>> getConfigPushStatus(
      String requestId) async {
    final url = Uri.parse('$_baseUrl/admin/config/push/$requestId/status');
    final resp = await _client
        .get(url, headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  void dispose() {
    _client.close();
  }
}
