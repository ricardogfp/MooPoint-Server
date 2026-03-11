class NodeHistoryPoint {
  final DateTime time;
  final double lat;
  final double lon;
  final double? voltage;
  final int? battery;

  NodeHistoryPoint({
    required this.time,
    required this.lat,
    required this.lon,
    this.voltage,
    this.battery,
  });

  factory NodeHistoryPoint.fromJson(Map<String, dynamic> json) {
    return NodeHistoryPoint(
      time: DateTime.parse(
          (json['time'] ?? DateTime.now().toIso8601String()).toString()),
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      voltage: (json['voltage'] as num?)?.toDouble(),
      battery: (json['battery'] as num?)?.toInt(),
    );
  }
}
