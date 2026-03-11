import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/widgets/charts/behavior_chart_widget.dart';
import 'package:moo_point/presentation/widgets/dashboard/behavior_insights_widget.dart';
import 'package:moo_point/main.dart';

class AnimalDetailPage extends StatelessWidget {
  final NodeModel node;
  const AnimalDetailPage({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? MooColors.bgDark : MooColors.bgLight,
      body: CustomScrollView(
        slivers: [
          // Sticky header
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: _HeroHeader(node: node),
              title: Text(
                node.getName(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.map_outlined, color: Colors.white),
                tooltip: 'View on Map',
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to map and select node
                  Future.delayed(const Duration(milliseconds: 100), () {
                    HomePage.mapKey.currentState?.selectNode(node);
                  });
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status & Battery
                  _NodeStatusCard(node: node),
                  const SizedBox(height: 12),

                  // Animal Profile
                  _AnimalProfileCard(node: node),
                  const SizedBox(height: 12),

                  // Behavior Analytics
                  _BehaviorCard(node: node),
                  const SizedBox(height: 12),

                  // Health Insights
                  _HealthInsightsCard(node: node),
                  const SizedBox(height: 12),

                  // Event History
                  _EventHistoryCard(node: node),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _ActionButtons(node: node),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero Header
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  final NodeModel node;
  const _HeroHeader({required this.node});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MooColors.primary.withValues(alpha: 0.8),
            const Color(0xFF1A3A5C),
          ],
        ),
      ),
      child: node.photoUrl != null && node.photoUrl!.isNotEmpty
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  node.photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: NodeAvatar(node: node, radius: 40),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node Status Card
// ---------------------------------------------------------------------------

class _NodeStatusCard extends StatelessWidget {
  final NodeModel node;
  const _NodeStatusCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final herdState = context.read<HerdState>();
    final assignedGeofence = herdState.geofences
        .where((g) => g.nodeIds.contains(node.nodeId))
        .firstOrNull;

    return _DetailCard(
      title: 'Node Status',
      icon: Icons.sensors,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatusItem(
                  label: 'Status',
                  value: node.overallStatus,
                  valueColor: Color(node.statusColor),
                ),
              ),
              Expanded(
                child: _StatusItem(
                  label: 'Battery',
                  value: '${node.batteryLevel}%',
                  valueColor: Color(node.batteryStatusColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Battery bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: node.batteryLevel / 100,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                  Color(node.batteryStatusColor)),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (node.rssi != null)
                Expanded(
                  child: _StatusItem(
                    label: 'Signal',
                    value: '${node.rssi} dBm',
                  ),
                ),
              Expanded(
                child: _StatusItem(
                  label: 'Last Seen',
                  value: _timeAgo(node.lastUpdated),
                ),
              ),
              if (assignedGeofence != null)
                Expanded(
                  child: _StatusItem(
                    label: 'Geofence',
                    value: assignedGeofence.name,
                  ),
                ),
            ],
          ),
          if (node.nodeType == NodeType.fence && node.voltage != null) ...[
            const SizedBox(height: 8),
            _StatusItem(
              label: 'Fence Voltage',
              value:
                  '${(node.voltage! / 1000).toStringAsFixed(1)} kV',
              valueColor:
                  node.hasVoltageFault ? Colors.red : Colors.green,
            ),
          ],
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatusItem({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor,
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Animal Profile Card
// ---------------------------------------------------------------------------

class _AnimalProfileCard extends StatelessWidget {
  final NodeModel node;
  const _AnimalProfileCard({required this.node});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      title: 'Animal Profile',
      icon: MdiIcons.cow,
      child: Column(
        children: [
          if (node.breed != null && node.breed!.isNotEmpty)
            _ProfileRow(label: 'Breed', value: node.breed!),
          if (node.age != null)
            _ProfileRow(
                label: 'Age',
                value: '${node.age} ${node.age == 1 ? 'year' : 'years'}'),
          if (node.healthStatus != null && node.healthStatus!.isNotEmpty)
            _ProfileRow(label: 'Health', value: node.healthStatus!),
          if (node.comments != null && node.comments!.isNotEmpty)
            _ProfileRow(label: 'Notes', value: node.comments!),
          if (node.breed == null &&
              node.age == null &&
              node.healthStatus == null &&
              node.comments == null)
            const Text(
              'No profile information available. Configure this node to add animal details.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  const _ProfileRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Behavior Analytics Card
// ---------------------------------------------------------------------------

class _BehaviorCard extends StatelessWidget {
  final NodeModel node;
  const _BehaviorCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final herdState = context.read<HerdState>();
    return _DetailCard(
      title: 'Behavior Analytics',
      icon: Icons.bar_chart_rounded,
      child: Column(
        children: [
          BehaviorChartWidget(nodeId: node.nodeId),
          const SizedBox(height: 12),
          FutureBuilder<BehaviorSummary?>(
            future: herdState.getBehaviorSummaryForNode(node.nodeId),
            builder: (ctx, snap) {
              final summary = snap.data;
              if (summary == null) return const SizedBox.shrink();
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _healthColor(summary).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _healthColor(summary).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(_healthIcon(summary),
                        color: _healthColor(summary), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(summary.healthStatus,
                          style: TextStyle(
                              fontSize: 13,
                              color: _healthColor(summary),
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _healthColor(BehaviorSummary s) {
    if (s.ruminatingHours < 4) return Colors.red;
    if (s.ruminatingHours < 6) return Colors.orange;
    return Colors.green;
  }

  IconData _healthIcon(BehaviorSummary s) {
    if (s.ruminatingHours < 4) return Icons.warning_rounded;
    if (s.ruminatingHours < 6) return Icons.info_outline;
    return Icons.check_circle_outline;
  }
}


// ---------------------------------------------------------------------------
// Event History Card
// ---------------------------------------------------------------------------

class _EventHistoryCard extends StatelessWidget {
  final NodeModel node;
  const _EventHistoryCard({required this.node});

  @override
  Widget build(BuildContext context) {
    final herdState = context.read<HerdState>();
    final nodeAlerts = herdState.alerts
        .where((a) => a.nodeId == node.nodeId)
        .take(10)
        .toList();

    return _DetailCard(
      title: 'Event History',
      icon: Icons.history_rounded,
      child: nodeAlerts.isEmpty
          ? const Text('No events recorded.',
              style: TextStyle(fontSize: 12, color: Colors.grey))
          : Column(
              children: nodeAlerts
                  .map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(_eventIcon(a.type.name),
                                size: 15, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(a.title,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Text(
                              _timeAgo(a.timestamp),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
    );
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'geofenceBreach':
        return Icons.location_off_rounded;
      case 'nodeOffline':
        return Icons.wifi_off_rounded;
      case 'nodeLowBattery':
        return Icons.battery_alert_rounded;
      default:
        return Icons.info_outline;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Action Buttons
// ---------------------------------------------------------------------------

class _ActionButtons extends StatelessWidget {
  final NodeModel node;
  const _ActionButtons({required this.node});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Future.delayed(const Duration(milliseconds: 100), () {
              HomePage.mapKey.currentState?.selectNode(node);
            });
          },
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('View on Map'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            // TODO: open config drawer for this node
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Open map to configure node')),
            );
          },
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: const Text('Configure Node'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable detail card
// ---------------------------------------------------------------------------

class _DetailCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? MooColors.borderDark : MooColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: MooColors.primary),
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
