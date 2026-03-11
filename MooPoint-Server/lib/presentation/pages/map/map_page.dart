import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/pages/nodes/node_placement_page.dart';
import 'package:moo_point/l10n/l10n_helper.dart';

import 'widgets/map_detail_panel.dart';
import 'widgets/map_detail_sheet.dart';
import 'widgets/map_config_drawer.dart';

enum HeatMapMode {
  off,
  coverage,
  position,
  history,
}

enum MapViewState {
  defaultView,
  cattleSelected,
  fenceSelected,
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => MapPageState();
}

class MapPageState extends State<MapPage>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  final LatLng _spainCenter = const LatLng(40.4637, -3.7492);

  // Interaction Model State
  MapViewState _viewState = MapViewState.defaultView;
  NodeModel? _selectedNode;
  bool _showConfigDrawer = false;
  bool _isSheetExpanded = false; // For mobile bottom sheet
  bool _sheetCollapsed = false; // Mobile pill mode (history/heatmap active)

  // Overlays & Toggles
  HeatMapMode _heatMapMode = HeatMapMode.off;
  String _heatMapTimeRange = '24h';
  double _playbackProgress = 0.0;
  List<LatLng> _historyPoints = [];

  // Auto-refresh timer
  Timer? _refreshTimer;
  bool _hasFittedNodes = false;

  @override
  void initState() {
    super.initState();
    _startRefreshTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_heatMapMode == HeatMapMode.off ||
          _heatMapMode == HeatMapMode.position) {
        context.read<HerdState>().loadNodesAndGeofences();
      }
    });
  }

  @override
  bool get wantKeepAlive => true;

  void _fitAllNodes(List<NodeModel> nodes) {
    final positioned = nodes.where((n) => n.latitude != 0.0 || n.longitude != 0.0).toList();
    if (positioned.isEmpty) return;
    if (positioned.length == 1) {
      _mapController.move(LatLng(positioned.first.latitude, positioned.first.longitude), 14);
      return;
    }
    final bounds = LatLngBounds.fromPoints(
      positioned.map((n) => LatLng(n.latitude, n.longitude)).toList(),
    );
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(80),
      ),
    );
  }

  void selectNode(NodeModel? node) {
    _selectNode(node);
  }

  void _selectNode(NodeModel? node) {
    if (node == null) {
      setState(() {
        _viewState = MapViewState.defaultView;
        _selectedNode = null;
        _showConfigDrawer = false;
        _isSheetExpanded = false;
        _sheetCollapsed = false;
        _heatMapMode = HeatMapMode.off;
      });
      return;
    }

    setState(() {
      _selectedNode = node;
      _showConfigDrawer = false;
      _isSheetExpanded = false; // Reset to collapsed when selecting new
      _sheetCollapsed = false;
      if (node.nodeType == NodeType.cattle) {
        _viewState = MapViewState.cattleSelected;
        _heatMapMode = HeatMapMode.off;
      } else {
        _viewState = MapViewState.fenceSelected;
        _heatMapMode = HeatMapMode.off;
      }
    });

    _mapController.move(LatLng(node.latitude, node.longitude), 15);
  }

  void _onMarkerTap(NodeModel node) {
    _selectNode(node);
  }

  bool _shouldShowMarker(NodeModel node) {
    // Don't show markers for nodes without a known position (unplaced fence
    // nodes or trackers that haven't reported GPS yet — lat/lon = 0.0).
    if (node.latitude == 0.0 && node.longitude == 0.0) return false;
    if (_heatMapMode == HeatMapMode.position ||
        _heatMapMode == HeatMapMode.coverage) {
      return false;
    }
    if (_viewState == MapViewState.defaultView) return true;
    return node.nodeId == _selectedNode?.nodeId;
  }

  double _markerOpacity(NodeModel node) {
    if (_viewState == MapViewState.defaultView) return 1.0;
    return node.nodeId == _selectedNode?.nodeId ? 1.0 : 0.2;
  }

  void _reloadHeatMapData() {
    if (_heatMapMode == HeatMapMode.coverage) {
      context.read<HerdState>().loadCoverageData(timeRange: _heatMapTimeRange);
    } else if (_heatMapMode == HeatMapMode.position) {
      _reloadPositionHeatmap();
    } else if (_heatMapMode == HeatMapMode.history && _selectedNode != null) {
      _loadNodeHistory(_selectedNode!.nodeId);
    }
  }

  Future<void> _loadNodeHistory(int nodeId) async {
    try {
      final hours = _heatMapTimeRange == '6h'
          ? 6
          : _heatMapTimeRange == '12h'
              ? 12
              : _heatMapTimeRange == '24h'
                  ? 24
                  : 168;
      final history = await context.read<HerdState>().getNodeHistory(
            nodeId,
            hours: hours,
            everyMinutes: 5,
          );
      setState(() {
        _historyPoints = history.map((p) => LatLng(p.lat, p.lon)).toList();
      });
    } catch (e) {
      debugPrint('Error loading node history: $e');
    }
  }

  Color _markerColor(NodeModel node) {
    if (!node.isRecent) return Colors.grey;
    if (node.batteryLevel < 20) return Colors.red;
    if (node.nodeType == NodeType.fence &&
        node.voltage != null &&
        node.voltage! < 4000) {
      return Colors.red;
    }
    if (node.batteryLevel < 40) return Colors.orange;
    return Colors.green;
  }

  void _reloadPositionHeatmap() {
    final hours = _heatMapTimeRange == '6h'
        ? 6
        : _heatMapTimeRange == '12h'
            ? 12
            : _heatMapTimeRange == '24h'
                ? 24
                : 168; // 7 days
    context.read<HerdState>().loadPositionHeatmap(hours: hours);
  }

  Marker _createNodeMarker(NodeModel node) {
    final isFence = node.nodeType == NodeType.fence;
    final icon = isFence ? Icons.flash_on : MdiIcons.cow;
    final color = _markerColor(node);
    final opacity = _markerOpacity(node);

    return Marker(
      point: LatLng(node.latitude, node.longitude),
      width: 60,
      height: 70,
      child: Opacity(
        opacity: opacity,
        child: GestureDetector(
          onTap: () => _onMarkerTap(node),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!node.isRecent)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: MooColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(Icons.access_time,
                      size: 10, color: Colors.white),
                ),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                node.getName().toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final herdState = context.watch<HerdState>();
    final nodes = herdState.nodes;
    final isMobile = MediaQuery.of(context).size.width < 900;

    // Auto-fit all nodes once when first loaded
    if (!_hasFittedNodes && nodes.isNotEmpty) {
      _hasFittedNodes = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllNodes(nodes));
    }

    // Handle pending map selection from other pages (e.g., AnimalDetailPage)
    final pending = herdState.pendingMapSelection;
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && herdState.pendingMapSelection != null) {
          herdState.clearPendingMapSelection();
          _selectNode(pending);
        }
      });
    }

    return Stack(
      children: [
        // Map LAYER
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: nodes.any((n) => n.latitude != 0.0 || n.longitude != 0.0)
                ? LatLng(nodes.firstWhere((n) => n.latitude != 0.0 || n.longitude != 0.0).latitude,
                         nodes.firstWhere((n) => n.latitude != 0.0 || n.longitude != 0.0).longitude)
                : _spainCenter,
            initialZoom: 7,
            onTap: (_, __) => _selectNode(null), // Close overlay on map tap
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.moopoint.app',
            ),
            PolygonLayer(
              polygons: herdState.geofences
                  .map((g) => Polygon(
                        points: g.points,
                        color: Color(int.parse(g.color.replaceAll('#', '0xFF')))
                            .withValues(alpha: 0.3),
                        borderColor:
                            Color(int.parse(g.color.replaceAll('#', '0xFF'))),
                        borderStrokeWidth: 2,
                      ))
                  .toList(),
            ),
            if (_heatMapMode == HeatMapMode.position && herdState.positionHeatmap != null)
              HeatMapLayer(
                heatMapDataSource: InMemoryHeatMapDataSource(
                    data: herdState.positionHeatmap!.toWeightedLatLng()),
                heatMapOptions: HeatMapOptions(radius: 30.0),
              ),
            if (_heatMapMode == HeatMapMode.coverage && herdState.coverageData != null)
              HeatMapLayer(
                heatMapDataSource: InMemoryHeatMapDataSource(
                    data: herdState.coverageData!.toWeightedLatLng()),
                heatMapOptions: HeatMapOptions(radius: 40.0),
              ),
            if (_heatMapMode == HeatMapMode.history &&
                _historyPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _historyPoints,
                    strokeWidth: 3,
                    color: MooColors.primary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            MarkerLayer(
              markers: nodes.where(_shouldShowMarker).map((node) {
                if (_heatMapMode == HeatMapMode.history &&
                    node.nodeId == _selectedNode?.nodeId &&
                    _historyPoints.isNotEmpty) {
                  final index =
                      (_playbackProgress * (_historyPoints.length - 1)).toInt();
                  return _createNodeMarker(node.copyWith(
                    latitude: _historyPoints[index].latitude,
                    longitude: _historyPoints[index].longitude,
                  ));
                }
                return _createNodeMarker(node);
              }).toList(),
            ),
          ],
        ),

        // OVERLAYS
        if (_viewState != MapViewState.fenceSelected)
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: _ViewTogglePill(
                state: _viewState,
                currentMode: _heatMapMode,
                onModeChanged: (mode) {
                  setState(() {
                    _heatMapMode = mode;
                    // Collapse sheet to pill on mobile when entering a heatmap mode
                    if (isMobile && _selectedNode != null) {
                      _sheetCollapsed = mode != HeatMapMode.off;
                    }
                  });
                  if (mode != HeatMapMode.off) {
                    _reloadHeatMapData();
                  }
                },
                  ),
                ),
              ),
            ),
          ),

        if (_heatMapMode == HeatMapMode.coverage ||
            _heatMapMode == HeatMapMode.position)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: _TimeRangeSelector(
                currentValue: _heatMapTimeRange,
                onChanged: (val) {
                  setState(() => _heatMapTimeRange = val);
                  _reloadHeatMapData();
                },
              ),
            ),
          ),

        if (_viewState == MapViewState.cattleSelected &&
            _heatMapMode == HeatMapMode.history)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: isMobile ? (_isSheetExpanded ? 300 : 100) : 0, // Adjust above bottom sheet
            left: 0,
            right: isMobile ? 0 : (_showConfigDrawer ? 400.0 : 384.0),
            child: _PlaybackBar(
              progress: _playbackProgress,
              onSeek: (v) => setState(() => _playbackProgress = v),
            ),
          ),

        // Heatmap legend card — position heatmap mode only
        if (_heatMapMode == HeatMapMode.position)
          Positioned(
            bottom: 16,
            left: 16,
            right: isMobile
                ? 16
                : (_viewState != MapViewState.defaultView
                    ? (_showConfigDrawer ? 436.0 : 400.0)
                    : 16),
            child: _HeatmapLegendCard(
              heatmapData: herdState.positionHeatmap,
            ),
          ),

        // Coverage legend card — coverage heatmap mode only
        if (_heatMapMode == HeatMapMode.coverage)
          Positioned(
            bottom: 16,
            left: 16,
            right: isMobile
                ? 16
                : (_viewState != MapViewState.defaultView
                    ? (_showConfigDrawer ? 436.0 : 400.0)
                    : 16),
            child: const _CoverageLegendCard(),
          ),

        // Fit-all-nodes button — top-right corner
        Positioned(
          top: 20,
          right: isMobile
              ? 16
              : ((_viewState == MapViewState.cattleSelected ||
                          _viewState == MapViewState.fenceSelected)
                      ? (_showConfigDrawer ? 440.0 : 404.0)
                      : 16),
          child: GestureDetector(
            onTap: () => _fitAllNodes(nodes),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.fit_screen_rounded,
                  color: Colors.white70, size: 22),
            ),
          ),
        ),

        // Desktop Detail Panel
        if (!isMobile)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: (_viewState == MapViewState.cattleSelected ||
                    _viewState == MapViewState.fenceSelected)
                ? 0
                : -400,
            child: _selectedNode != null
                ? MapDetailPanel(
                    state: _viewState,
                    node: _selectedNode!,
                    onClose: () => _selectNode(null),
                    onOpenConfig: () => setState(() => _showConfigDrawer = true),
                  )
                : const SizedBox.shrink(),
          ),

        // Config Drawer
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          bottom: 0,
          right: _showConfigDrawer ? 0 : -420,
          child: _selectedNode != null
              ? MapConfigDrawer(
                  node: _selectedNode!,
                  onClose: () => setState(() => _showConfigDrawer = false),
                )
              : const SizedBox.shrink(),
        ),

        // Mobile Detail Sheet or Control Pill
        if (isMobile && _selectedNode != null)
          if (_sheetCollapsed)
            // Control pill — floats top-left when history/heatmap mode is active
            Positioned(
              top: 76,
              left: 16,
              right: 16,
              child: _NodeInfoPill(
                node: _selectedNode!,
                modeLabel: _heatMapMode == HeatMapMode.history
                    ? 'Position History · $_heatMapTimeRange'
                    : _heatMapMode == HeatMapMode.position
                        ? 'Position Heatmap · $_heatMapTimeRange'
                        : 'Coverage · $_heatMapTimeRange',
                onExpand: () => setState(() => _sheetCollapsed = false),
              ),
            )
          else
            AnimatedSlide(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCirc,
              offset: Offset.zero,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: MapDetailSheet(
                    state: _viewState,
                    node: _selectedNode!,
                    isExpanded: _isSheetExpanded,
                    onToggleExpand: () =>
                        setState(() => _isSheetExpanded = !_isSheetExpanded),
                    onOpenConfig: () =>
                        setState(() => _showConfigDrawer = true),
                  ),
                ),
              ),
            ),

        // Uninitialized fence node banner — bottom of map
        if (herdState.newNodesRequiringPlacement.isNotEmpty)
          Positioned(
            bottom: isMobile
                ? (_selectedNode != null ? 240 : 16)
                : 16,
            left: 16,
            right: isMobile
                ? 16
                : (_viewState != MapViewState.defaultView ? 416 : 16),
            child: _FenceNodeBanner(
              nodes: herdState.newNodesRequiringPlacement,
            ),
          ),
      ],
    );
  }
}

