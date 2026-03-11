import 'package:flutter/material.dart';
import 'package:moo_point/data/models/behavior_model.dart';

enum AlertSeverity { critical, warning, info }

class BehaviorAlert {
  final String title;
  final String message;
  final AlertSeverity severity;
  final IconData icon;
  final String recommendation;

  BehaviorAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.icon,
    required this.recommendation,
  });

  Color get color {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.info:
        return Colors.blue;
    }
  }

  Color get backgroundColor {
    switch (severity) {
      case AlertSeverity.critical:
        return Colors.red.shade50;
      case AlertSeverity.warning:
        return Colors.orange.shade50;
      case AlertSeverity.info:
        return Colors.blue.shade50;
    }
  }
}

class BehaviorAlertsWidget extends StatelessWidget {
  final BehaviorSummary summary;

  const BehaviorAlertsWidget({
    super.key,
    required this.summary,
  });

  List<BehaviorAlert> _generateAlerts() {
    final alerts = <BehaviorAlert>[];

    // Critical: Very low rumination (< 4 hours)
    if (summary.ruminatingHours < 4) {
      alerts.add(BehaviorAlert(
        title: 'Critical: Very Low Rumination',
        message:
            'Only ${summary.ruminatingHours.toStringAsFixed(1)} hours of rumination detected',
        severity: AlertSeverity.critical,
        icon: Icons.error,
        recommendation:
            'Immediate veterinary check recommended. May indicate illness, digestive issues, or pain.',
      ));
    }
    // Warning: Low rumination (4-6 hours)
    else if (summary.ruminatingHours < 6) {
      alerts.add(BehaviorAlert(
        title: 'Warning: Below Normal Rumination',
        message:
            '${summary.ruminatingHours.toStringAsFixed(1)} hours (normal: 6-8 hours)',
        severity: AlertSeverity.warning,
        icon: Icons.warning,
        recommendation:
            'Monitor closely. Check for signs of illness, stress, or feed quality issues.',
      ));
    }
    // Warning: High rumination (> 10 hours)
    else if (summary.ruminatingHours > 10) {
      alerts.add(BehaviorAlert(
        title: 'Warning: Elevated Rumination',
        message:
            '${summary.ruminatingHours.toStringAsFixed(1)} hours (normal: 6-8 hours)',
        severity: AlertSeverity.warning,
        icon: Icons.info,
        recommendation:
            'May indicate low-quality forage or digestive inefficiency. Check feed quality.',
      ));
    }

    // Critical: Excessive resting (> 16 hours)
    if (summary.restingHours > 16) {
      alerts.add(BehaviorAlert(
        title: 'Critical: Excessive Resting',
        message:
            '${summary.restingHours.toStringAsFixed(1)} hours of resting detected',
        severity: AlertSeverity.critical,
        icon: Icons.hotel,
        recommendation:
            'Possible injury, lameness, or severe illness. Immediate examination needed.',
      ));
    }
    // Warning: High resting (12-16 hours)
    else if (summary.restingHours > 12) {
      alerts.add(BehaviorAlert(
        title: 'Warning: High Resting Time',
        message: '${summary.restingHours.toStringAsFixed(1)} hours of resting',
        severity: AlertSeverity.warning,
        icon: Icons.hotel_outlined,
        recommendation:
            'Check for lameness, discomfort, or environmental stressors.',
      ));
    }

    // Warning: Very low movement (< 1 hour)
    if (summary.movingHours < 1) {
      alerts.add(BehaviorAlert(
        title: 'Warning: Low Movement',
        message:
            'Only ${summary.movingHours.toStringAsFixed(1)} hours of movement',
        severity: AlertSeverity.warning,
        icon: Icons.directions_walk,
        recommendation:
            'Check for lameness, injury, or reluctance to move. Ensure adequate space.',
      ));
    }

    // Warning: Very low grazing (< 4 hours)
    if (summary.grazingHours < 4 && summary.feedingHours < 2) {
      alerts.add(BehaviorAlert(
        title: 'Warning: Low Feeding Activity',
        message:
            'Only ${(summary.grazingHours + summary.feedingHours).toStringAsFixed(1)} hours feeding/grazing',
        severity: AlertSeverity.warning,
        icon: Icons.grass,
        recommendation:
            'Check appetite, dental health, and feed availability. May indicate illness.',
      ));
    }

    // Info: Normal behavior
    if (alerts.isEmpty) {
      alerts.add(BehaviorAlert(
        title: 'All Systems Normal',
        message: 'Behavior patterns are within healthy ranges',
        severity: AlertSeverity.info,
        icon: Icons.check_circle,
        recommendation:
            'Continue current care routine. Monitor for any changes.',
      ));
    }

    // Sort by severity (critical first, then warning, then info)
    alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));

    return alerts;
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _generateAlerts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                'Smart Health Alerts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return _buildAlertCard(context, alert);
          },
        ),
      ],
    );
  }

  Widget _buildAlertCard(BuildContext context, BehaviorAlert alert) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: alert.backgroundColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alert.icon,
                  color: alert.color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: alert.color,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alert.message,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: alert.color.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: alert.color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.recommendation,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
