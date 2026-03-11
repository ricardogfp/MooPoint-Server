import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:moo_point/data/models/alert_model.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/data/models/coverage_model.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/api/node_backend_http_client.dart';
import 'package:moo_point/data/models/node_history_model.dart';

class NodeBackendService {
  final http.Client _client;

  NodeBackendService({http.Client? client})
      : _client = client ?? createNodeBackendHttpClient();

  String get _baseUrl => NodeBackendConfig.baseUrl.endsWith('/')
      ? NodeBackendConfig.baseUrl
          .substring(0, NodeBackendConfig.baseUrl.length - 1)
      : NodeBackendConfig.baseUrl;

  Future<bool> testConnection() async {
    try {
      final url = Uri.parse('$_baseUrl/health/influx');
      final resp = await _client.get(url).timeout(const Duration(seconds: 10));
      return resp.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> requestBleLocate(
    int nodeId, {
    int minutes = 5,
  }) async {
    final url = Uri.parse('$_baseUrl/api/ble_locate');
    final body = jsonEncode({
      'node_id': nodeId,
      'minutes': minutes,
    });

    final resp = await _client
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200 && resp.statusCode != 202) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<List<NodeModel>> getNodesData() async {
    final url = Uri.parse('$_baseUrl/api/nodes');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map((m) => NodeModel.fromJson(m))
        .toList();
  }

  // Alias for backward compatibility
  Future<List<NodeModel>> getCowsData() => getNodesData();

  Future<NodeModel?> getNodeById(int nodeId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/nodes/$nodeId');
      final resp = await _client.get(url).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) return null;
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected response format');
      }

      return NodeModel.fromJson(decoded);
    } on SocketException catch (e) {
      debugPrint('getNodeById network error: $e');
      return null;
    } on HttpException catch (e) {
      debugPrint('getNodeById HTTP error: $e');
      return null;
    } on TimeoutException catch (e) {
      debugPrint('getNodeById timeout: $e');
      return null;
    } catch (e) {
      debugPrint('getNodeById unexpected error: $e');
      rethrow;
    }
  }

  // Alias for backward compatibility
  Future<NodeModel?> getCowById(int nodeId) => getNodeById(nodeId);

  Future<List<Geofence>> getGeofences() async {
    final url = Uri.parse('$_baseUrl/api/geofences');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Geofence.fromJson)
        .toList();
  }

  Future<List<GeofenceEvent>> getGeofenceEvents(
      {int? nodeId, int limit = 100}) async {
    final params = <String>['limit=$limit'];
    if (nodeId != null) params.add('node_id=$nodeId');
    final url = Uri.parse('$_baseUrl/api/geofence-events?${params.join('&')}');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(GeofenceEvent.fromJson)
        .toList();
  }

  Future<List<NodeHistoryPoint>> getNodeHistory(
    int nodeId, {
    int hours = 24,
    int everyMinutes = 1,
  }) async {
    final url = Uri.parse(
        '$_baseUrl/api/nodes/$nodeId/history?hours=$hours&everyMinutes=$everyMinutes');
    final resp = await _client.get(url).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(NodeHistoryPoint.fromJson)
        .toList();
  }

  // Alias for backward compatibility
  Future<List<NodeHistoryPoint>> getCowHistory(int nodeId,
          {int hours = 24, int everyMinutes = 1}) =>
      getNodeHistory(nodeId, hours: hours, everyMinutes: everyMinutes);

  Future<CoverageData> getCoverageData(
      {String? nodeId, String timeRange = '24h'}) async {
    final path = nodeId != null ? '/api/coverage/$nodeId' : '/api/coverage';
    final url = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: {'timeRange': timeRange});
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    return CoverageData.fromJson(decoded);
  }

  Future<List<BehaviorData>> getBehaviorData(int nodeId,
      {int hours = 24}) async {
    final url = Uri.parse('$_baseUrl/api/behavior/$nodeId?hours=$hours');
    final resp = await _client.get(url).timeout(const Duration(seconds: 30));

    if (resp.statusCode == 404) return <BehaviorData>[];

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    final data = decoded['data'];
    if (data is! List) return <BehaviorData>[];

    return data
        .whereType<Map<String, dynamic>>()
        .map(BehaviorData.fromJson)
        .toList();
  }

  Future<BehaviorSummary?> getBehaviorSummary(int nodeId,
      {String? date}) async {
    final params = date != null ? '?date=$date' : '';
    final url = Uri.parse('$_baseUrl/api/behavior/$nodeId/summary$params');
    final resp = await _client.get(url).timeout(const Duration(seconds: 30));

    if (resp.statusCode == 404) return null;

    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected response format');
    }

    final summary = decoded['summary'];
    if (summary is! Map<String, dynamic>) return null;

    return BehaviorSummary.fromJson(summary);
  }

  Future<List<AlertModel>> getAlerts({int limit = 100, bool includeResolved = false, String? severity}) async {
    final severityParam = severity != null ? '&severity=$severity' : '';
    final url = Uri.parse('$_baseUrl/nodejs/api/alerts?limit=$limit${includeResolved ? '&includeResolved=true' : ''}$severityParam');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) throw Exception('Unexpected response format');
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AlertModel.fromApiAlert)
        .toList();
  }

  Future<void> resolveAlert(String alertKey, {String? notes}) async {
    final url = Uri.parse('$_baseUrl/nodejs/api/alerts/resolve');
    final body = jsonEncode({'alertKey': alertKey, if (notes != null) 'notes': notes});
    final resp = await _client
        .post(url, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<List<NodeHistoryPoint>> getFenceHistory(
    int nodeId, {
    int hours = 24,
    int everyMinutes = 5,
  }) async {
    final url = Uri.parse(
        '$_baseUrl/api/nodes/$nodeId/fence-history?hours=$hours&everyMinutes=$everyMinutes');
    final resp = await _client.get(url).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) {
      throw Exception('Unexpected response format');
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map((json) => NodeHistoryPoint(
              time: DateTime.parse(json['time']),
              lat: 0.0,
              lon: 0.0,
              voltage: (json['voltage'] as num?)?.toDouble(),
              battery: (json['batt_percent'] as num?)?.toInt(),
            ))
        .toList();
  }

  Future<List<AlertModel>> getNodeAlerts(int nodeId, {int limit = 20}) async {
    final url = Uri.parse('$_baseUrl/nodejs/api/alerts?limit=$limit&includeResolved=true');
    final resp = await _client.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .where((json) => json['nodeId'] == nodeId)
        .map(AlertModel.fromApiAlert)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
