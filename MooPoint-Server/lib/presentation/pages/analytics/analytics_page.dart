import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/presentation/widgets/charts/behavior_chart_widget.dart';
import 'package:moo_point/presentation/widgets/charts/voltage_chart_widget.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedNodeId = -1;
  int _timeRangeHours = 168; // 7 days default

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final herdState = context.watch<HerdState>();
    final cattleNodes = herdState.nodes
        .where((n) => n.nodeType == NodeType.cattle)
        .toList();

    if (_selectedNodeId == -1 && cattleNodes.isNotEmpty) {
      _selectedNodeId = cattleNodes.first.nodeId;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Header
          Container(
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
                const Icon(Icons.bar_chart_rounded, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Analytics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 168, label: Text('7d')),
                    ButtonSegment(value: 720, label: Text('30d')),
                  ],
                  selected: {_timeRangeHours},
                  onSelectionChanged: (s) =>
                      setState(() => _timeRangeHours = s.first),
                  style: SegmentedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Behavior Trends'),
              Tab(text: 'Herd Overview'),
              Tab(text: 'Pasture Utilization'),
            ],
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BehaviorTrendsTab(
                  cattleNodes: cattleNodes,
                  selectedNodeId: _selectedNodeId,
                  timeRangeHours: _timeRangeHours,
                  onNodeChanged: (id) => setState(() => _selectedNodeId = id),
                ),
                _HerdOverviewTab(nodes: cattleNodes),
                _PastureTab(timeRangeHours: _timeRangeHours),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Behavior Trends
// ---------------------------------------------------------------------------

class _BehaviorTrendsTab extends StatelessWidget {
  final List<NodeModel> cattleNodes;
  final int selectedNodeId;
  final int timeRangeHours;
  final ValueChanged<int> onNodeChanged;

