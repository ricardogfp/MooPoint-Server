import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:moo_point/data/models/node_history_model.dart';
import 'dart:math' as math;

class PositionHeatPoint {
  final LatLng latLng;
  final double weight;

  PositionHeatPoint({required this.latLng, required this.weight});
}

class PositionHeatmapData {
  final List<PositionHeatPoint> points;
  final int totalPoints;

  PositionHeatmapData({required this.points, required this.totalPoints});

  /// Aggregate position history into heat map points
  /// Groups positions into 30m x 30m grid cells
  factory PositionHeatmapData.fromHistory(List<NodeHistoryPoint> history) {
    if (history.isEmpty) {
      return PositionHeatmapData(points: [], totalPoints: 0);
    }

    // Grid cell size in degrees (approximately 30m at equator)
    // 1 degree latitude ≈ 111km, so 30m ≈ 0.00027 degrees
    const double cellSize = 0.00027;

    // Group positions into grid cells
    final Map<String, List<NodeHistoryPoint>> grid = {};

    for (final point in history) {
      // Calculate grid cell coordinates
      final cellLat = (point.lat / cellSize).floor();
      final cellLon = (point.lon / cellSize).floor();
      final cellKey = '$cellLat,$cellLon';

      grid.putIfAbsent(cellKey, () => []).add(point);
    }

    // Convert grid cells to heat points with weights
    final List<PositionHeatPoint> heatPoints = [];

    for (final entry in grid.entries) {
      final cellPoints = entry.value;

      // Calculate center of all points in this cell
      final avgLat = cellPoints.map((p) => p.lat).reduce((a, b) => a + b) /
          cellPoints.length;
      final avgLon = cellPoints.map((p) => p.lon).reduce((a, b) => a + b) /
          cellPoints.length;

      // Weight is the number of position reports in this cell
      final weight = cellPoints.length.toDouble();

      heatPoints.add(PositionHeatPoint(
        latLng: LatLng(avgLat, avgLon),
        weight: weight,
      ));
    }

    // Normalize weights to 0.0-1.0 range
    if (heatPoints.isNotEmpty) {
      final maxWeight = heatPoints.map((p) => p.weight).reduce(math.max);
      if (maxWeight > 0) {
        for (int i = 0; i < heatPoints.length; i++) {
          heatPoints[i] = PositionHeatPoint(
            latLng: heatPoints[i].latLng,
            weight: heatPoints[i].weight / maxWeight,
          );
        }
      }
    }

    return PositionHeatmapData(
      points: heatPoints,
      totalPoints: history.length,
    );
  }

  /// Convert to WeightedLatLng for flutter_map_heatmap
  List<WeightedLatLng> toWeightedLatLng() {
    return points.map((p) => WeightedLatLng(p.latLng, p.weight)).toList();
  }
}
