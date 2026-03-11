import 'package:flutter/material.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/l10n/l10n_helper.dart';
import '../map_page.dart';

String _lastSeen(DateTime lastUpdated) {
  final diff = DateTime.now().difference(lastUpdated);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}


class MapDetailSheet extends StatelessWidget {
  final MapViewState state;
  final NodeModel node;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpenConfig;

  const MapDetailSheet({
    super.key,
    required this.state,
    required this.node,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenConfig,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCattle = state == MapViewState.cattleSelected;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          GestureDetector(
            onVerticalDragUpdate: (details) {
              if (details.primaryDelta! < -10 && !isExpanded) {
                onToggleExpand();
              } else if (details.primaryDelta! > 10 && isExpanded) {
                onToggleExpand();
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          
          // Collapsed View (Always visible part of sheet)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    NodeAvatar(node: node, radius: 22),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          node.getName(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(node.statusColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${node.overallStatus} • ${_lastSeen(node.lastUpdated)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white54 : Colors.black54),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: onToggleExpand,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.black12,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded content
          if (isExpanded)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.2,
                      children: [
                        _InfoCard(
                            label: l10n.battery,
                            value: '${node.batteryLevel}%',
                            icon: Icons.battery_charging_full_rounded),
                        _InfoCard(
                            label: l10n.signal,
                            value: '${node.rssi} dBm',
                            icon: Icons.signal_cellular_alt_rounded),
                        if (isCattle) ...[
                          _InfoCard(
                              label: l10n.temperature,
                              value: '${node.temperature}°C',
                              icon: Icons.thermostat_rounded),
                          _InfoCard(
                              label: l10n.activity,
                              value: 'Active',
                              icon: Icons.straighten_rounded),
                        ] else ...[
                          _InfoCard(
                              label: l10n.voltage,
                              value: node.voltage != null
                                  ? '${(node.voltage! / 1000).toStringAsFixed(1)} kV'
                                  : '—',
                              icon: Icons.bolt_rounded),
                          _InfoCard(
                              label: l10n.fenceType,
                              value: 'Perimeter',
                              icon: Icons.shield_outlined),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isCattle) ...[
                      Text(l10n.activityFeed,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      const _StatBar(label: 'Grazing', value: 0.65),
                      const _StatBar(label: 'Resting', value: 0.25),
                      const _StatBar(label: 'Moving', value: 0.10),
                      const SizedBox(height: 20),
                      const Text('POSITION HISTORY (24H)',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? MooColors.bgDark.withValues(alpha: 0.3)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isDark
                                  ? MooColors.borderDark
                                  : Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Distance traveled',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade500)),
                                const Text('4.2 km',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Time in motion',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey.shade500)),
                                const Text('3h 15m',
                                    style: TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(l10n.fenceVoltage,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      // Mock chart...
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onOpenConfig,
                      icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                      label: Text(l10n.remoteConfig),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? MooColors.bgDark.withValues(alpha: 0.5) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? MooColors.borderDark : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: MooColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBar extends StatelessWidget {
  final String label;
  final double value;

  const _StatBar({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500)),
              Text('${(value * 100).toInt()}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.grey.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(MooColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
