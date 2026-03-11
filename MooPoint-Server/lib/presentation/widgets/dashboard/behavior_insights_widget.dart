import 'package:flutter/material.dart';
import 'package:moo_point/data/models/behavior_model.dart';

class BehaviorInsight {
  final String text;
  final IconData icon;
  final Color color;
  final bool isPositive;

  BehaviorInsight({
    required this.text,
    required this.icon,
    required this.color,
    required this.isPositive,
  });
}

class BehaviorInsightsWidget extends StatelessWidget {
  final BehaviorSummary summary;

  const BehaviorInsightsWidget({
    super.key,
    required this.summary,
  });

  List<BehaviorInsight> _generateInsights() {
    final insights = <BehaviorInsight>[];

    // Rumination insights
    if (summary.ruminatingHours >= 6 && summary.ruminatingHours <= 8) {
      insights.add(BehaviorInsight(
        text:
            'Rumination is in the optimal range (${summary.ruminatingHours.toStringAsFixed(1)} hrs)',
        icon: Icons.check_circle,
        color: Colors.green,
        isPositive: true,
      ));
    } else if (summary.ruminatingHours < 6) {
      final deficit = 6 - summary.ruminatingHours;
      insights.add(BehaviorInsight(
        text:
            'Rumination is ${deficit.toStringAsFixed(1)} hours below normal range',
        icon: Icons.trending_down,
        color: Colors.orange,
        isPositive: false,
      ));
    } else {
      final excess = summary.ruminatingHours - 8;
      insights.add(BehaviorInsight(
        text:
            'Rumination is ${excess.toStringAsFixed(1)} hours above normal range',
        icon: Icons.trending_up,
        color: Colors.blue,
        isPositive: false,
      ));
    }

    // Activity balance insight
    final totalActiveHours =
        summary.grazingHours + summary.movingHours + summary.feedingHours;
    if (totalActiveHours >= 8 && totalActiveHours <= 12) {
      insights.add(BehaviorInsight(
        text:
            'Active time is well-balanced (${totalActiveHours.toStringAsFixed(1)} hrs)',
        icon: Icons.balance,
        color: Colors.green,
        isPositive: true,
      ));
    } else if (totalActiveHours < 8) {
      insights.add(BehaviorInsight(
        text:
            'Activity level is lower than expected (${totalActiveHours.toStringAsFixed(1)} hrs)',
        icon: Icons.warning_amber,
        color: Colors.orange,
        isPositive: false,
      ));
    }

    // Resting pattern insight
    if (summary.restingHours >= 8 && summary.restingHours <= 12) {
      insights.add(BehaviorInsight(
        text:
            'Rest time is appropriate for recovery (${summary.restingHours.toStringAsFixed(1)} hrs)',
        icon: Icons.nightlight,
        color: Colors.green,
        isPositive: true,
      ));
    } else if (summary.restingHours > 12) {
      insights.add(BehaviorInsight(
        text:
            'Excessive resting detected (${summary.restingHours.toStringAsFixed(1)} hrs) - may indicate discomfort',
        icon: Icons.hotel,
        color: Colors.red,
        isPositive: false,
      ));
    }

    // Grazing/feeding insight
    final feedingTotal = summary.grazingHours + summary.feedingHours;
    if (feedingTotal >= 6) {
      insights.add(BehaviorInsight(
        text:
            'Good feeding behavior with ${feedingTotal.toStringAsFixed(1)} hours of grazing/feeding',
        icon: Icons.restaurant,
        color: Colors.green,
        isPositive: true,
      ));
    } else if (feedingTotal < 4) {
      insights.add(BehaviorInsight(
        text:
            'Low feeding activity (${feedingTotal.toStringAsFixed(1)} hrs) - check appetite',
        icon: Icons.warning,
        color: Colors.red,
        isPositive: false,
      ));
    }

    // Movement insight
    if (summary.movingHours >= 2 && summary.movingHours <= 4) {
      insights.add(BehaviorInsight(
        text:
            'Movement patterns are healthy (${summary.movingHours.toStringAsFixed(1)} hrs)',
        icon: Icons.directions_walk,
        color: Colors.green,
        isPositive: true,
      ));
    } else if (summary.movingHours < 1) {
      insights.add(BehaviorInsight(
        text:
            'Very low movement (${summary.movingHours.toStringAsFixed(1)} hrs) - check for lameness',
        icon: Icons.warning,
        color: Colors.orange,
        isPositive: false,
      ));
    }

    // Overall health summary
    if (summary.isHealthy) {
      insights.add(BehaviorInsight(
        text: 'Overall behavior patterns indicate good health',
        icon: Icons.favorite,
        color: Colors.pink,
        isPositive: true,
      ));
    }

    return insights;
  }

  @override
  Widget build(BuildContext context) {
    final insights = _generateInsights();
    final positiveCount = insights.where((i) => i.isPositive).length;
    final negativeCount = insights.where((i) => !i.isPositive).length;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'AI Behavior Insights',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryChip(
                  context,
                  Icons.check_circle,
                  '$positiveCount Positive',
                  Colors.green,
                ),
                const SizedBox(width: 8),
                if (negativeCount > 0)
                  _buildSummaryChip(
                    context,
                    Icons.warning,
                    '$negativeCount Concern${negativeCount > 1 ? 's' : ''}',
                    Colors.orange,
                  ),
              ],
            ),
            const Divider(height: 24),
            ...insights.map((insight) => _buildInsightRow(context, insight)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightRow(BuildContext context, BehaviorInsight insight) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            insight.icon,
            color: insight.color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              insight.text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
