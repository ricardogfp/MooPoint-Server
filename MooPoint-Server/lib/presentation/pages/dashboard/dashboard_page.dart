import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/l10n/app_localizations.dart';

import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/providers/settings_provider.dart';
import 'package:moo_point/presentation/providers/navigation_provider.dart';
import 'package:moo_point/data/models/alert_model.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/l10n/l10n_helper.dart';
import 'package:moo_point/presentation/pages/nodes/node_placement_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Consumer<HerdState>(
      builder: (context, state, _) {
        if (state.nodesLoading && state.nodes.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await state.loadNodesAndGeofences();
            await state.loadAlerts();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Page Header ---
                  _DashboardHeader(l10n: l10n),

                  // --- New Node Detection Banner ---
                  if (state.newNodesRequiringPlacement.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _NewNodeBanner(
                        nodes: state.newNodesRequiringPlacement),
                  ],
                  const SizedBox(height: 32),

                  // --- KPI Cards ---
                  _KpiGrid(state: state, l10n: l10n),
                  const SizedBox(height: 32),

                  // --- Main Grid: Activity & Alerts ---
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktop = constraints.maxWidth > 900;
                      if (isDesktop) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _ActivityFeed(state: state, l10n: l10n),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 5,
                              child: _AlertsPanel(state: state, l10n: l10n),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          _ActivityFeed(state: state, l10n: l10n),
                          const SizedBox(height: 32),
                          _AlertsPanel(state: state, l10n: l10n),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 48),
                  // --- Footer ---
                  _DashboardFooter(l10n: l10n),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// New Node Detection Banner
// ---------------------------------------------------------------------------
class _NewNodeBanner extends StatelessWidget {
  final List<NodeModel> nodes;
  const _NewNodeBanner({required this.nodes});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: MooColors.fenceBrown.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MooColors.fenceBrown.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MooColors.fenceBrown.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fence_rounded,
                color: MooColors.fenceBrown, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nodes.length == 1
                      ? 'New fence node needs placement'
                      : '${nodes.length} fence nodes need placement',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MooColors.fenceBrown),
                ),
                Text(
                  nodes.length == 1
                      ? '"${nodes.first.getName()}" has no map position yet.'
                      : 'Tap to set their permanent map positions.',
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NodePlacementPage(newNodes: nodes),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: MooColors.fenceBrown,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: const Text('Place Now'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------
class _DashboardHeader extends StatelessWidget {
  final AppLocalizations l10n;
  const _DashboardHeader({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.dashboard,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.welcomeBack(context.read<SettingsProvider>().username.isEmpty ? 'User' : context.read<SettingsProvider>().username),
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.2).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5),
              blurRadius: 4,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI Cards
// ---------------------------------------------------------------------------
class _KpiGrid extends StatelessWidget {
  final HerdState state;
  final AppLocalizations l10n;
  const _KpiGrid({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final active = state.nodes.where((n) => n.overallStatus == 'Active').length;
    final lowBatt =
        state.nodes.where((n) => n.overallStatus == 'Low Battery').length;
    final activeAlerts = state.alerts.where((a) => !a.resolved).length;
    final fenceAlerts = state.alerts
        .where((a) =>
            !a.resolved &&
            (a.type == AlertType.fenceVoltageFailure ||
                a.type == AlertType.fenceVoltageDropped))
        .length;
    final connectivity = state.nodes.isEmpty
        ? "0.0"
        : (active / state.nodes.length * 100).toStringAsFixed(1);

    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth > 1100
          ? 5
          : (constraints.maxWidth > 600 ? 2 : 1);
      final spacing = 16.0;
      final itemWidth =
          (constraints.maxWidth - (spacing * (columns - 1))) / columns;

      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          _KpiCard(
            title: l10n.totalAnimals,
            value: '${state.nodes.length}',
            icon: Icons.pets,
            color: MooColors.primary,
            subtitle: '${state.nodes.length} registered',
            width: itemWidth,
          ),
          _KpiCard(
            title: l10n.onlineNow,
            value: '$active',
            icon: Icons.sensors,
            color: MooColors.active,
            subtitle: l10n.connectivity(connectivity),
            width: itemWidth,
          ),
          _KpiCard(
            title: l10n.activeAlerts,
            value: '$activeAlerts',
            icon: Icons.warning_amber_rounded,
            color: MooColors.warning,
            subtitle: l10n.requiresAttention,
            width: itemWidth,
            isAmber: true,
          ),
          _KpiCard(
            title: l10n.batteryCritical,
            value: '$lowBatt',
            icon: Icons.battery_alert_rounded,
            color: MooColors.lowBattery,
            subtitle: l10n.rechargeNeeded,
            width: itemWidth,
            isRed: true,
          ),
          _KpiCard(
            title: l10n.fenceAlerts,
            value: '$fenceAlerts',
            icon: Icons.bolt_rounded,
            color: MooColors.fenceBrown,
            subtitle: l10n.breachDetected,
            width: itemWidth,
            isFence: true,
          ),
        ],
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  final IconData? subtitleIcon;
  final Color? subtitleColor;
  final double width;
  final bool isAmber;
  final bool isRed;
  final bool isFence;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
    this.subtitleIcon,
    this.subtitleColor,
    required this.width,
    this.isAmber = false,
    this.isRed = false,
    this.isFence = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAmber
              ? Colors.amber.withOpacity(0.1)
              : isRed
                  ? Colors.red.withOpacity(0.1)
                  : isFence
                      ? MooColors.fenceBrown.withOpacity(0.2)
                      : Theme.of(context).brightness == Brightness.dark
                          ? MooColors.borderDark
                          : MooColors.borderLight,
        ),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (subtitleIcon != null) ...[
                Icon(subtitleIcon, size: 14, color: subtitleColor),
                const SizedBox(width: 4),
              ],
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor ??
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Feed
// ---------------------------------------------------------------------------
class _ActivityFeed extends StatelessWidget {
  final HerdState state;
  final AppLocalizations l10n;
  const _ActivityFeed({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.recentActivity,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: () => context.read<NavigationIndexProvider>().setIndex(4),
              child: Text(
                l10n.viewAll,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (state.events.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.history,
                      size: 48,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.1)),
                  const SizedBox(height: 12),
                  Text(l10n.noRecentEvents,
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.4))),
                ],
              ),
            ),
          )
        else
          ...state.events
              .take(6)
              .map((event) => _FeedItem(event: event, l10n: l10n)),
      ],
    );
  }
}

