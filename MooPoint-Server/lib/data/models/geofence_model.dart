import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class Geofence {
  final int id;
  final String name;
  final String description;
  final List<LatLng> points;
  final List<int> nodeIds;
  final String color;
  final String pastureType; // 'meadow', 'cropland', 'forest', 'water', 'other'
  final DateTime? lastModified;

  Geofence({
    required this.id,
    required this.name,
    this.description = '',
    required this.points,
    required this.nodeIds,
    this.color = '#3B82F6',
    this.pastureType = 'meadow',
    this.lastModified,
  });

  /// Approximate area in hectares using the Shoelace formula (assumes flat earth for small areas).
  double get areaHectares {
    if (points.length < 3) return 0;
    double area = 0;
    final n = points.length;
    for (int i = 0; i < n; i++) {
      final j = (i + 1) % n;
      // Convert to approximate meters using 1° lat ≈ 111,000 m
      final xi = points[i].longitude * 111320 * math.cos(points[i].latitude * math.pi / 180);
      final yi = points[i].latitude * 111000;
      final xj = points[j].longitude * 111320 * math.cos(points[j].latitude * math.pi / 180);
      final yj = points[j].latitude * 111000;
      area += xi * yj - xj * yi;
    }
    final areaM2 = (area / 2).abs();
    return areaM2 / 10000; // m² → ha
  }

  factory Geofence.fromJson(Map<String, dynamic> json) {
    final gj = json['geojson'];
    var coords = _extractPolygonCoords(gj);
    // Strip closing vertex (duplicate of first) since _save() always re-adds it
    if (coords.length > 1 &&
        coords.first[0] == coords.last[0] &&
        coords.first[1] == coords.last[1]) {
      coords = coords.sublist(0, coords.length - 1);
    }
    final pts = coords.map((c) => LatLng(c[1], c[0])).toList();

    final nodes = (json['nodeIds'] is List)
        ? (json['nodeIds'] as List)
            .whereType<num>()
            .map((n) => n.toInt())
            .toList()
        : <int>[];

    DateTime? lastMod;
    final lm = json['lastModified'] ?? json['updatedAt'] ?? json['createdAt'];
    if (lm != null) lastMod = DateTime.tryParse(lm.toString());

    return Geofence(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      points: pts,
      nodeIds: nodes,
      color: json['color'] ?? '#3B82F6',
      pastureType: json['pastureType'] ?? 'meadow',
      lastModified: lastMod,
    );
  }

  Map<String, dynamic> toGeoJson() {
    final ring = [
      ...points.map((p) => [p.longitude, p.latitude]),
      [points.first.longitude, points.first.latitude],
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

  Geofence copyWith({
    int? id,
    String? name,
    String? description,
    List<LatLng>? points,
    List<int>? nodeIds,
    String? color,
    String? pastureType,
    DateTime? lastModified,
  }) {
    return Geofence(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      points: points ?? this.points,
      nodeIds: nodeIds ?? this.nodeIds,
      color: color ?? this.color,
      pastureType: pastureType ?? this.pastureType,
      lastModified: lastModified ?? this.lastModified,
    );
  }

  static List<List<double>> _extractPolygonCoords(dynamic geojson) {
    if (geojson is Map<String, dynamic>) {
      if (geojson['type'] == 'Feature') {
        return _extractPolygonCoords(geojson['geometry']);
      }
      if (geojson['type'] == 'Polygon') {
        final rings = geojson['coordinates'];
        if (rings is List && rings.isNotEmpty && rings[0] is List) {
          return (rings[0] as List)
              .whereType<List>()
              .where((p) => p.length >= 2)
              .map((p) => [
                    (p[0] as num).toDouble(),
                    (p[1] as num).toDouble(),
                  ])
              .toList();
        }
      }
    }
    return <List<double>>[];
  }
}
