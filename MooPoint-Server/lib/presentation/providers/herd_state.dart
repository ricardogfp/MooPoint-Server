import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/coverage_model.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';
import 'package:moo_point/data/models/node_history_model.dart';
import 'package:moo_point/data/models/position_heatmap_model.dart';
import 'package:moo_point/data/models/alert_model.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/presentation/providers/settings_provider.dart';

class HerdState extends ChangeNotifier {
  final NodeBackendService _backend;
  final NodeBackendAdminService _admin;

  /// Public accessor for the backend service (used by detail panels).
  NodeBackendService get backend => _backend;

  HerdState({NodeBackendService? backend, NodeBackendAdminService? admin, SettingsProvider? settings, Duration? refreshInterval})
      : _backend = backend ?? NodeBackendService(settings: settings),
        _admin = admin ?? NodeBackendAdminService() {
    _startAutoRefresh(refreshInterval ?? const Duration(seconds: 30));
  }

  // --- Auto-refresh timer ---
  Timer? _refreshTimer;

  void _startAutoRefresh(Duration interval) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(interval, (_) {
      loadNodesAndGeofences();
    });
  }

  // --- Nodes ---
  List<NodeModel> _nodes = [];
  List<NodeModel> get nodes => _nodes;

  bool _nodesLoading = false;
  bool get nodesLoading => _nodesLoading;

  String? _nodesError;
  String? get nodesError => _nodesError;

  @Deprecated('Use loadNodesAndGeofences instead')
  Future<void> loadCowsAndGeofences() => loadNodesAndGeofences();

  // --- Geofences ---
  List<Geofence> _geofences = [];
  List<Geofence> get geofences => _geofences;

  // --- Geofence exit tracking (nodeId → set of geofenceIds that node has exited) ---
  final Map<int, Set<int>> _exitedGeofences = {};

  /// Returns true if any assigned node has exited this geofence.
  bool isGeofenceBreached(Geofence geofence) {
    for (final nodeId in geofence.nodeIds) {
      final exits = _exitedGeofences[nodeId];
      if (exits != null && exits.contains(geofence.id)) return true;
    }
    return false;
  }

  /// Called when a geofence_exit WS event arrives.
  void recordGeofenceExit(int nodeId, int geofenceId) {
    _exitedGeofences.putIfAbsent(nodeId, () => {}).add(geofenceId);
    notifyListeners();
  }

  // --- Discovery Notification ---
  List<NodeModel> get newNodesRequiringPlacement =>
      _nodes.where((n) => n.isNew).toList();

  // --- Geofence Events ---
  List<GeofenceEvent> _events = [];
  List<GeofenceEvent> get events => _events;

  bool _eventsLoading = false;
  bool get eventsLoading => _eventsLoading;

  String? _eventsError;
  String? get eventsError => _eventsError;

  int? _eventsNodeFilter;
  int? get eventsNodeFilter => _eventsNodeFilter;

  // --- Load nodes + geofences ---
  Future<void> loadNodesAndGeofences() async {
    _nodesLoading = true;
    _nodesError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _backend.getNodesData(),
        _backend.getGeofences(),
      ]);
      _nodes = results[0] as List<NodeModel>;
      _geofences = results[1] as List<Geofence>;
      _nodesError = null;
      // Reset exit tracking on full reload (server re-evaluates)
      _exitedGeofences.clear();
    } catch (e) {
      _nodesError = e.toString();
    } finally {
      _nodesLoading = false;
      notifyListeners();
    }
  }

  // --- WebSocket: apply a batch position update ---
  void applyPositionUpdate(List<Map<String, dynamic>> nodeMaps) {
    if (_nodes.isEmpty) return;
    final lookup = <int, NodeModel>{for (final n in _nodes) n.nodeId: n};
    bool changed = false;
    for (final m in nodeMaps) {
      final nodeId = (m['nodeId'] as num?)?.toInt();
      if (nodeId == null) continue;
      final existing = lookup[nodeId];
      if (existing == null) continue;

      final lat = (m['latitude'] as num?)?.toDouble() ?? existing.latitude;
      final lon = (m['longitude'] as num?)?.toDouble() ?? existing.longitude;
      final batt =
          (m['batteryLevel'] as num?)?.toInt() ?? existing.batteryLevel;
      final voltage = (m['voltage'] as num?)?.toInt() ?? existing.voltage;
      final nodeTypeStr = m['nodeType'] as String?;
      final nodeType =
          nodeTypeStr == 'fence' ? NodeType.fence : NodeType.cattle;
      final updated = m['lastUpdated'] != null
          ? DateTime.tryParse(m['lastUpdated'].toString()) ??
              existing.lastUpdated
          : existing.lastUpdated;
      final name = (m['name'] as String?) ?? existing.name;
      final isNew = (m['isNew'] as bool?) ?? existing.isNew;

      if (lat != existing.latitude ||
          lon != existing.longitude ||
          batt != existing.batteryLevel ||
          voltage != existing.voltage ||
          nodeType != existing.nodeType ||
          updated != existing.lastUpdated ||
          name != existing.name ||
          isNew != existing.isNew) {
        lookup[nodeId] = existing.copyWith(
          latitude: lat,
          longitude: lon,
          batteryLevel: batt,
          voltage: voltage,
          nodeType: nodeType,
          lastUpdated: updated,
          name: name,
          isNew: isNew,
        );
        changed = true;
      }
    }
    if (changed) {
      _nodes = lookup.values.toList();
      notifyListeners();
    }
  }

  /// Handles `telemetry_update` WebSocket events from fence nodes.
  /// Fence nodes have no GPS — only battery, voltage, and RSSI are updated.
  /// The node's position remains whatever was set during map placement.
  void applyTelemetryUpdate(Map<String, dynamic> m) {
    if (_nodes.isEmpty) return;
    final nodeId = (m['nodeId'] as num?)?.toInt();
    if (nodeId == null) return;
    final idx = _nodes.indexWhere((n) => n.nodeId == nodeId);
    if (idx == -1) return;

    final existing = _nodes[idx];
    final batt    = (m['batteryLevel'] as num?)?.toInt() ?? existing.batteryLevel;
    final voltage = (m['voltage']      as num?)?.toInt() ?? existing.voltage;
    final updated = m['lastUpdated'] != null
        ? DateTime.tryParse(m['lastUpdated'].toString()) ?? existing.lastUpdated
        : existing.lastUpdated;

    if (batt != existing.batteryLevel ||
        voltage != existing.voltage ||
        updated != existing.lastUpdated) {
      _nodes = List.of(_nodes);
      _nodes[idx] = existing.copyWith(
        batteryLevel: batt,
        voltage: voltage,
        lastUpdated: updated,
      );
      notifyListeners();
    }
  }

  // --- Load geofence events ---
  Future<void> loadEvents({int? nodeId}) async {
    _eventsNodeFilter = nodeId;
    _eventsLoading = true;
    _eventsError = null;
    notifyListeners();

    try {
      _events = await _backend.getGeofenceEvents(nodeId: nodeId);
      _eventsError = null;
    } catch (e) {
      _eventsError = e.toString();
    } finally {
      _eventsLoading = false;
      notifyListeners();
    }
  }

  // --- Coverage Data ---
  CoverageData? _coverageData;
  CoverageData? get coverageData => _coverageData;

  bool _coverageLoading = false;
  bool get coverageLoading => _coverageLoading;

  String? _coverageError;
  String? get coverageError => _coverageError;

  Future<void> loadCoverageData(
      {String? nodeId, String timeRange = '24h'}) async {
    _coverageLoading = true;
    _coverageError = null;
    notifyListeners();

    try {
      _coverageData =
          await _backend.getCoverageData(nodeId: nodeId, timeRange: timeRange);
      _coverageError = null;
    } catch (e) {
      _coverageError = e.toString();
      _coverageData = null;
    } finally {
      _coverageLoading = false;
      notifyListeners();
    }
  }

  void clearCoverageData() {
    _coverageData = null;
    notifyListeners();
  }

  // --- Position Heat Map Data ---
  PositionHeatmapData? _positionHeatmap;
  PositionHeatmapData? get positionHeatmap => _positionHeatmap;

  bool _positionHeatmapLoading = false;
  bool get positionHeatmapLoading => _positionHeatmapLoading;

  String? _positionHeatmapError;
  String? get positionHeatmapError => _positionHeatmapError;

  Future<void> loadPositionHeatmap({String? nodeId, int hours = 24}) async {
    _positionHeatmapLoading = true;
    _positionHeatmapError = null;
    notifyListeners();

    try {
      if (nodeId == null) {
        // Load all nodes' history and aggregate
        final allHistory = <NodeHistoryPoint>[];
        for (final node in _nodes) {
          try {
            final history = await _backend.getNodeHistory(
              node.nodeId,
              hours: hours,
              everyMinutes: 5, // Sample every 5 minutes
            );
            allHistory.addAll(history);
          } catch (e) {
            debugPrint('Error loading history for node ${node.nodeId}: $e');
          }
        }
        _positionHeatmap = PositionHeatmapData.fromHistory(allHistory);
      } else {
        // Load single node history
        final history = await _backend.getNodeHistory(
          int.parse(nodeId),
          hours: hours,
          everyMinutes: 5,
        );
        _positionHeatmap = PositionHeatmapData.fromHistory(history);
      }
      _positionHeatmapError = null;
    } catch (e) {
      _positionHeatmapError = e.toString();
      _positionHeatmap = null;
      debugPrint('Error loading position heatmap: $e');
    } finally {
      _positionHeatmapLoading = false;
      notifyListeners();
    }
  }

  void clearPositionHeatmap() {
    _positionHeatmap = null;
    notifyListeners();
  }

  Future<List<NodeHistoryPoint>> getNodeHistory(int nodeId,
      {int hours = 24, int everyMinutes = 5}) {
    return _backend.getNodeHistory(nodeId,
        hours: hours, everyMinutes: everyMinutes);
  }

  // --- Alerts ---
  List<AlertModel> _alerts = [];
  List<AlertModel> get alerts => _alerts;

  bool _alertsLoading = false;
  bool get alertsLoading => _alertsLoading;

  Future<void> loadAlerts() async {
    _alertsLoading = true;
    notifyListeners();

    try {
      final apiAlerts = await _backend.getAlerts(includeResolved: true);

      // Merge with in-session WebSocket alerts that don't yet have a server id,
      // keeping only those not already covered by the API response.
      final apiIds = apiAlerts.map((a) => a.id).toSet();
      final sessionAlerts = _alerts
          .where((a) => a.id.startsWith('node_') && !apiIds.contains(a.id))
          .toList();

      _alerts = [...apiAlerts, ...sessionAlerts]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } catch (e) {
      debugPrint('Error loading alerts: $e');
    } finally {
      _alertsLoading = false;
      notifyListeners();
    }
  }

  void addAlertFromNodeEvent(Map<String, dynamic> json) {
    final alert = AlertModel.fromNodeAlert(json);
    _alerts = [alert, ..._alerts];
    notifyListeners();
  }

  void addAlertFromGeofenceExit(GeofenceEvent event) {
    final alert = AlertModel.fromGeofenceEvent(event);
    // Avoid duplicating an alert that may already be loaded
    if (_alerts.any((a) => a.id == alert.id)) return;
    _alerts = [alert, ..._alerts];
    notifyListeners();
  }

  Future<void> resolveAlert(String alertId) async {
    // Persist to server (best-effort — update UI regardless)
    try {
      await _backend.resolveAlert(alertId);
    } catch (e) {
      debugPrint('Failed to persist alert resolution for $alertId: $e');
    }
    // Remove from local list so it disappears from the UI immediately
    _alerts = _alerts.where((a) => a.id != alertId).toList();
    notifyListeners();
  }

  void addAlertNote(String alertId, String note) {
    _alerts = _alerts
        .map((a) => a.id == alertId ? a.copyWith(notes: note) : a)
        .toList();
    notifyListeners();
  }

  // --- Behavior Summary Cache ---
  final Map<int, BehaviorSummary> _behaviorSummaryCache = {};

  Future<BehaviorSummary?> getBehaviorSummaryForNode(int nodeId) async {
    if (_behaviorSummaryCache.containsKey(nodeId)) {
      return _behaviorSummaryCache[nodeId];
    }
    try {
      final summary = await _backend.getBehaviorSummary(nodeId);
      if (summary != null) {
        _behaviorSummaryCache[nodeId] = summary;
      }
      return summary;
    } catch (e) {
      debugPrint('Error fetching behavior summary for node $nodeId: $e');
      return null;
    }
  }

  Future<bool> testConnection() => _backend.testConnection();

  // --- Geofence CRUD ---

  bool _geofenceSaving = false;
  bool get geofenceSaving => _geofenceSaving;

  String? _geofenceError;
  String? get geofenceError => _geofenceError;

  /// Create a new geofence and refresh the list. Returns the new id.
  Future<int?> createGeofence({
    required String name,
    required List<LatLng> points,
    String description = '',
    String color = '#3B82F6',
    String pastureType = 'meadow',
    List<int> nodeIds = const [],
  }) async {
    _geofenceSaving = true;
    _geofenceError = null;
    notifyListeners();
    try {
      final geojson = _pointsToGeoJson(points);
      final id = await _admin.createGeofence(name: name, geojson: geojson);
      if (nodeIds.isNotEmpty) {
        await _admin.setGeofenceNodes(id, nodeIds);
      }
      await loadNodesAndGeofences();
      return id;
    } catch (e) {
      _geofenceError = e.toString();
      notifyListeners();
      return null;
    } finally {
      _geofenceSaving = false;
      notifyListeners();
    }
  }

  /// Update an existing geofence and refresh the list.
  Future<bool> updateGeofence(
    int id, {
    required String name,
    required List<LatLng> points,
    String description = '',
    String color = '#3B82F6',
    String pastureType = 'meadow',
    List<int> nodeIds = const [],
  }) async {
    _geofenceSaving = true;
    _geofenceError = null;
    notifyListeners();
    try {
      final geojson = _pointsToGeoJson(points);
      await _admin.updateGeofence(id, name: name, geojson: geojson);
      await _admin.setGeofenceNodes(id, nodeIds);
      await loadNodesAndGeofences();
      return true;
    } catch (e) {
      _geofenceError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _geofenceSaving = false;
      notifyListeners();
    }
  }

  /// Delete a geofence and refresh the list.
  Future<bool> deleteGeofence(int id) async {
    _geofenceSaving = true;
    _geofenceError = null;
    notifyListeners();
    try {
      await _admin.deleteGeofence(id);
      _geofences = _geofences.where((g) => g.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _geofenceError = e.toString();
      notifyListeners();
      return false;
    } finally {
      _geofenceSaving = false;
      notifyListeners();
    }
  }

  static Map<String, dynamic> _pointsToGeoJson(List<LatLng> points) {
    final ring = [
      ...points.map((p) => [p.longitude, p.latitude]),
      if (points.isNotEmpty) [points.first.longitude, points.first.latitude],
    ];
    return {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [ring],
      },
      'properties': {},
    };
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _backend.dispose();
    _admin.dispose();
    super.dispose();
  }
}
