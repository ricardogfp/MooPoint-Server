import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/pages/herd/animal_detail_page.dart';

class HerdPage extends StatefulWidget {
  const HerdPage({super.key});

  @override
  State<HerdPage> createState() => _HerdPageState();
}

class _HerdPageState extends State<HerdPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _HerdFilter _filter = _HerdFilter.all;
  _HerdSort _sort = _HerdSort.name;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<NodeModel> _applyFilter(List<NodeModel> nodes) {
    var result = nodes.where((n) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = n.getName().toLowerCase().contains(q);
        final matchId = n.nodeId.toString().contains(q);
        if (!matchName && !matchId) return false;
      }
      return true;
    }).toList();

    switch (_filter) {
      case _HerdFilter.attention:
        result = result
            .where((n) =>
                !n.isRecent || n.batteryLevel < 40 || n.hasVoltageFault)
            .toList();
        break;
      case _HerdFilter.lowBattery:
        result = result.where((n) => n.batteryLevel < 40).toList();
        break;
      case _HerdFilter.offline:
        result = result.where((n) => !n.isRecent).toList();
        break;
      case _HerdFilter.outsideFence:
        final herd = context.read<HerdState>();
        result = result
            .where((n) => herd.alerts
                .any((a) =>
                    a.nodeId == n.nodeId &&
                    !a.resolved &&
                    a.type.name == 'geofenceBreach'))
            .toList();
        break;
      case _HerdFilter.all:
        break;
    }

    switch (_sort) {
      case _HerdSort.name:
        result.sort((a, b) => a.getName().compareTo(b.getName()));
        break;
      case _HerdSort.battery:
        result.sort((a, b) => a.batteryLevel.compareTo(b.batteryLevel));
        break;
      case _HerdSort.lastSeen:
        result.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
        break;
      case _HerdSort.status:
        result.sort((a, b) =>
            a.overallStatus.compareTo(b.overallStatus));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdState>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final allNodes = herdState.nodes;

    if (herdState.nodesLoading && allNodes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final cattleNodes =
        allNodes.where((n) => n.nodeType == NodeType.cattle).toList();
    final filtered = _applyFilter(cattleNodes);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 300,
            child: _HerdSidebar(
              nodes: cattleNodes,
              herdState: herdState,
            ),
          ),
          Expanded(
            child: _HerdMain(
              filtered: filtered,
              allCount: cattleNodes.length,
              searchController: _searchController,
              filter: _filter,
              sort: _sort,
              onSearch: (q) => setState(() => _searchQuery = q),
              onFilter: (f) => setState(() => _filter = f),
              onSort: (s) => setState(() => _sort = s),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _HerdSummaryRow(nodes: cattleNodes, herdState: herdState),
        _SearchAndFilterBar(
          searchController: _searchController,
          filter: _filter,
          sort: _sort,
          onSearch: (q) => setState(() => _searchQuery = q),
          onFilter: (f) => setState(() => _filter = f),
          onSort: (s) => setState(() => _sort = s),
        ),
        Expanded(
          child: _AnimalGrid(nodes: filtered),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop sidebar (summary + attention list)
// ---------------------------------------------------------------------------

class _HerdSidebar extends StatelessWidget {
  final List<NodeModel> nodes;
  final HerdState herdState;

  const _HerdSidebar({required this.nodes, required this.herdState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        border: Border(
          right: BorderSide(
            color: isDark ? MooColors.borderDark : MooColors.borderLight,
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Herd',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _HerdSummaryCards(nodes: nodes, herdState: herdState),
          const SizedBox(height: 20),
          const Text(
            'NEEDS ATTENTION',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          _NeedsAttentionList(nodes: nodes, herdState: herdState),
        ],
      ),
    );
  }
}

class _HerdSummaryCards extends StatelessWidget {
  final List<NodeModel> nodes;
  final HerdState herdState;
  const _HerdSummaryCards({required this.nodes, required this.herdState});

  @override
  Widget build(BuildContext context) {
    final total = nodes.length;
    final active = nodes.where((n) => n.isRecent).length;
    final offline = nodes.where((n) => !n.isRecent).length;
    final lowBatt = nodes.where((n) => n.batteryLevel < 40).length;
    final alerts = herdState.alerts
        .where((a) => !a.resolved && a.nodeId != null)
        .length;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                  label: 'Total', value: '$total', color: MooColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                  label: 'Active',
                  value: '$active',
                  color: Colors.green),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                  label: 'Offline',
                  value: '$offline',
                  color: Colors.grey),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                  label: 'Low Batt',
                  value: '$lowBatt',
                  color: Colors.orange),
            ),
          ],
        ),
        if (alerts > 0) ...[
          const SizedBox(height: 8),
          _StatCard(
              label: 'Active Alerts',
              value: '$alerts',
              color: Colors.red,
              fullWidth: true),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: fullWidth
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.black45)),
          if (!fullWidth) const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

