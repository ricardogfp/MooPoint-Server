import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/data/models/node_history_model.dart';

class NodeHistoryPage extends StatefulWidget {
  final NodeModel node;

  const NodeHistoryPage({super.key, required this.node});

  @override
  State<NodeHistoryPage> createState() => _NodeHistoryPageState();
}

class _NodeHistoryPageState extends State<NodeHistoryPage> {
  final _backend = NodeBackendService();
  Future<List<NodeHistoryPoint>>? _future;
  Future<List<Geofence>>? _geofencesFuture;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _geofencesFuture = _loadGeofences();
  }

  Future<List<NodeHistoryPoint>> _load() async {
    return _backend.getNodeHistory(widget.node.nodeId,
        hours: 24, everyMinutes: 1);
  }

  Future<List<Geofence>> _loadGeofences() async {
    try {
      final all = await _backend.getGeofences();
      // Filter to geofences that include this node
      return all.where((g) => g.nodeIds.contains(widget.node.nodeId)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _future = _load();
      _geofencesFuture = _loadGeofences();
      _index = 0; // Reset to first point when refreshing
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History: ${widget.node.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh History',
          ),
        ],
      ),
      body: FutureBuilder<List<NodeHistoryPoint>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load history: ${snap.error}'));
          }
          final points = snap.data ?? const <NodeHistoryPoint>[];
          if (points.isEmpty) {
            return const Center(
                child: Text('No history points in the last 24 hours.'));
          }

          if (_index >= points.length) _index = points.length - 1;
          if (_index < 0) _index = 0;

          final selected = points[_index];
          final selectedLatLng = LatLng(selected.lat, selected.lon);

          final polyPoints = points
              .take(_index + 1)
              .map((p) => LatLng(p.lat, p.lon))
              .toList(growable: false);

          return FutureBuilder<List<Geofence>>(
            future: _geofencesFuture,
            builder: (context, geofenceSnap) {
              final geofences = geofenceSnap.data ?? const <Geofence>[];

              return Column(
                children: [
                  Expanded(
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: selectedLatLng,
                        initialZoom: 14,
                        minZoom: 4,
                        maxZoom: 18,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.moopoint.tracker',
                        ),
                        // Geofence polygon overlays for this node
                        if (geofences.isNotEmpty)
                          PolygonLayer(
                            polygons: geofences
                                .map((gf) => Polygon(
                                      points: gf.points,
                                      color: Colors.orange.withValues(alpha: 0.2),
                                      borderColor: Colors.deepOrange,
                                      borderStrokeWidth: 2,
                                      label: gf.name,
                                    ))
                                .toList(),
                          ),
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: polyPoints,
                              color: Colors.blue,
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: selectedLatLng,
                              width: 44,
                              height: 44,
                              child: const Icon(Icons.location_on,
                                  color: Colors.red, size: 44),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Time: ${selected.time.toLocal()}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        Slider(
                          value: _index.toDouble(),
                          min: 0,
                          max: (points.length - 1).toDouble(),
                          divisions:
                              points.length > 1 ? points.length - 1 : null,
                          label: '${_index + 1}/${points.length}',
                          onChanged: (v) {
                            setState(() {
                              _index = v.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