  const _BehaviorTrendsTab({
    required this.cattleNodes,
    required this.selectedNodeId,
    required this.timeRangeHours,
    required this.onNodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdState>();

    if (cattleNodes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pets,
        title: 'No Cattle Nodes',
        subtitle: 'Add cattle tracking nodes to view behavior trends.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Node selector
        _AnalyticsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Animal',
                  style:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: selectedNodeId,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                items: cattleNodes
                    .map((n) => DropdownMenuItem(
                          value: n.nodeId,
                          child: Text(n.getName(),
                              style: const TextStyle(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) onNodeChanged(v);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Behavior chart — BehaviorChartWidget handles its own fetching
        if (selectedNodeId != -1) ...[
          _AnalyticsCard(
            title: 'Behavior Timeline (24h)',
            child: BehaviorChartWidget(nodeId: selectedNodeId),
          ),
          const SizedBox(height: 12),

          // Health Summary
          _AnalyticsCard(
            title: 'Health Summary',
            child: FutureBuilder<BehaviorSummary?>(
              future:
                  herdState.getBehaviorSummaryForNode(selectedNodeId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final summary = snap.data;
                if (summary == null) {
                  return const Text('No summary available',
                      style:
                          TextStyle(color: Colors.grey, fontSize: 13));
                }
                return Column(
                  children: [
                    _SummaryRow(
                        label: 'Health Status',
                        value: summary.healthStatus),
                    _SummaryRow(
                        label: 'Ruminating',
                        value:
                            '${summary.ruminatingHours.toStringAsFixed(1)}h / day'),
                    _SummaryRow(
                        label: 'Grazing',
                        value:
                            '${summary.grazingHours.toStringAsFixed(1)}h / day'),
                    _SummaryRow(
                        label: 'Resting',
                        value:
                            '${summary.restingHours.toStringAsFixed(1)}h / day'),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Herd Overview
// ---------------------------------------------------------------------------

class _HerdOverviewTab extends StatelessWidget {
  final List<NodeModel> nodes;

  const _HerdOverviewTab({required this.nodes});

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdState>();
    final fenceNodes = herdState.nodes
        .where((n) => n.nodeType == NodeType.fence)
        .toList();

    if (nodes.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.pets,
        title: 'No Cattle Nodes',
        subtitle: 'Add cattle tracking nodes to see herd overview.',
      );
    }

    int grazing = 0, resting = 0, moving = 0, ruminating = 0, unknown = 0;
    for (final n in nodes) {
      switch (n.overallStatus.toLowerCase()) {
        case 'grazing':
          grazing++;
          break;
        case 'resting':
          resting++;
          break;
        case 'moving':
          moving++;
          break;
        case 'ruminating':
          ruminating++;
          break;
        default:
          unknown++;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AnalyticsCard(
          title: 'Current Behavior Distribution',
          child: Column(
            children: [
              _BehaviorBar(
                  label: 'Grazing',
                  count: grazing,
                  total: nodes.length,
                  color: Colors.green),
              const SizedBox(height: 8),
              _BehaviorBar(
                  label: 'Resting',
                  count: resting,
                  total: nodes.length,
                  color: Colors.blue),
              const SizedBox(height: 8),
              _BehaviorBar(
                  label: 'Moving',
                  count: moving,
                  total: nodes.length,
                  color: Colors.orange),
              const SizedBox(height: 8),
              _BehaviorBar(
                  label: 'Ruminating',
                  count: ruminating,
                  total: nodes.length,
                  color: Colors.purple),
              if (unknown > 0) ...[
                const SizedBox(height: 8),
                _BehaviorBar(
                    label: 'Unknown',
                    count: unknown,
                    total: nodes.length,
                    color: Colors.grey),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Health anomalies
        _AnalyticsCard(
          title: 'Health Anomalies',
          child: FutureBuilder<List<_NodeAnomaly>>(
            future: _findAnomalies(herdState, nodes),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()));
              }
              final anomalies = snap.data ?? [];
              if (anomalies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('No health anomalies detected',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                );
              }
              return Column(
                children: anomalies
                    .map((a) => _AnomalyRow(anomaly: a))
                    .toList(),
              );
            },
          ),
        ),

        if (fenceNodes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AnalyticsCard(
            title: 'Fence Voltage',
            child: VoltageChartWidget(nodeId: fenceNodes.first.nodeId),
          ),
        ],
      ],
    );
  }

  Future<List<_NodeAnomaly>> _findAnomalies(
      HerdState state, List<NodeModel> nodes) async {
    final anomalies = <_NodeAnomaly>[];
    for (final node in nodes) {
      if (!node.isRecent) {
        anomalies.add(_NodeAnomaly(
            node: node,
            reason: 'Node offline',
            severity: _AnomalySeverity.critical));
      } else if (node.batteryLevel < 15) {
        anomalies.add(_NodeAnomaly(
            node: node,
            reason: 'Critical battery (${node.batteryLevel}%)',
            severity: _AnomalySeverity.critical));
      } else if (node.batteryLevel < 40) {
        anomalies.add(_NodeAnomaly(
            node: node,
            reason: 'Low battery (${node.batteryLevel}%)',
            severity: _AnomalySeverity.warning));
      } else {
        final summary =
            await state.getBehaviorSummaryForNode(node.nodeId);
        if (summary != null && summary.ruminatingHours < 4) {
          anomalies.add(_NodeAnomaly(
              node: node,
              reason:
                  'Low rumination (${summary.ruminatingHours.toStringAsFixed(1)}h)',
              severity: _AnomalySeverity.warning));
        }
      }
    }
    return anomalies;
  }
}

enum _AnomalySeverity { critical, warning }

class _NodeAnomaly {
  final NodeModel node;
  final String reason;
  final _AnomalySeverity severity;
  _NodeAnomaly(
      {required this.node, required this.reason, required this.severity});
}

class _AnomalyRow extends StatelessWidget {
  final _NodeAnomaly anomaly;
  const _AnomalyRow({required this.anomaly});

  @override
  Widget build(BuildContext context) {
    final color = anomaly.severity == _AnomalySeverity.critical
        ? Colors.red
        : Colors.orange;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(anomaly.node.getName(),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Text(anomaly.reason,
              style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}

class _BehaviorBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _BehaviorBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? count / total : 0.0;
    return Row(
      children: [
        SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '$count / $total',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Pasture Utilization
// ---------------------------------------------------------------------------

class _PastureTab extends StatefulWidget {
  final int timeRangeHours;
  const _PastureTab({required this.timeRangeHours});

  @override
  State<_PastureTab> createState() => _PastureTabState();
}

class _PastureTabState extends State<_PastureTab> {
  final _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final herdState = context.watch<HerdState>();
    final heatData =
        herdState.positionHeatmap?.toWeightedLatLng() ?? const <WeightedLatLng>[];
    final nodes = herdState.nodes;
    final center = nodes.isNotEmpty
        ? LatLng(nodes.first.latitude, nodes.first.longitude)
        : const LatLng(-33.0, -71.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Position density — last ${widget.timeRangeHours == 168 ? '7 days' : '30 days'}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  ),
                  if (heatData.isNotEmpty)
                    HeatMapLayer(
                      heatMapDataSource:
                          InMemoryHeatMapDataSource(data: heatData),
                      heatMapOptions: HeatMapOptions(
                        gradient: HeatMapOptions.defaultGradient,
                        minOpacity: 0.3,
                        radius: 40,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (heatData.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              'No position data yet. Data appears as nodes report locations.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _AnalyticsCard extends StatelessWidget {
  final String? title;
  final Widget child;

  const _AnalyticsCard({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? MooColors.borderDark : MooColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}
