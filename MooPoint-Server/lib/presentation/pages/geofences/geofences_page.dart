import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/providers/navigation_provider.dart';
import 'package:moo_point/presentation/pages/geofences/geofence_edit_page.dart';

class GeofencesPage extends StatelessWidget {
  const GeofencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? MooColors.bgDark : MooColors.bgLight,
      body: const _GeofencesBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEdit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New Geofence'),
        backgroundColor: MooColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  static void _openEdit(BuildContext context, Geofence? geofence) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GeofenceEditPage(geofence: geofence),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _GeofencesBody extends StatelessWidget {
  const _GeofencesBody();

  @override
  Widget build(BuildContext context) {
    final herd = context.watch<HerdState>();
    final geofences = herd.geofences;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Geofence Management',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${geofences.length} pasture${geofences.length == 1 ? '' : 's'} configured',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                _SummaryRow(geofences: geofences, herd: herd),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (herd.nodesLoading && geofences.isEmpty)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (geofences.isEmpty)
          SliverFillRemaining(
            child: _EmptyGeofences(
              onCreate: () => GeofencesPage._openEdit(context, null),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList.separated(
              itemCount: geofences.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _GeofenceCard(
                geofence: geofences[i],
                herd: herd,
                isDark: isDark,
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Row
// ---------------------------------------------------------------------------

class _SummaryRow extends StatelessWidget {
  final List<Geofence> geofences;
  final HerdState herd;
  const _SummaryRow({required this.geofences, required this.herd});

  @override
  Widget build(BuildContext context) {
    final totalCattle = geofences.fold<Set<int>>(
      {},
      (acc, g) => acc..addAll(g.nodeIds),
    ).length;
    final breached = geofences.where(herd.isGeofenceBreached).length;
    final totalArea = geofences.fold<double>(0, (s, g) => s + g.areaHectares);

    return Row(
      children: [
        _SummaryChip(
          icon: Icons.fence_rounded,
          label: '${geofences.length} Zones',
          color: MooColors.primary,
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          icon: Icons.pets,
          label: '$totalCattle Cattle',
          color: Colors.green,
        ),
        const SizedBox(width: 8),
        _SummaryChip(
          icon: Icons.straighten,
          label: '${totalArea.toStringAsFixed(1)} ha',
          color: Colors.teal,
        ),
        if (breached > 0) ...[
          const SizedBox(width: 8),
          _SummaryChip(
            icon: Icons.warning_rounded,
            label: '$breached Breached',
            color: Colors.red,
          ),
        ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SummaryChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geofence Card
// ---------------------------------------------------------------------------

class _GeofenceCard extends StatelessWidget {
  final Geofence geofence;
  final HerdState herd;
  final bool isDark;
  const _GeofenceCard({
    required this.geofence,
    required this.herd,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isBreached = herd.isGeofenceBreached(geofence);
    final fenceColor = _hexToColor(geofence.color);
    final cattleNodes = herd.nodes.where((n) => geofence.nodeIds.contains(n.nodeId)).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBreached
              ? Colors.red.withValues(alpha: 0.5)
              : isDark
                  ? MooColors.borderDark
                  : MooColors.borderLight,
          width: isBreached ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          // Color strip + header
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: fenceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: fenceColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.fence_rounded, size: 18, color: fenceColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            geofence.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          if (geofence.description.isNotEmpty)
                            Text(
                              geofence.description,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    if (isBreached)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_rounded, size: 11, color: Colors.red),
                            SizedBox(width: 4),
                            Text('Breach', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  children: [
                    _Stat(
                      icon: Icons.pets,
                      label: '${geofence.nodeIds.length} cattle',
                    ),
                    const SizedBox(width: 16),
                    _Stat(
                      icon: Icons.straighten,
                      label: '${geofence.areaHectares.toStringAsFixed(1)} ha',
                    ),
                    const SizedBox(width: 16),
                    _Stat(
                      icon: Icons.local_florist_outlined,
                      label: _pastureLabel(geofence.pastureType),
                    ),
                    if (geofence.lastModified != null) ...[
                      const SizedBox(width: 16),
                      _Stat(
                        icon: Icons.update_rounded,
                        label: _timeAgo(geofence.lastModified!),
                      ),
                    ],
                  ],
                ),
                // Cattle avatars
                if (cattleNodes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cattleNodes.length > 8 ? 8 : cattleNodes.length,
                      itemBuilder: (ctx, i) {
                        if (i == 7 && cattleNodes.length > 8) {
                          return Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '+${cattleNodes.length - 7}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: NodeAvatar(node: cattleNodes[i], radius: 14),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _openOnMap(context),
                      icon: const Icon(Icons.map_outlined, size: 15),
                      label: const Text('View on Map', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => GeofencesPage._openEdit(context, geofence),
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Edit', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                      label: const Text('Delete', style: TextStyle(fontSize: 12, color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openOnMap(BuildContext context) {
    // Navigate to Map tab (index 1) via NavigationIndexProvider
    context.read<NavigationIndexProvider>().setIndex(1);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Geofence'),
        content: Text('Delete "${geofence.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final ok = await context.read<HerdState>().deleteGeofence(geofence.id);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<HerdState>().geofenceError ?? 'Delete failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) {
      return Color(int.parse('FF$h', radix: 16));
    }
    return MooColors.primary;
  }

  static String _pastureLabel(String type) {
    const map = {
      'meadow': 'Meadow',
      'cropland': 'Cropland',
      'forest': 'Forest',
      'water': 'Water access',
      'other': 'Other',
    };
    return map[type] ?? type;
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyGeofences extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyGeofences({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fence_rounded, size: 64, color: Colors.grey.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            const Text(
              'No Geofences',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Draw pasture boundaries to track where your cattle should be.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create First Geofence'),
              style: ElevatedButton.styleFrom(
                backgroundColor: MooColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
