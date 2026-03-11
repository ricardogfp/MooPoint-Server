class BehaviorData {
  final DateTime timestamp;
  final int ruminatingSeconds;
  final int grazingSeconds;
  final int restingSeconds;
  final int movingSeconds;
  final int feedingSeconds;
  final int confidence;

  BehaviorData({
    required this.timestamp,
    required this.ruminatingSeconds,
    required this.grazingSeconds,
    required this.restingSeconds,
    required this.movingSeconds,
    required this.feedingSeconds,
    required this.confidence,
  });

  factory BehaviorData.fromJson(Map<String, dynamic> json) {
    return BehaviorData(
      timestamp: DateTime.parse(json['timestamp']),
      ruminatingSeconds: json['ruminating_s'] ?? 0,
      grazingSeconds: json['grazing_s'] ?? 0,
      restingSeconds: json['resting_s'] ?? 0,
      movingSeconds: json['moving_s'] ?? 0,
      feedingSeconds: json['feeding_s'] ?? 0,
      confidence: json['confidence'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'ruminating_s': ruminatingSeconds,
      'grazing_s': grazingSeconds,
      'resting_s': restingSeconds,
      'moving_s': movingSeconds,
      'feeding_s': feedingSeconds,
      'confidence': confidence,
    };
  }

  // Total activity seconds
  int get totalSeconds =>
      ruminatingSeconds +
      grazingSeconds +
      restingSeconds +
      movingSeconds +
      feedingSeconds;

  // Get percentages
  double get ruminatingPercent =>
      totalSeconds > 0 ? (ruminatingSeconds / totalSeconds) * 100 : 0;
  double get grazingPercent =>
      totalSeconds > 0 ? (grazingSeconds / totalSeconds) * 100 : 0;
  double get restingPercent =>
      totalSeconds > 0 ? (restingSeconds / totalSeconds) * 100 : 0;
  double get movingPercent =>
      totalSeconds > 0 ? (movingSeconds / totalSeconds) * 100 : 0;
  double get feedingPercent =>
      totalSeconds > 0 ? (feedingSeconds / totalSeconds) * 100 : 0;
}

class BehaviorSummary {
  final String date;
  final int ruminatingMinutes;
  final int grazingMinutes;
  final int restingMinutes;
  final int movingMinutes;
  final int feedingMinutes;

  BehaviorSummary({
    required this.date,
    required this.ruminatingMinutes,
    required this.grazingMinutes,
    required this.restingMinutes,
    required this.movingMinutes,
    required this.feedingMinutes,
  });

  factory BehaviorSummary.fromJson(Map<String, dynamic> json) {
    return BehaviorSummary(
      date: json['date'],
      ruminatingMinutes: json['ruminating_minutes'] ?? 0,
      grazingMinutes: json['grazing_minutes'] ?? 0,
      restingMinutes: json['resting_minutes'] ?? 0,
      movingMinutes: json['moving_minutes'] ?? 0,
      feedingMinutes: json['feeding_minutes'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'ruminating_minutes': ruminatingMinutes,
      'grazing_minutes': grazingMinutes,
      'resting_minutes': restingMinutes,
      'moving_minutes': movingMinutes,
      'feeding_minutes': feedingMinutes,
    };
  }

  // Total activity minutes
  int get totalMinutes =>
      ruminatingMinutes +
      grazingMinutes +
      restingMinutes +
      movingMinutes +
      feedingMinutes;

  // Get percentages
  double get ruminatingPercent =>
      totalMinutes > 0 ? (ruminatingMinutes / totalMinutes) * 100 : 0;
  double get grazingPercent =>
      totalMinutes > 0 ? (grazingMinutes / totalMinutes) * 100 : 0;
  double get restingPercent =>
      totalMinutes > 0 ? (restingMinutes / totalMinutes) * 100 : 0;
  double get movingPercent =>
      totalMinutes > 0 ? (movingMinutes / totalMinutes) * 100 : 0;
  double get feedingPercent =>
      totalMinutes > 0 ? (feedingMinutes / totalMinutes) * 100 : 0;

  // Get hours for display
  double get ruminatingHours => ruminatingMinutes / 60.0;
  double get grazingHours => grazingMinutes / 60.0;
  double get restingHours => restingMinutes / 60.0;
  double get movingHours => movingMinutes / 60.0;
  double get feedingHours => feedingMinutes / 60.0;
  double get totalHours => totalMinutes / 60.0;

  // Health indicators
  bool get isHealthy {
    // Healthy cow should ruminate 6-8 hours per day
    return ruminatingHours >= 6 && ruminatingHours <= 10;
  }

  String get healthStatus {
    if (ruminatingHours < 4) return 'Low Rumination - Check Health';
    if (ruminatingHours < 6) return 'Below Normal Rumination';
    if (ruminatingHours > 10) return 'High Rumination';
    return 'Normal';
  }
}