/// Banner shown on the map when there are unplaced fence nodes.
class _FenceNodeBanner extends StatelessWidget {
  final List<NodeModel> nodes;
  const _FenceNodeBanner({required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MooColors.fenceBrown.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            const Icon(Icons.fence_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                nodes.length == 1
                    ? '"${nodes.first.getName()}" needs a map position'
                    : '${nodes.length} fence nodes need map positions',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NodePlacementPage(newNodes: nodes),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Place Now',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewTogglePill extends StatelessWidget {
  final MapViewState state;
  final HeatMapMode currentMode;
  final Function(HeatMapMode) onModeChanged;

  const _ViewTogglePill({
    required this.state,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    List<({HeatMapMode mode, String label})> options;
    if (state == MapViewState.cattleSelected) {
      options = [
        (mode: HeatMapMode.off, label: l10n.liveView),
        (mode: HeatMapMode.history, label: l10n.positionHistory),
        (mode: HeatMapMode.position, label: l10n.positionHeatmap),
      ];
    } else if (state == MapViewState.defaultView) {
      options = [
        (mode: HeatMapMode.off, label: l10n.liveView),
        (mode: HeatMapMode.position, label: l10n.positionHeatmap),
        (mode: HeatMapMode.coverage, label: l10n.coverageView),
      ];
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = currentMode == opt.mode;
          return GestureDetector(
            onTap: () => onModeChanged(opt.mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? MooColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                opt.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimeRangeSelector extends StatelessWidget {
  final String currentValue;
  final Function(String) onChanged;

  const _TimeRangeSelector({
    required this.currentValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = ['6h', '12h', '24h', '48h'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, color: Colors.white70, size: 16),
          const SizedBox(width: 8),
          ...ranges.map((r) {
            final isSelected = currentValue == r;
            return GestureDetector(
              onTap: () => onChanged(r),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  r,
                  style: TextStyle(
                    color: isSelected ? MooColors.primary : Colors.white60,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PlaybackBar extends StatelessWidget {
  final double progress;
  final Function(double) onSeek;

  const _PlaybackBar({
    required this.progress,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final startTime = DateTime.now().subtract(const Duration(hours: 24));
    final displayTime =
        startTime.add(Duration(minutes: (progress * 24 * 60).toInt()));
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${months[displayTime.month - 1]} ${displayTime.day}';
    final timeStr = '${displayTime.hour.toString().padLeft(2, '0')}:${displayTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$dateStr · $timeStr',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  const Text('POSITION HISTORY · 24H',
                      style: TextStyle(
                          color: Colors.white38,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: MooColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: MooColors.primary.withValues(alpha: 0.2),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: onSeek,
                    divisions: 288,
                  ),
                ),
              ),
            ],
          ),
          // Time labels below slider
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('-24h', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('-18h', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('-12h', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('-6h', style: TextStyle(color: Colors.white38, fontSize: 9)),
                Text('Now', style: TextStyle(color: MooColors.active, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Node info pill — shown on mobile when history/heatmap mode is active
// ---------------------------------------------------------------------------
class _NodeInfoPill extends StatelessWidget {
  final NodeModel node;
  final String modeLabel;
  final VoidCallback onExpand;

  const _NodeInfoPill({
    required this.node,
    required this.modeLabel,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onExpand,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NodeAvatar(node: node, radius: 14),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    node.getName(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    modeLabel,
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more_rounded,
                color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heatmap legend card — shown at bottom when position heatmap mode is active
// ---------------------------------------------------------------------------
class _HeatmapLegendCard extends StatelessWidget {
  final dynamic heatmapData; // PositionHeatmapData?

  const _HeatmapLegendCard({this.heatmapData});

  @override
  Widget build(BuildContext context) {
    // Estimate stats from data points (5-min intervals assumed)
    final totalPts = heatmapData?.totalPoints as int? ?? 0;
    final activeHrs = totalPts > 0 ? (totalPts * 5 / 60).toStringAsFixed(1) : '—';
    final distKm = totalPts > 0
        ? ((totalPts * 0.05).clamp(0.1, 99.9)).toStringAsFixed(1)
        : '—';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('POSITION DENSITY',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          // Gradient bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0000FF), // blue — rare
                    Color(0xFF00FF00), // green — occasional
                    Color(0xFFFFFF00), // yellow — frequent
                    Color(0xFFFF0000), // red — hotspot
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Rare', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('Occasional', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('Frequent', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('Hotspot', style: TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendStat(label: 'Active hrs/day', value: activeHrs),
              _LegendStat(label: 'Distance', value: '$distKm km'),
              _LegendStat(label: 'Data points', value: '$totalPts'),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coverage legend card — shown at bottom when coverage heatmap mode is active
// ---------------------------------------------------------------------------
class _CoverageLegendCard extends StatelessWidget {
  const _CoverageLegendCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SIGNAL COVERAGE (RSSI)',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          // Gradient bar: red (weak) → orange → yellow → green (strong)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 8,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF0000), // red — very weak < -110 dBm
                    Color(0xFFFF8800), // orange — weak -100 to -110
                    Color(0xFFFFFF00), // yellow — moderate -90 to -100
                    Color(0xFF00FF00), // green — good > -90 dBm
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('< -110 dBm', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('-100 dBm', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('-90 dBm', style: TextStyle(color: Colors.white38, fontSize: 9)),
              Text('> -80 dBm', style: TextStyle(color: Colors.white38, fontSize: 9)),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendStat(label: 'Coverage', value: 'RSSI map'),
              _LegendStat(label: 'No signal', value: '< -110 dBm'),
              _LegendStat(label: 'Good signal', value: '> -90 dBm'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendStat extends StatelessWidget {
  final String label;
  final String value;

  const _LegendStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 9)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
