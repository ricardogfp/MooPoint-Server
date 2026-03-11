class GeofenceEvent {
  final int id;
  final int geofenceId;
  final int nodeId;
  final String type;
  final DateTime eventTime;
  final double? lat;
  final double? lon;
  final String? geofenceName;
  final String? nodeName;

  GeofenceEvent({
    required this.id,
    required this.geofenceId,
    required this.nodeId,
    required this.type,
    required this.eventTime,
    this.lat,
    this.lon,
    this.geofenceName,
    this.nodeName,
  });

  factory GeofenceEvent.fromJson(Map<String, dynamic> json) {
    return GeofenceEvent(
      id: (json['id'] as num?)?.toInt() ?? 0,
      geofenceId: (json['geofenceId'] as num?)?.toInt() ?? 0,
      nodeId: (json['nodeId'] as num?)?.toInt() ?? 0,
      type: (json['type'] ?? '').toString(),
      eventTime: DateTime.parse(
          (json['eventTime'] ?? DateTime.now().toIso8601String()).toString()),
      lat: json['lat'] is num ? (json['lat'] as num).toDouble() : null,
      lon: json['lon'] is num ? (json['lon'] as num).toDouble() : null,
      geofenceName: json['geofenceName'] is String
          ? json['geofenceName'] as String
          : null,
      nodeName: json['nodeName'] is String ? json['nodeName'] as String : null,
    );
  }
}
