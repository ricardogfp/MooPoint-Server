import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';
import 'package:moo_point/app/theme/app_theme.dart';

/// Full-screen map page for placing a newly discovered fence node at a static
/// geographic position. Shows all existing geofences as reference polygons.
class NodePlacementPage extends StatefulWidget {
  /// All unplaced new fence nodes. The user can switch between them.
  final List<NodeModel> newNodes;

  const NodePlacementPage({super.key, required this.newNodes});

  @override
  State<NodePlacementPage> createState() => _NodePlacementPageState();
}

class _NodePlacementPageState extends State<NodePlacementPage> {
  final _admin = NodeBackendAdminService();
  final _mapController = MapController();

  late NodeModel _selectedNode;
  LatLng? _placementLocation;

  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _panelExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedNode = widget.newNodes.first;
    _nameController.text = _selectedNode.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _admin.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _selectNode(NodeModel node) {
    setState(() {
      _selectedNode = node;
      _nameController.text = node.name;
      _placementLocation = null; // Reset pin when switching node
    });
  }

  Future<void> _savePlacement() async {
    if (_placementLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tap on the map to drop the fence node pin first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _admin.updateNodeInfo(
        _selectedNode.nodeId,
        friendlyName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        nodeType: 'fence',
        staticLat: _placementLocation!.latitude,
        staticLon: _placementLocation!.longitude,
      );

      if (!mounted) return;
      context.read<HerdState>().loadNodesAndGeofences();

      // If there's only one node remaining, pop the page
      final remaining = widget.newNodes
          .where((n) => n.nodeId != _selectedNode.nodeId)
          .toList();
      if (remaining.isEmpty) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All fence nodes placed successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Node ${_selectedNode.getName()} placed. '
              '${remaining.length} remaining.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _selectNode(remaining.first);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final herd = context.watch<HerdState>();
    final geofences = herd.geofences;
    final remaining = widget.newNodes.length;

    return Scaffold(
      backgroundColor: isDark ? MooColors.bgDark : MooColors.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Place Fence Node', style: TextStyle(fontSize: 16)),
            Text(
              '$remaining node${remaining == 1 ? '' : 's'} to place',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton.icon(
              onPressed: _savePlacement,
              icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
              label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Instruction strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: MooColors.primary.withValues(alpha: 0.12),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: MooColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _placementLocation == null
                        ? 'Tap on the map to pin the permanent position for '
                            '"${_selectedNode.getName()}"'
                        : 'Location set. Adjust name below, then tap Save.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: Stack(
              children: [
                _PlacementMap(
                  mapController: _mapController,
                  geofences: geofences,
                  placedNodes: herd.nodes
                      .where((n) =>
                          n.nodeType == NodeType.fence && !n.isNew)
                      .toList(),
                  placementLocation: _placementLocation,
                  selectedNode: _selectedNode,
                  onTap: (_, ll) => setState(() => _placementLocation = ll),
                ),
                // Node selector — top left overlay (only when multiple)
                if (widget.newNodes.length > 1)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 80,
                    child: _NodeSelector(
                      nodes: widget.newNodes,
                      selected: _selectedNode,
                      onSelect: _selectNode,
                    ),
                  ),
                // Pin indicator badge
                if (_placementLocation != null)
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: _CoordBadge(location: _placementLocation!),
                  ),
              ],
            ),
          ),
          // Bottom sheet: name field
          _DetailsPanel(
            nameController: _nameController,
            node: _selectedNode,
            expanded: _panelExpanded,
            onToggle: () => setState(() => _panelExpanded = !_panelExpanded),
            onSave: _isSaving ? null : _savePlacement,
            isSaving: _isSaving,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Map widget
// ---------------------------------------------------------------------------

class _PlacementMap extends StatelessWidget {
  final MapController mapController;
  final List<dynamic> geofences; // List<Geofence>
  final List<NodeModel> placedNodes;
  final LatLng? placementLocation;
  final NodeModel selectedNode;
  final void Function(TapPosition, LatLng) onTap;

  const _PlacementMap({
    required this.mapController,
    required this.geofences,
    required this.placedNodes,
    required this.placementLocation,
    required this.selectedNode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: placementLocation ??
            (placedNodes.isNotEmpty
                ? LatLng(placedNodes.first.latitude,
                    placedNodes.first.longitude)
                : const LatLng(40.4168, -3.7038)),
        initialZoom: 15,
        onTap: onTap,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moopoint.app',
          retinaMode: true,
        ),
        // Geofence reference polygons (dimmed)
        if (geofences.isNotEmpty)
          PolygonLayer(
            polygons: [
              for (final g in geofences)
                Polygon(
                  points: (g.points as List<LatLng>),
                  color: _hexToColor(g.color as String).withValues(alpha: 0.12),
                  borderColor:
                      _hexToColor(g.color as String).withValues(alpha: 0.5),
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        // Already-placed fence nodes
        MarkerLayer(
          markers: [
            for (final n in placedNodes)
              Marker(
                point: LatLng(n.latitude, n.longitude),
                width: 32,
                height: 32,
                child: Tooltip(
                  message: n.getName(),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: MooColors.fenceBrown.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.fence_rounded,
                        size: 12, color: Colors.white),
                  ),
                ),
              ),
            // Drop pin
            if (placementLocation != null)
              Marker(
                point: placementLocation!,
                width: 48,
                height: 56,
                alignment: Alignment.topCenter,
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: MooColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                              blurRadius: 6, color: Colors.black38, offset: Offset(0, 2))
                        ],
                      ),
                      child: const Icon(Icons.fence_rounded,
                          size: 18, color: Colors.white),
                    ),
                    Container(
                      width: 2,
                      height: 14,
                      color: MooColors.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return MooColors.primary;
  }
}

// ---------------------------------------------------------------------------
// Node selector
// ---------------------------------------------------------------------------

class _NodeSelector extends StatelessWidget {
  final List<NodeModel> nodes;
  final NodeModel selected;
  final ValueChanged<NodeModel> onSelect;

  const _NodeSelector({
    required this.nodes,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      color: Theme.of(context).brightness == Brightness.dark
          ? MooColors.surfaceDark
          : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<NodeModel>(
            value: selected,
            isExpanded: true,
            isDense: true,
            items: nodes
                .map((n) => DropdownMenuItem(
                      value: n,
                      child: Text(
                        'Node ${n.nodeId} — ${n.getName()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) onSelect(v);
            },
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Coordinate badge
// ---------------------------------------------------------------------------

class _CoordBadge extends StatelessWidget {
  final LatLng location;
  const _CoordBadge({required this.location});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${location.latitude.toStringAsFixed(5)}, '
        '${location.longitude.toStringAsFixed(5)}',
        style: const TextStyle(
            color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom details panel
// ---------------------------------------------------------------------------

class _DetailsPanel extends StatelessWidget {
  final TextEditingController nameController;
  final NodeModel node;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback? onSave;
  final bool isSaving;

  const _DetailsPanel({
    required this.nameController,
    required this.node,
    required this.expanded,
    required this.onToggle,
    required this.onSave,
    required this.isSaving,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar / toggle
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                    size: 16,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Node info row
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: MooColors.fenceBrown.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fence_rounded,
                            size: 18, color: MooColors.fenceBrown),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fence Node #${node.nodeId}',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              node.deviceId != null
                                  ? 'Device ID: ${node.deviceId}'
                                  : 'Newly discovered — no device assigned',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Battery
                      _BattBadge(level: node.batteryLevel),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Name field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Friendly Name',
                      hintText: 'e.g. North Fence Post',
                      prefixIcon: const Icon(Icons.label_outline, size: 18),
                      filled: true,
                      fillColor: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Save button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Save Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: MooColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _BattBadge extends StatelessWidget {
  final int level;
  const _BattBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = level >= 50
        ? Colors.green
        : level >= 20
            ? Colors.orange
            : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.battery_std_outlined, size: 12, color: color),
          const SizedBox(width: 3),
          Text('$level%',
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
