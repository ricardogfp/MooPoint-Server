import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';

class CoveragePoint {
  final double lat;
  final double lon;
  final int timestamp;
  final int? rssi;
  final String? nodeId;

  CoveragePoint({
    required this.lat,
    required this.lon,
    required this.timestamp,
    this.rssi,
    this.nodeId,
  });

  factory CoveragePoint.fromJson(Map<String, dynamic> json) {
    return CoveragePoint(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] as int,
      rssi: json['rssi'] != null ? (json['rssi'] as num).toInt() : null,
      nodeId: json['nodeId'] as String?,
    );
  }

  LatLng get latLng => LatLng(lat, lon);

  // Weight and color based on RSSI
  // RSSI: -90 (excellent) to -120 (poor)
  // Weight: 0.3 (good) to 1.0 (poor)
  double get weight {
    if (rssi == null) return 0.5;
    final r = rssi!;
    if (r >= -90) return 0.3; // Excellent - low weight for green
    if (r >= -100) return 0.5; // Good
    if (r >= -105) return 0.7; // Fair
    if (r >= -110) return 0.85; // Poor
    return 1.0; // Very poor - high weight for red
  }
}

class CoverageSummary {
  final int totalPoints;
  final int pointsWithRssi;
  final double? avgRssi;
  final int goodSignal;
  final int mediumSignal;
  final int poorSignal;

  CoverageSummary({
    required this.totalPoints,
    required this.pointsWithRssi,
    this.avgRssi,
    required this.goodSignal,
    required this.mediumSignal,
    required this.poorSignal,
  });

  factory CoverageSummary.fromJson(Map<String, dynamic> json) {
    return CoverageSummary(
      totalPoints: json['totalPoints'] as int,
      pointsWithRssi: json['pointsWithRssi'] as int,
      avgRssi:
          json['avgRssi'] != null ? (json['avgRssi'] as num).toDouble() : null,
      goodSignal: json['goodSignal'] as int,
      mediumSignal: json['mediumSignal'] as int,
      poorSignal: json['poorSignal'] as int,
    );
  }
}

class CoverageData {
  final String nodeId;
  final String timeRange;
  final List<CoveragePoint> points;
  final CoverageSummary summary;

  CoverageData({
    required this.nodeId,
    required this.timeRange,
    required this.points,
    required this.summary,
  });

  factory CoverageData.fromJson(Map<String, dynamic> json) {
    return CoverageData(
      nodeId: json['nodeId'] as String? ?? '',
      timeRange: json['timeRange'] as String? ?? '',
      points: (json['points'] as List)
          .map((p) => CoveragePoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      summary:
          CoverageSummary.fromJson(json['summary'] as Map<String, dynamic>),
    );
  }

  /// Convert to WeightedLatLng for flutter_map_heatmap
  List<WeightedLatLng> toWeightedLatLng() {
    return points.map((p) => WeightedLatLng(p.latLng, p.weight)).toList();
  }
}
