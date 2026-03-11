import 'package:moo_point/data/models/geofence_event_model.dart';

enum AlertSeverity { critical, warning, info }

enum AlertType {
  fenceVoltageFailure,
  fenceVoltageDropped,
  nodeOffline,
  nodeLowBattery,
  geofenceBreach,
  reducedRumination,
  abnormalActivity,
}

class AlertModel {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String body;
  final DateTime timestamp;
  final int? nodeId;
  final String? nodeName;
  final int? geofenceId;
  final String? geofenceName;
  final bool resolved;
  final String? notes;

  const AlertModel({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.body,
    required this.timestamp,
    this.nodeId,
    this.nodeName,
    this.geofenceId,
    this.geofenceName,
    this.resolved = false,
    this.notes,
  });

  AlertModel copyWith({bool? resolved, String? notes}) {
    return AlertModel(
      id: id,
      type: type,
      severity: severity,
      title: title,
      body: body,
      timestamp: timestamp,
      nodeId: nodeId,
      nodeName: nodeName,
      geofenceId: geofenceId,
      geofenceName: geofenceName,
      resolved: resolved ?? this.resolved,
      notes: notes ?? this.notes,
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseType(json['alertType'] ?? json['type']),
      severity: _parseSeverity(json['severity']),
      title: json['title'] ?? 'Alert',
      body: json['message'] ?? json['body'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      nodeId: json['nodeId'] as int?,
      nodeName: json['nodeName'] as String?,
      geofenceId: json['geofenceId'] as int?,
      geofenceName: json['geofenceName'] as String?,
      resolved: json['resolved'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  factory AlertModel.fromGeofenceEvent(GeofenceEvent event) {
    final nodeName = event.nodeName ?? 'Node ${event.nodeId}';
    final fenceName = event.geofenceName ?? 'Geofence ${event.geofenceId}';
    return AlertModel(
      id: 'geofence_${event.nodeId}_${event.geofenceId}_${event.eventTime.millisecondsSinceEpoch}',
      type: AlertType.geofenceBreach,
      severity: AlertSeverity.critical,
      title: 'Geofence Breach',
      body: '$nodeName exited $fenceName.',
      timestamp: event.eventTime,
      nodeId: event.nodeId,
      nodeName: nodeName,
      geofenceId: event.geofenceId,
      geofenceName: fenceName,
    );
  }

  /// Builds an AlertModel from the unified /nodejs/api/alerts response.
  /// [json] must include `alertKey` as the stable cross-restart identifier.
  factory AlertModel.fromApiAlert(Map<String, dynamic> json) {
    return AlertModel(
      id: json['alertKey']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: _parseType(json['alertType']),
      severity: _parseSeverity(json['severity']),
      title: json['title'] ?? 'Alert',
      body: json['message'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      nodeId: json['nodeId'] as int?,
      nodeName: json['nodeName'] as String?,
      geofenceId: json['geofenceId'] as int?,
      geofenceName: json['geofenceName'] as String?,
      resolved: json['resolved'] as bool? ?? false,
    );
  }

  factory AlertModel.fromNodeAlert(Map<String, dynamic> json) {
    final alertType = json['alertType'] as String? ?? '';
    AlertType type;
    AlertSeverity severity;

    if (alertType == 'voltage_low' || alertType == 'fence_voltage_low') {
      type = AlertType.fenceVoltageDropped;
      severity = AlertSeverity.warning;
    } else if (alertType == 'voltage_failure' ||
        alertType == 'fence_voltage_failure') {
      type = AlertType.fenceVoltageFailure;
      severity = AlertSeverity.critical;
    } else if (alertType == 'battery_low') {
      type = AlertType.nodeLowBattery;
      severity = AlertSeverity.warning;
    } else if (alertType == 'offline') {
      type = AlertType.nodeOffline;
      severity = AlertSeverity.critical;
    } else {
      type = AlertType.abnormalActivity;
      severity = AlertSeverity.info;
    }

    final nodeId = json['nodeId'] as int?;
    final nodeName = json['nodeName'] as String? ?? 'Node $nodeId';

    return AlertModel(
      id: 'node_${nodeId}_${alertType}_${DateTime.now().millisecondsSinceEpoch}',
      type: type,
      severity: severity,
      title: _titleForType(type),
      body: json['message'] as String? ?? 'Alert received from $nodeName',
      timestamp: DateTime.now(),
      nodeId: nodeId,
      nodeName: nodeName,
    );
  }

  static AlertType _parseType(dynamic raw) {
    switch (raw?.toString()) {
      case 'fence_voltage_failure':
        return AlertType.fenceVoltageFailure;
      case 'fence_voltage_dropped':
        return AlertType.fenceVoltageDropped;
      case 'node_offline':
        return AlertType.nodeOffline;
      case 'battery_low':
        return AlertType.nodeLowBattery;
      case 'geofence_breach':
        return AlertType.geofenceBreach;
      case 'reduced_rumination':
        return AlertType.reducedRumination;
      case 'abnormal_activity':
        return AlertType.abnormalActivity;
      case 'health_deteriorated':
        return AlertType.abnormalActivity;
      case 'voltage_low':
        return AlertType.fenceVoltageFailure;
      default:
        return AlertType.abnormalActivity;
    }
  }

  static AlertSeverity _parseSeverity(dynamic raw) {
    switch (raw?.toString()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }

  static String _titleForType(AlertType type) {
    switch (type) {
      case AlertType.fenceVoltageFailure:
        return 'Fence Voltage Failure';
      case AlertType.fenceVoltageDropped:
        return 'Fence Voltage Dropped';
      case AlertType.nodeOffline:
        return 'Node Offline';
      case AlertType.nodeLowBattery:
        return 'Low Battery';
      case AlertType.geofenceBreach:
        return 'Geofence Breach';
      case AlertType.reducedRumination:
        return 'Reduced Rumination';
      case AlertType.abnormalActivity:
        return 'Abnormal Activity';
    }
  }
}
