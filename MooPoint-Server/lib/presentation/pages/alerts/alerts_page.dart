import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/data/models/alert_model.dart';
import 'package:moo_point/presentation/pages/herd/animal_detail_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  AlertSeverity? _filterSeverity;
  bool _showResolved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HerdState>().loadAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    var alerts = herdState.alerts;
    if (!_showResolved) alerts = alerts.where((a) => !a.resolved).toList();
    if (_filterSeverity != null) {
      alerts = alerts.where((a) => a.severity == _filterSeverity).toList();
    }

    // Group by date
    final grouped = <String, List<AlertModel>>{};
    for (final alert in alerts) {
      final key = _dateLabel(alert.timestamp);
      grouped.putIfAbsent(key, () => []).add(alert);
    }
    final dateKeys = grouped.keys.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header stats bar
          _AlertSummaryBar(alerts: herdState.alerts),

          // Filter row
          _FilterRow(
            severity: _filterSeverity,
            showResolved: _showResolved,
            onSeverityChanged: (s) => setState(() => _filterSeverity = s),
            onShowResolvedChanged: (v) => setState(() => _showResolved = v),
          ),

          // Alert list
          Expanded(
            child: herdState.alertsLoading
                ? const Center(child: CircularProgressIndicator())
                : alerts.isEmpty
                    ? EmptyStateWidget(
                        icon: Icons.notifications_active_outlined,
                        title: 'No Alerts',
                        subtitle: _filterSeverity != null || _showResolved
                            ? 'No alerts match the current filter.'
                            : 'Everything looks good. Active alerts will appear here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: dateKeys.length,
                        itemBuilder: (ctx, i) {
                          final key = dateKeys[i];
                          final dayAlerts = grouped[key]!;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                child: Text(
                                  key,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white54
                                        : Colors.black45,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...dayAlerts.map(
                                (alert) => _AlertCard(
                                  alert: alert,
                                  onResolve: () => context
                                      .read<HerdState>()
                                      .resolveAlert(alert.id),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    if (day == today) return 'TODAY';
    if (day == today.subtract(const Duration(days: 1))) return 'YESTERDAY';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// Summary bar
// ---------------------------------------------------------------------------

class _AlertSummaryBar extends StatelessWidget {
  final List<AlertModel> alerts;
  const _AlertSummaryBar({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = alerts.where((a) => !a.resolved).toList();
    final critical = active.where((a) => a.severity == AlertSeverity.critical).length;
    final warning = active.where((a) => a.severity == AlertSeverity.warning).length;
    final info = active.where((a) => a.severity == AlertSeverity.info).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? MooColors.borderDark : MooColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_rounded, size: 20),
          const SizedBox(width: 12),
          Text(
            'Alerts',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          _SeverityBadge(count: critical, color: Colors.red, label: 'Critical'),
          const SizedBox(width: 8),
          _SeverityBadge(count: warning, color: Colors.orange, label: 'Warning'),
          const SizedBox(width: 8),
          _SeverityBadge(count: info, color: Colors.blue, label: 'Info'),
        ],
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _SeverityBadge(
      {required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$count $label',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final AlertSeverity? severity;
  final bool showResolved;
  final ValueChanged<AlertSeverity?> onSeverityChanged;
  final ValueChanged<bool> onShowResolvedChanged;

  const _FilterRow({
    required this.severity,
    required this.showResolved,
    required this.onSeverityChanged,
    required this.onShowResolvedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              selected: severity == null && !showResolved,
              onTap: () {
                onSeverityChanged(null);
                onShowResolvedChanged(false);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Critical',
              selected: severity == AlertSeverity.critical,
              color: Colors.red,
              onTap: () => onSeverityChanged(
                  severity == AlertSeverity.critical ? null : AlertSeverity.critical),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Warning',
              selected: severity == AlertSeverity.warning,
              color: Colors.orange,
              onTap: () => onSeverityChanged(
                  severity == AlertSeverity.warning ? null : AlertSeverity.warning),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Info',
              selected: severity == AlertSeverity.info,
              color: Colors.blue,
              onTap: () => onSeverityChanged(
                  severity == AlertSeverity.info ? null : AlertSeverity.info),
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Resolved',
              selected: showResolved,
              color: Colors.green,
              onTap: () => onShowResolvedChanged(!showResolved),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? MooColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? c : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alert Card
// ---------------------------------------------------------------------------

class _AlertCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onResolve;

  const _AlertCard({required this.alert, required this.onResolve});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _severityColor(alert.severity);
    final icon = _alertIcon(alert.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: severityColor, width: 3),
          top: BorderSide(
              color: isDark ? MooColors.borderDark : MooColors.borderLight),
          right: BorderSide(
              color: isDark ? MooColors.borderDark : MooColors.borderLight),
          bottom: BorderSide(
              color: isDark ? MooColors.borderDark : MooColors.borderLight),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: severityColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: severityColor, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: alert.resolved ? Colors.grey : null,
                          decoration: alert.resolved
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (alert.nodeName != null)
                        Text(
                          alert.nodeName!,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Text(
                  _timeAgo(alert.timestamp),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.body,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black54),
            ),
            if (!alert.resolved) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onResolve,
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: const Text('Resolve', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (alert.nodeId != null)
                    TextButton.icon(
                      onPressed: () {
                        final nodeId = alert.nodeId;
                        if (nodeId == null) return;
                        final node = context
                            .read<HerdState>()
                            .nodes
                            .where((n) => n.nodeId == nodeId)
                            .firstOrNull;
                        if (node == null) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AnimalDetailPage(node: node),
                          ),
                        );
                      },
                      icon: const Icon(Icons.pets, size: 14),
                      label: const Text('View Animal',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Resolved',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return Colors.red;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.info:
        return Colors.blue;
    }
  }

  IconData _alertIcon(AlertType t) {
    switch (t) {
      case AlertType.fenceVoltageFailure:
      case AlertType.fenceVoltageDropped:
        return Icons.bolt;
      case AlertType.geofenceBreach:
        return Icons.location_off_rounded;
      case AlertType.nodeOffline:
        return Icons.wifi_off_rounded;
      case AlertType.nodeLowBattery:
        return Icons.battery_alert_rounded;
      case AlertType.reducedRumination:
        return Icons.grass_rounded;
      case AlertType.abnormalActivity:
        return Icons.warning_rounded;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