class _NeedsAttentionList extends StatelessWidget {
  final List<NodeModel> nodes;
  final HerdState herdState;
  const _NeedsAttentionList({required this.nodes, required this.herdState});

  @override
  Widget build(BuildContext context) {
    final attention = _prioritizeNodes(nodes, herdState);

    if (attention.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            SizedBox(width: 8),
            Text('All animals look healthy',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      children: attention
          .take(5)
          .map((item) => _AttentionItem(node: item.node, reason: item.reason))
          .toList(),
    );
  }

  List<_AttentionEntry> _prioritizeNodes(
      List<NodeModel> nodes, HerdState herd) {
    final entries = <_AttentionEntry>[];
    for (final n in nodes) {
      if (!n.isRecent) {
        entries.add(_AttentionEntry(
            node: n, reason: 'Offline', priority: 0));
      } else if (n.batteryLevel < 15) {
        entries.add(_AttentionEntry(
            node: n,
            reason: 'Critical battery (${n.batteryLevel}%)',
            priority: 1));
      } else if (herd.alerts.any((a) =>
          a.nodeId == n.nodeId &&
          !a.resolved &&
          a.type.name == 'geofenceBreach')) {
        entries.add(_AttentionEntry(
            node: n, reason: 'Outside geofence', priority: 1));
      } else if (n.batteryLevel < 40) {
        entries.add(_AttentionEntry(
            node: n,
            reason: 'Low battery (${n.batteryLevel}%)',
            priority: 2));
      }
    }
    entries.sort((a, b) => a.priority.compareTo(b.priority));
    return entries;
  }
}

class _AttentionEntry {
  final NodeModel node;
  final String reason;
  final int priority;
  _AttentionEntry(
      {required this.node, required this.reason, required this.priority});
}

class _AttentionItem extends StatelessWidget {
  final NodeModel node;
  final String reason;
  const _AttentionItem({required this.node, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => AnimalDetailPage(node: node)),
        ),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.orange.withValues(alpha: 0.3)),
            color: Colors.orange.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              NodeAvatar(node: node, radius: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.getName(),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    Text(reason,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row (mobile)
// ---------------------------------------------------------------------------

class _HerdSummaryRow extends StatelessWidget {
  final List<NodeModel> nodes;
  final HerdState herdState;
  const _HerdSummaryRow({required this.nodes, required this.herdState});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = nodes.length;
    final active = nodes.where((n) => n.isRecent).length;
    final offline = nodes.where((n) => !n.isRecent).length;
    final alerts = herdState.alerts
        .where((a) => !a.resolved && a.nodeId != null)
        .length;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
              color: isDark ? MooColors.borderDark : MooColors.borderLight),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MiniStat(label: 'Total', value: '$total', color: MooColors.primary),
            const SizedBox(width: 12),
            _MiniStat(label: 'Active', value: '$active', color: Colors.green),
            const SizedBox(width: 12),
            _MiniStat(label: 'Offline', value: '$offline', color: Colors.grey),
            if (alerts > 0) ...[
              const SizedBox(width: 12),
              _MiniStat(
                  label: 'Alerts', value: '$alerts', color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text('$value $label',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Main content area (filter + grid)
// ---------------------------------------------------------------------------

class _HerdMain extends StatelessWidget {
  final List<NodeModel> filtered;
  final int allCount;
  final TextEditingController searchController;
  final _HerdFilter filter;
  final _HerdSort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<_HerdFilter> onFilter;
  final ValueChanged<_HerdSort> onSort;

  const _HerdMain({
    required this.filtered,
    required this.allCount,
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.onSearch,
    required this.onFilter,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchAndFilterBar(
          searchController: searchController,
          filter: filter,
          sort: sort,
          onSearch: onSearch,
          onFilter: onFilter,
          onSort: onSort,
        ),
        Expanded(child: _AnimalGrid(nodes: filtered)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Search & Filter Bar
// ---------------------------------------------------------------------------

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final _HerdFilter filter;
  final _HerdSort sort;
  final ValueChanged<String> onSearch;
  final ValueChanged<_HerdFilter> onFilter;
  final ValueChanged<_HerdSort> onSort;

  const _SearchAndFilterBar({
    required this.searchController,
    required this.filter,
    required this.sort,
    required this.onSearch,
    required this.onFilter,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          // Search
          TextField(
            controller: searchController,
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: 'Search by name or ID...',
              hintStyle:
                  const TextStyle(fontSize: 13, color: Colors.grey),
              prefixIcon:
                  const Icon(Icons.search, size: 18, color: Colors.grey),
              filled: true,
              fillColor: isDark ? MooColors.bgDark : MooColors.bgLight,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          // Filters + sort
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._HerdFilter.values.map(
                  (f) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _FilterChip(
                      label: _filterLabel(f),
                      selected: filter == f,
                      onTap: () => onFilter(f),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.grey.withValues(alpha: 0.3),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                ),
                DropdownButton<_HerdSort>(
                  value: sort,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: _HerdSort.values
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(_sortLabel(s),
                                style: const TextStyle(fontSize: 12)),
                          ))
                      .toList(),
                  onChanged: (s) {
                    if (s != null) onSort(s);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _filterLabel(_HerdFilter f) {
    switch (f) {
      case _HerdFilter.all:
        return 'All';
      case _HerdFilter.attention:
        return 'Needs Attention';
      case _HerdFilter.lowBattery:
        return 'Low Battery';
      case _HerdFilter.offline:
        return 'Offline';
      case _HerdFilter.outsideFence:
        return 'Outside Fence';
    }
  }

  String _sortLabel(_HerdSort s) {
    switch (s) {
      case _HerdSort.name:
        return 'Sort: Name';
      case _HerdSort.battery:
        return 'Sort: Battery';
      case _HerdSort.lastSeen:
        return 'Sort: Last Seen';
      case _HerdSort.status:
        return 'Sort: Status';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? MooColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? MooColors.primary
                : Colors.grey.withValues(alpha: 0.4),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? MooColors.primary : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Animal Grid
// ---------------------------------------------------------------------------

class _AnimalGrid extends StatelessWidget {
  final List<NodeModel> nodes;
  const _AnimalGrid({required this.nodes});

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pets,
        title: 'No animals found',
        subtitle:
            'Try adjusting your search or filter, or add cattle nodes.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 200,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: nodes.length,
      itemBuilder: (ctx, i) => AnimalCard(node: nodes[i]),
    );
  }
}

// ---------------------------------------------------------------------------
// Animal Card (reusable)
// ---------------------------------------------------------------------------

class AnimalCard extends StatelessWidget {
  final NodeModel node;
  const AnimalCard({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final herd = context.read<HerdState>();
    final statusColor = _statusColor(node);
    final isOutsideFence = herd.alerts.any((a) =>
        a.nodeId == node.nodeId &&
        !a.resolved &&
        a.type.name == 'geofenceBreach');

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AnimalDetailPage(node: node)),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOutsideFence
                ? Colors.red.withValues(alpha: 0.5)
                : (isDark ? MooColors.borderDark : MooColors.borderLight),
            width: isOutsideFence ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NodeAvatar(node: node, radius: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.getName(),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${node.nodeId}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (isOutsideFence)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('OUT',
                        style: TextStyle(
                            fontSize: 9,
                            color: Colors.red,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Spacer(),

            // Status pill
            StatusPill(label: node.overallStatus, color: statusColor),
            const SizedBox(height: 6),

            // Battery bar
            Row(
              children: [
                Icon(
                  _battIcon(node.batteryLevel),
                  size: 13,
                  color: Color(node.batteryStatusColor),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: node.batteryLevel / 100,
                      backgroundColor:
                          Colors.grey.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Color(node.batteryStatusColor)),
                      minHeight: 5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text('${node.batteryLevel}%',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 6),

            // Last seen
            Text(
              _lastSeen(node.lastUpdated),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(NodeModel n) {
    if (!n.isRecent) return Colors.grey;
    if (n.batteryLevel < 20 || n.hasVoltageFault) return Colors.red;
    if (n.batteryLevel < 40) return Colors.orange;
    return Colors.green;
  }

  IconData _battIcon(int level) {
    if (level < 15) return Icons.battery_0_bar;
    if (level < 40) return Icons.battery_2_bar;
    if (level < 70) return Icons.battery_5_bar;
    return Icons.battery_full;
  }

  String _lastSeen(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum _HerdFilter { all, attention, lowBattery, offline, outsideFence }

enum _HerdSort { name, battery, lastSeen, status }
