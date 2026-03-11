import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';

class GeofenceEditPage extends StatefulWidget {
  /// Pass null to create a new geofence.
  final Geofence? geofence;

  const GeofenceEditPage({super.key, required this.geofence});

  @override
  State<GeofenceEditPage> createState() => _GeofenceEditPageState();
}

class _GeofenceEditPageState extends State<GeofenceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _color = '#3B82F6';
  String _pastureType = 'meadow';
  List<LatLng> _points = [];
  Set<int> _selectedNodeIds = {};
  bool _drawMode = false;
  bool _saving = false;

  final MapController _mapCtrl = MapController();

  @override
  void initState() {
    super.initState();
    final g = widget.geofence;
    if (g != null) {
      _nameCtrl.text = g.name;
      _descCtrl.text = g.description;
      _color = g.color;
      _pastureType = g.pastureType;
      _points = List.from(g.points);
      _selectedNodeIds = Set.from(g.nodeIds);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.geofence != null;

  Color get _fenceColor => _hexToColor(_color);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? MooColors.bgDark : MooColors.bgLight,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Geofence' : 'New Geofence'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Map section (half the screen)
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.45,
            child: Stack(
              children: [
                _MapEditor(
                  mapCtrl: _mapCtrl,
                  points: _points,
                  fenceColor: _fenceColor,
                  drawMode: _drawMode,
                  onTap: _onMapTap,
                ),
                // Draw mode toolbar
                Positioned(
                  top: 12,
                  right: 12,
                  child: _MapToolbar(
                    drawMode: _drawMode,
                    hasPoints: _points.isNotEmpty,
                    onToggleDraw: () => setState(() => _drawMode = !_drawMode),
                    onUndoPoint: _undoPoint,
                    onClearAll: _clearPoints,
                    onCenterMap: _centerOnPoints,
                  ),
                ),
                // Instruction overlay
                if (_drawMode)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _points.isEmpty
                            ? 'Tap on the map to add the first vertex'
                            : _points.length < 3
                                ? 'Tap to add more vertices (${_points.length}/3 min)'
                                : 'Tap to continue — polygon closes automatically',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                // Area badge
                if (_points.length >= 3)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _fenceColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _computeArea(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Form section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Geofence Name *',
                        hintText: 'e.g. North Pasture',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 12),
                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Optional notes about this pasture',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    // Pasture Type + Color (row)
                    Row(
                      children: [
                        Expanded(
                          child: _LabeledField(
                            label: 'Pasture Type',
                            child: DropdownButtonFormField<String>(
                              initialValue: _pastureType,
                              decoration: const InputDecoration(isDense: true),
                              items: const [
                                DropdownMenuItem(value: 'meadow', child: Text('Meadow')),
                                DropdownMenuItem(value: 'cropland', child: Text('Cropland')),
                                DropdownMenuItem(value: 'forest', child: Text('Forest')),
                                DropdownMenuItem(value: 'water', child: Text('Water Access')),
                                DropdownMenuItem(value: 'other', child: Text('Other')),
                              ],
                              onChanged: (v) => setState(() => _pastureType = v ?? 'meadow'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _LabeledField(
                          label: 'Color',
                          child: _ColorPicker(
                            selected: _color,
                            onChanged: (c) => setState(() => _color = c),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Cattle Assignment
                    _CattleAssignment(
                      selectedIds: _selectedNodeIds,
                      onChanged: (ids) => setState(() => _selectedNodeIds = ids),
                    ),
                    const SizedBox(height: 16),
                    // Polygon info
                    _PolygonInfo(
                      points: _points,
                      onDraw: () => setState(() => _drawMode = true),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapTap(TapPosition _, LatLng point) {
    if (!_drawMode) return;
    setState(() => _points.add(point));
  }

  void _undoPoint() {
    if (_points.isNotEmpty) setState(() => _points.removeLast());
  }

  void _clearPoints() {
    setState(() => _points.clear());
  }

  void _centerOnPoints() {
    if (_points.isEmpty) return;
    final lats = _points.map((p) => p.latitude);
    final lngs = _points.map((p) => p.longitude);
    final centerLat = (lats.reduce((a, b) => a + b)) / _points.length;
    final centerLng = (lngs.reduce((a, b) => a + b)) / _points.length;
    _mapCtrl.move(LatLng(centerLat, centerLng), 15);
  }

  String _computeArea() {
    if (_points.length < 3) return '';
    final tempGeofence = Geofence(id: 0, name: '', points: _points, nodeIds: []);
    final ha = tempGeofence.areaHectares;
    if (ha >= 100) return '${ha.toStringAsFixed(0)} ha';
    return '${ha.toStringAsFixed(2)} ha';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_points.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please draw at least 3 vertices on the map'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final herd = context.read<HerdState>();
    final name = _nameCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final nodeIds = _selectedNodeIds.toList();

    bool ok;
    if (_isEditing) {
      ok = await herd.updateGeofence(
        widget.geofence!.id,
        name: name,
        points: _points,
        description: desc,
        color: _color,
        pastureType: _pastureType,
        nodeIds: nodeIds,
      );
    } else {
      final id = await herd.createGeofence(
        name: name,
        points: _points,
        description: desc,
        color: _color,
        pastureType: _pastureType,
        nodeIds: nodeIds,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Geofence updated' : 'Geofence created'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(herd.geofenceError ?? 'Save failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return MooColors.primary;
  }
}

// ---------------------------------------------------------------------------
// Map editor
// ---------------------------------------------------------------------------

class _MapEditor extends StatelessWidget {
  final MapController mapCtrl;
  final List<LatLng> points;
  final Color fenceColor;
  final bool drawMode;
  final void Function(TapPosition, LatLng) onTap;

  const _MapEditor({
    required this.mapCtrl,
    required this.points,
    required this.fenceColor,
    required this.drawMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final center = points.isNotEmpty
        ? LatLng(
            points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
            points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
          )
        : const LatLng(40.4168, -3.7038);

    return FlutterMap(
      mapController: mapCtrl,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        onTap: onTap,
        interactionOptions: InteractionOptions(
          flags: drawMode
              ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
              : InteractiveFlag.all,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.moopoint.app',
          retinaMode: true,
        ),
        if (points.length >= 3)
          PolygonLayer(
            polygons: [
              Polygon(
                points: points,
                color: fenceColor.withValues(alpha: 0.2),
                borderColor: fenceColor,
                borderStrokeWidth: 2.5,
              ),
            ],
          ),
        if (points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: fenceColor,
                strokeWidth: 2.5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (int i = 0; i < points.length; i++)
              Marker(
                point: points[i],
                width: 20,
                height: 20,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: i == 0 ? Colors.green : fenceColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(blurRadius: 3, color: Colors.black26),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Map toolbar
// ---------------------------------------------------------------------------

class _MapToolbar extends StatelessWidget {
  final bool drawMode;
  final bool hasPoints;
  final VoidCallback onToggleDraw;
  final VoidCallback onUndoPoint;
  final VoidCallback onClearAll;
  final VoidCallback onCenterMap;

  const _MapToolbar({
    required this.drawMode,
    required this.hasPoints,
    required this.onToggleDraw,
    required this.onUndoPoint,
    required this.onClearAll,
    required this.onCenterMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ToolBtn(
          icon: drawMode ? Icons.touch_app : Icons.draw_outlined,
          label: drawMode ? 'Done' : 'Draw',
          active: drawMode,
          onPressed: onToggleDraw,
        ),
        const SizedBox(height: 6),
        _ToolBtn(
          icon: Icons.undo,
          label: 'Undo',
          onPressed: hasPoints ? onUndoPoint : null,
        ),
        const SizedBox(height: 6),
        _ToolBtn(
          icon: Icons.clear_all,
          label: 'Clear',
          onPressed: hasPoints ? onClearAll : null,
        ),
        const SizedBox(height: 6),
        _ToolBtn(
          icon: Icons.center_focus_strong,
          label: 'Center',
          onPressed: hasPoints ? onCenterMap : null,
        ),
      ],
    );
  }
}

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  const _ToolBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      color: active ? MooColors.primary : Colors.white,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? Colors.grey.shade400
                : active
                    ? Colors.white
                    : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Color picker
// ---------------------------------------------------------------------------

const _kColors = [
  '#3B82F6', // blue
  '#10B981', // green
  '#F59E0B', // amber
  '#EF4444', // red
  '#8B5CF6', // violet
  '#EC4899', // pink
  '#06B6D4', // cyan
  '#F97316', // orange
];

class _ColorPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  const _ColorPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _hexToColor(selected),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: const Icon(Icons.palette_outlined, color: Colors.white, size: 18),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pick Fence Color', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _kColors.map((c) {
                  final isSelected = c == selected;
                  return GestureDetector(
                    onTap: () {
                      onChanged(c);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _hexToColor(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.black87 : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check, color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _hexToColor(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length == 6) return Color(int.parse('FF$h', radix: 16));
    return MooColors.primary;
  }
}

// ---------------------------------------------------------------------------
// Labeled field helper
// ---------------------------------------------------------------------------

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cattle Assignment
// ---------------------------------------------------------------------------

class _CattleAssignment extends StatelessWidget {
  final Set<int> selectedIds;
  final ValueChanged<Set<int>> onChanged;
  const _CattleAssignment({required this.selectedIds, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final herd = context.watch<HerdState>();
    final cattleNodes = herd.nodes.where((n) => n.nodeType == NodeType.cattle).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Assign Cattle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (cattleNodes.isNotEmpty)
              TextButton(
                onPressed: () {
                  final allIds = cattleNodes.map((n) => n.nodeId).toSet();
                  if (selectedIds.length == allIds.length) {
                    onChanged({});
                  } else {
                    onChanged(allIds);
                  }
                },
                child: Text(
                  selectedIds.length == cattleNodes.length ? 'Deselect All' : 'Select All',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (cattleNodes.isEmpty)
          const Text('No cattle nodes available.', style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cattleNodes.map((node) {
              final isSelected = selectedIds.contains(node.nodeId);
              return FilterChip(
                selected: isSelected,
                avatar: NodeAvatar(node: node, radius: 12),
                label: Text(node.getName(), style: const TextStyle(fontSize: 12)),
                onSelected: (val) {
                  final newSet = Set<int>.from(selectedIds);
                  if (val) {
                    newSet.add(node.nodeId);
                  } else {
                    newSet.remove(node.nodeId);
                  }
                  onChanged(newSet);
                },
                selectedColor: MooColors.primary.withValues(alpha: 0.15),
                checkmarkColor: MooColors.primary,
                side: BorderSide(
                  color: isSelected ? MooColors.primary : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
        if (selectedIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${selectedIds.length} cattle selected',
              style: TextStyle(fontSize: 11, color: MooColors.primary),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Polygon Info
// ---------------------------------------------------------------------------

class _PolygonInfo extends StatelessWidget {
  final List<LatLng> points;
  final VoidCallback onDraw;
  const _PolygonInfo({required this.points, required this.onDraw});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? MooColors.surfaceDark : MooColors.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: points.length < 3 ? Colors.orange.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            points.length >= 3 ? Icons.check_circle_outline : Icons.draw_outlined,
            size: 18,
            color: points.length >= 3 ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  points.length >= 3
                      ? 'Boundary defined (${points.length} vertices)'
                      : points.isEmpty
                          ? 'No boundary drawn yet'
                          : '${points.length} vertices — need at least 3',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: points.length >= 3 ? Colors.green : Colors.orange,
                  ),
                ),
                if (points.length < 3)
                  const Text(
                    'Tap "Draw" on the map to set the boundary',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (points.isEmpty)
            TextButton(
              onPressed: onDraw,
              child: const Text('Draw', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
