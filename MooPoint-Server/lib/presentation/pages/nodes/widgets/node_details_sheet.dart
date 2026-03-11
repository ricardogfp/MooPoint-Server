import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/widgets/charts/behavior_chart_widget.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/data/models/position_heatmap_model.dart';
import 'package:moo_point/presentation/pages/nodes/node_history_page.dart';
import 'package:moo_point/presentation/pages/map/compass_tracker_page.dart';
import 'package:moo_point/presentation/pages/events/geofence_events_page.dart';
import 'package:moo_point/presentation/widgets/charts/voltage_chart_widget.dart';

class NodeDetailsSheet extends StatefulWidget {
  final NodeModel node;

  const NodeDetailsSheet({super.key, required this.node});

  @override
  State<NodeDetailsSheet> createState() => _NodeDetailsSheetState();
}

class _NodeDetailsSheetState extends State<NodeDetailsSheet>
    with SingleTickerProviderStateMixin {
  late NodeModel _node;
  late TabController _tabController;
  final _backend = NodeBackendService();

  bool get _isBleLocateSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _node = widget.node;
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNodeData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backend.dispose();
    super.dispose();
  }

  Future<void> _refreshNodeData() async {
    try {
      final updatedNode = await _backend.getNodeById(_node.nodeId);
      if (updatedNode != null && mounted) {
        setState(() => _node = updatedNode);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _node.photoUrl != null && _node.photoUrl!.isNotEmpty
                        ? CircleAvatar(
                            radius: 26,
                            backgroundImage: NetworkImage(_node.photoUrl!),
                            backgroundColor: Color(_node.statusColor),
                            onBackgroundImageError: (error, stackTrace) {
                              debugPrint(
                                  'Error loading photo for node ${_node.nodeId} from ${_node.photoUrl}: $error');
                            },
                          )
                        : CircleAvatar(
                            backgroundColor: Color(_node.statusColor),
                            radius: 26,
                            child: Icon(
                              _node.nodeType == NodeType.fence
                                  ? Icons.bolt
                                  : MdiIcons.cow,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_node.name,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                          Text('Node ${_node.nodeId}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                    StatusPill.fromStatus(_node.overallStatus),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Quick-action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (_isBleLocateSupported)
                      _QuickAction(
                        icon: Icons.explore,
                        label: 'Locate',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CompassTrackerPage(
                                initialNodeId: _node.nodeId,
                                autoRequestLocate: true,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Tabs
              TabBar(
                controller: _tabController,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                tabs: _node.nodeType == NodeType.fence
                    ? [
                        const Tab(text: 'Overview'),
                        const Tab(text: 'Voltage'),
                        const Tab(text: 'Events'),
                      ]
                    : [
                        const Tab(text: 'Overview'),
                        const Tab(text: 'Behavior'),
                        const Tab(text: 'Location'),
                      ],
              ),
              // Tab content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _node.nodeType == NodeType.fence
                      ? [
                          _OverviewTab(
                            node: _node,
                            scrollController: scrollController,
                          ),
                          VoltageChartWidget(nodeId: _node.nodeId),
                          _FenceEventsTab(node: _node),
                        ]
                      : [
                          _OverviewTab(
                            node: _node,
                            scrollController: scrollController,
                          ),
                          BehaviorChartWidget(nodeId: _node.nodeId),
                          _LocationTab(node: _node),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-action button
// ---------------------------------------------------------------------------
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      MooColors.primary.withOpacity(0.15),
                      MooColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: MooColors.primary.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: MooColors.primary, size: 22),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview tab — battery, status, last seen
// ---------------------------------------------------------------------------
class _OverviewTab extends StatelessWidget {
  final NodeModel node;
  final ScrollController scrollController;

  const _OverviewTab({required this.node, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          if (node.nodeType == NodeType.fence && node.voltage != null) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: node.hasVoltageFault
                      ? [Colors.red.shade400, Colors.red.shade700]
                      : [MooColors.primary, MooColors.secondary],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (node.hasVoltageFault ? Colors.red : MooColors.primary)
                            .withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Pasture Pulse',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Icon(
                        node.hasVoltageFault
                            ? Icons.warning_amber_rounded
                            : Icons.bolt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        ((node.voltage ?? 0) / 1000).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'kV',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    node.hasVoltageFault
                        ? 'VOLTAGE FAULT DETECTED'
                        : 'System nominal',
                    style: TextStyle(
                      color:
                          node.hasVoltageFault ? Colors.white : Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Battery card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: node.batteryLevel / 100.0,
                          strokeWidth: 6,
                          backgroundColor: Colors.grey.shade100,
                          color: Color(node.batteryStatusColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Text(
                        '${node.batteryLevel}%',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Battery Level',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          node.batteryStatus,
                          style: TextStyle(
                            color: Color(node.batteryStatusColor),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last reported ${DateFormat('HH:mm').format(node.lastUpdated)}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Signal Strength / Last Update
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.history,
                            color: MooColors.primary, size: 24),
                        const SizedBox(height: 8),
                        const Text('Last Update',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          _relativeTime(node.lastUpdated),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Icon(Icons.cell_tower,
                            color: MooColors.accent, size: 24),
                        const SizedBox(height: 8),
                        const Text('Signal',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey)),
                        const SizedBox(height: 4),
                        const Text(
                          'Strong', // TODO: Add signal data to model
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Node photo card
          if (node.photoUrl != null && node.photoUrl!.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Surroundings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: node.photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: Icon(Icons.broken_image,
                          size: 48, color: Colors.grey[400])),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Details List
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: MooColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text('System Details',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SummaryRow(label: 'Node ID', value: '${node.nodeId}'),
                  _SummaryRow(
                      label: 'Type', value: node.nodeType.name.toUpperCase()),
                  if (node.nodeType == NodeType.cattle) ...[
                    if (node.breed != null)
                      _SummaryRow(label: 'Breed', value: node.breed!),
                    if (node.age != null)
                      _SummaryRow(label: 'Age', value: '${node.age} years'),
                  ],
                  const Divider(height: 32),
                  const Text('COMMENTS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                          letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(
                    node.comments?.isNotEmpty == true
                        ? node.comments!
                        : 'No additional comments provided.',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
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
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey[600])),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Location tab — coordinates + map actions
// ---------------------------------------------------------------------------
class _LocationTab extends StatelessWidget {
  final NodeModel node;
  const _LocationTab({required this.node});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomPadding),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined,
                          color: MooColors.primary, size: 22),
                      const SizedBox(width: 8),
                      const Text('Location Actions',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NodeHistoryPage(node: node)),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text('Position History'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => SizedBox(
                            height: MediaQuery.of(context).size.height * 0.8,
                            child: _HeatMapTab(node: node),
                          ),
                        );
                      },
                      icon: const Icon(Icons.layers_outlined),
                      label: const Text('Heatmap'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                GeofenceEventsPage(nodeId: node.nodeId)),
                      ),
                      icon: const Icon(Icons.fence),
                      label: const Text('Geofence Events'),
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

// ---------------------------------------------------------------------------
// Heat Map Tab - Shows position heat map for individual node
// ---------------------------------------------------------------------------
class _HeatMapTab extends StatefulWidget {
  final NodeModel node;

  const _HeatMapTab({required this.node});

  @override
  State<_HeatMapTab> createState() => _HeatMapTabState();
}

class _HeatMapTabState extends State<_HeatMapTab> {
  PositionHeatmapData? _heatmap;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHeatmap();
  }

  Future<void> _loadHeatmap() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await NodeBackendService().getNodeHistory(
        widget.node.nodeId,
        hours: 24,
        everyMinutes: 5,
      );
      final data = PositionHeatmapData.fromHistory(history);
      if (mounted) {
        setState(() {
          _heatmap = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading position data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadHeatmap,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_heatmap == null || _heatmap!.points.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No position data available'),
            const SizedBox(height: 8),
            Text(
              'This tracker has not reported any positions in the last 24 hours',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Calculate bounds from heat map points for auto-center and auto-zoom
    final points = _heatmap!.points.map((p) => p.latLng).toList();

    // Find min/max lat/lon
    final minLat =
        points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat =
        points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLon =
        points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLon =
        points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    // Calculate center
    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;

    // Calculate appropriate zoom based on bounds size
    final latDelta = maxLat - minLat;
    final lonDelta = maxLon - minLon;
    final maxDelta = latDelta > lonDelta ? latDelta : lonDelta;

    // Convert delta to approximate zoom level
    // zoom = log2(360/delta) - 1 (rough approximation)
    double zoom = 15;
    if (maxDelta > 0) {
      zoom = 16 - (maxDelta / 0.01).clamp(0, 10);
    }
    zoom = zoom.clamp(10, 18);

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(centerLat, centerLon),
                  initialZoom: zoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.node_tracker',
                  ),
                  HeatMapLayer(
                    heatMapDataSource: InMemoryHeatMapDataSource(
                      data: _heatmap!.points
                          .map((point) =>
                              WeightedLatLng(point.latLng, point.weight))
                          .toList(),
                    ),
                    heatMapOptions: HeatMapOptions(
                      radius: 50,
                      minOpacity: 0.3,
                      gradient: {
                        0.0: Colors.blue,
                        0.3: Colors.cyan,
                        0.5: Colors.green,
                        0.7: Colors.yellow,
                        1.0: Colors.orange,
                      },
                    ),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point:
                            LatLng(widget.node.latitude, widget.node.longitude),
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on,
                            color: Colors.red, size: 40),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activity Heat Map',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        _legendItem(Colors.orange, 'High Activity'),
                        _legendItem(Colors.green, 'Medium Activity'),
                        _legendItem(Colors.blue, 'Low Activity'),
                        const SizedBox(height: 4),
                        _legendItem(Colors.red, 'Current Position'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 9)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fence Events tab
// ---------------------------------------------------------------------------
class _FenceEventsTab extends StatelessWidget {
  final NodeModel node;
  const _FenceEventsTab({required this.node});

  @override
  Widget build(BuildContext context) {
    return GeofenceEventsPage(nodeId: node.nodeId);
  }
}