class _FeedItem extends StatelessWidget {
  final GeofenceEvent event;
  final AppLocalizations l10n;
  const _FeedItem({required this.event, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final isExit = event.type == 'exit';
    final isCattle = (event.nodeId % 2 == 0); // Mock logic for demo
    final color = isCattle ? MooColors.primary : MooColors.fenceBrown;
    final icon = isCattle ? Icons.location_on : Icons.bolt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? MooColors.borderDark
                : MooColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (isCattle ? l10n.cattleEvent : l10n.fenceEvent)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: color,
                      ),
                    ),
                    Text(
                      _relativeTime(event.eventTime, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${event.nodeName ?? "Node ${event.nodeId}"} ${isExit ? l10n.exited : l10n.entered} ${event.geofenceName ?? "Zone"}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "GPS updated: 45.321, -121.454", // Simulated
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt, AppLocalizations l10n) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return l10n.justNow;
    if (d.inMinutes < 60) return l10n.minutesAgo(d.inMinutes);
    if (d.inHours < 24) return l10n.hoursAgo(d.inHours);
    return l10n.daysAgo(d.inDays);
  }
}

// ---------------------------------------------------------------------------
// Alerts Panel
// ---------------------------------------------------------------------------
class _AlertsPanel extends StatelessWidget {
  final HerdState state;
  final AppLocalizations l10n;
  const _AlertsPanel({required this.state, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final activeAlerts =
        state.alerts.where((a) => !a.resolved).take(5).toList();
    final activeCount = state.alerts.where((a) => !a.resolved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.activeAlertsTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: activeCount > 0
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.green.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                activeCount > 0 ? '$activeCount Active' : 'All Clear',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (activeAlerts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('No active alerts. All systems nominal.',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          )
        else
          ...activeAlerts.map((alert) {
            final color = _severityColor(alert.severity);
            return _AlertCard(
              type: _severityLabel(alert.severity),
              title: alert.title,
              description: alert.body,
              color: color,
              icon: _alertIcon(alert.type),
              action1: 'Resolve',
              action2: 'View',
              onAction1: () => state.resolveAlert(alert.id),
            );
          }),
      ],
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

  String _severityLabel(AlertSeverity s) {
    switch (s) {
      case AlertSeverity.critical:
        return 'Critical';
      case AlertSeverity.warning:
        return 'Warning';
      case AlertSeverity.info:
        return 'Info';
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
      default:
        return Icons.warning_rounded;
    }
  }
}

class _AlertCard extends StatelessWidget {
  final String type;
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final double iconSize;
  final String action1;
  final String? action2;
  final VoidCallback? onAction1;
  final VoidCallback? onAction2;

  const _AlertCard({
    required this.type,
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    this.iconSize = 18,
    required this.action1,
    this.action2,
    this.onAction1,
    this.onAction2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.8), size: iconSize),
              const SizedBox(width: 8),
              Text(
                type.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAction1,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(action1,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
              if (action2 != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onAction2,
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? MooColors.bgDark
                              : Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? MooColors.borderDark
                              : MooColors.borderLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(action2!,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------
class _DashboardFooter extends StatelessWidget {
  final AppLocalizations l10n;
  const _DashboardFooter({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(
            top: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? MooColors.borderDark
                    : MooColors.borderLight)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "MooPoint v4.2.0 · IoT Livestock Management",
            style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
          Text(
            l10n.lastSynced("just now"),
            style: TextStyle(
                fontSize: 11,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}
