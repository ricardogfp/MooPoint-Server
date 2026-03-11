import 'package:moo_point/app/theme/app_theme.dart';

enum NodeType {
  cattle,
  fence,
}

class NodeModel {
  final int nodeId;
  final int? deviceId;
  final String name;
  final double latitude;
  final double longitude;
  final int batteryLevel; // 0-100%
  final int? voltage; // in Volts
  final DateTime lastUpdated;
  final NodeType nodeType;
  final String? breed;
  final int? age;
  final String? healthStatus;
  final String? comments;
  final int? rssi;
  final double? temperature;
  final String? photoUrl;
  final bool isNew;

  NodeModel({
    required this.nodeId,
    this.deviceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.batteryLevel,
    this.voltage,
    required this.lastUpdated,
    this.nodeType = NodeType.cattle,
    this.breed,
    this.age,
    this.healthStatus,
    this.comments,
    this.photoUrl,
    this.isNew = false,
    this.rssi,
    this.temperature,
  });

  NodeModel copyWith({
    int? nodeId,
    int? deviceId,
    String? name,
    double? latitude,
    double? longitude,
    int? batteryLevel,
    int? voltage,
    DateTime? lastUpdated,
    NodeType? nodeType,
    String? breed,
    int? age,
    String? healthStatus,
    String? comments,
    String? photoUrl,
    bool? isNew,
  }) {
    return NodeModel(
      nodeId: nodeId ?? this.nodeId,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      voltage: voltage ?? this.voltage,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      nodeType: nodeType ?? this.nodeType,
      breed: breed ?? this.breed,
      age: age ?? this.age,
      healthStatus: healthStatus ?? this.healthStatus,
      comments: comments ?? this.comments,
      photoUrl: photoUrl ?? this.photoUrl,
      isNew: isNew ?? this.isNew,
      rssi: rssi ?? this.rssi,
      temperature: temperature ?? this.temperature,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'deviceId': deviceId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'batteryLevel': batteryLevel,
      'voltage': voltage,
      'lastUpdated': lastUpdated.toIso8601String(),
      'nodeType': nodeType.name,
      'breed': breed,
      'age': age,
      'healthStatus': healthStatus,
      'comments': comments,
      'photoUrl': photoUrl,
      'isNew': isNew,
      'rssi': rssi,
      'temperature': temperature,
    };
  }

  factory NodeModel.fromJson(Map<String, dynamic> json) {
    // Handle nodeId as either int or string
    final nodeIdRaw = json['nodeId'];
    final nodeId = nodeIdRaw is int
        ? nodeIdRaw
        : (nodeIdRaw is String ? int.tryParse(nodeIdRaw) : null);

    if (nodeId == null) {
      throw ArgumentError('Invalid or missing nodeId in JSON');
    }

    return NodeModel(
      nodeId: nodeId,
      deviceId:
          json['deviceId'] == null ? null : (json['deviceId'] as num).toInt(),
      name: json['name'] ?? 'Node $nodeId',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      batteryLevel: (json['batteryLevel'] as num?)?.toInt() ?? 0,
      voltage:
          json['voltage'] == null ? null : (json['voltage'] as num).toInt(),
      lastUpdated: DateTime.parse(json['lastUpdated']),
      nodeType: json['nodeType'] == 'fence' ? NodeType.fence : NodeType.cattle,
      breed: json['breed'],
      age: json['age'],
      healthStatus: json['healthStatus'],
      comments: json['comments'],
      photoUrl: json['photoUrl'] is String ? json['photoUrl'] as String : null,
      isNew: json['isNew'] ?? false,
      rssi: json['rssi'] == null ? null : (json['rssi'] as num).toInt(),
      temperature: json['temperature'] == null
          ? null
          : (json['temperature'] as num).toDouble(),
    );
  }

  // Get a friendly name for the node
  String getName() => name.isNotEmpty ? name : 'Node $nodeId';

  // Get battery status text
  String get batteryStatus {
    if (batteryLevel >= 80) return 'Good';
    if (batteryLevel >= 50) return 'Medium';
    if (batteryLevel >= 20) return 'Low';
    return 'Critical';
  }

  // Get battery status color
  int get batteryStatusColor {
    if (batteryLevel >= 80) return MooColors.battGood.toARGB32();
    if (batteryLevel >= 50) return MooColors.battMedium.toARGB32();
    if (batteryLevel >= 20) return MooColors.battLow.toARGB32();
    return MooColors.battCritical.toARGB32();
  }

  // Check if voltage is in fault state (for fences)
  bool get hasVoltageFault {
    if (nodeType != NodeType.fence || voltage == null) return false;
    return voltage! < 5000; // 5kV threshold
  }

  // Get location description
  String get locationDescription {
    return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
  }

  // Check if data is recent (within last hour)
  bool get isRecent {
    return DateTime.now().difference(lastUpdated).inHours < 1;
  }

  // Get status based on battery, last update and voltage
  String get overallStatus {
    if (hasVoltageFault) return 'FENCE FAULT';
    if (!isRecent) return 'Offline';
    if (batteryLevel < 20) return 'Low Battery';
    return 'Active';
  }

  // Get status color
  int get statusColor {
    if (hasVoltageFault) return 0xFFFF0000; // Red
    if (!isRecent) return MooColors.offline.toARGB32();
    if (batteryLevel < 20) return MooColors.lowBattery.toARGB32();
    return MooColors.active.toARGB32();
  }
}
