import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/geofence_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';
import 'package:moo_point/services/api/node_backend_service.dart';
import 'package:moo_point/presentation/pages/ble/ble_provisioning_menu.dart';
import 'package:moo_point/presentation/pages/admin/config_push_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _admin = NodeBackendAdminService();
  final _backend = NodeBackendService();

  @override
  void dispose() {
    _admin.dispose();
    _backend.dispose();
    super.dispose();
  }

  void _onChanged() {
    // Refresh shared state so Map and Herd tabs pick up changes
    context.read<HerdState>().loadNodesAndGeofences();
  }

  @override
  Widget build(BuildContext context) {
    final isBleSupported =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Action bar with BLE provisioning and Config Push
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isBleSupported)
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const BleProvisioningMenu()),
                      );
                    },
                    icon: const Icon(Icons.settings_bluetooth),
                    label: const Text('BLE Provisioning'),
                  ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ConfigPushPage()),
                    );
                  },
                  icon: const Icon(Icons.settings_remote),
                  label: const Text('Push Config'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Nodes'),
              Tab(text: 'Geofences'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _NodesTab(
                  admin: _admin,
                  backend: _backend,
                  onChanged: _onChanged,
                ),
                _GeofencesTab(
                  admin: _admin,
                  backend: _backend,
                  onChanged: _onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodesTab extends StatefulWidget {
  final NodeBackendAdminService admin;
  final NodeBackendService backend;
  final VoidCallback? onChanged;

  const _NodesTab({required this.admin, required this.backend, this.onChanged});

  @override
  State<_NodesTab> createState() => _NodesTabState();
}

class _NodesTabState extends State<_NodesTab> {
  Future<List<NodeModel>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = widget.backend.getNodesData();
    });
  }

  Future<void> _editNodeInfo(NodeModel node) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EditNodeDialog(node: node, admin: widget.admin),
    );
    if (saved == true) {
      widget.onChanged?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NodeModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final nodes = snap.data ?? <NodeModel>[];
        if (nodes.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.pets,
            title: 'No nodes found',
            subtitle: 'Nodes will appear here once they report data',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: nodes.length,
            itemBuilder: (context, i) {
              final node = nodes[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          NodeAvatar(node: node, radius: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(node.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                Text('Node ${node.nodeId}',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          StatusPill.fromStatus(node.overallStatus),
                          const SizedBox(width: 6),
                          StatusPill.battery(node.batteryLevel),
                        ],
                      ),
                      if (node.breed != null ||
                          node.age != null ||
                          node.healthStatus != null ||
                          (node.comments != null &&
                              node.comments!.isNotEmpty)) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (node.breed != null)
                              _AdminInfoChip(
                                  label: 'Breed', value: node.breed!),
                            if (node.age != null)
                              _AdminInfoChip(
                                  label: 'Age', value: '${node.age}y'),
                            if (node.healthStatus != null)
                              _AdminInfoChip(
                                  label: 'Health', value: node.healthStatus!),
                          ],
                        ),
                        if (node.comments != null && node.comments!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(node.comments!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ),
                      ],
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _editNodeInfo(node),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _GeofencesTab extends StatefulWidget {
  final NodeBackendAdminService admin;
  final NodeBackendService backend;
  final VoidCallback? onChanged;

  const _GeofencesTab(
      {required this.admin, required this.backend, this.onChanged});

  @override
  State<_GeofencesTab> createState() => _GeofencesTabState();
}

class _GeofencesTabState extends State<_GeofencesTab> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = widget.admin.listGeofences();
    });
  }

  Future<void> _createGeofence() async {
    final nodes = await widget.backend.getNodesData();
    if (!mounted) return;

    final created = await showModalBottomSheet<_CreateGeofenceResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GeofenceEditorSheet(nodes: nodes),
    );

    if (created == null) return;

    try {
      final id = await widget.admin
          .createGeofence(name: created.name, geojson: created.geojson);
      await widget.admin.setGeofenceNodes(id, created.nodeIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geofence created')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _deleteGeofence(int id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Geofence'),
        content: Text(
            'Are you sure you want to delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: MooColors.lowBattery),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.admin.deleteGeofence(id);
      if (!mounted) return;
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _editGeofence(Geofence geofence) async {
    final nodes = await widget.backend.getNodesData();
    if (!mounted) return;

    final updated = await showModalBottomSheet<_CreateGeofenceResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _GeofenceEditorSheet(nodes: nodes, geofence: geofence),
    );

    if (updated == null) return;

    try {
      await widget.admin.updateGeofence(geofence.id,
          name: updated.name, geojson: updated.geojson);
      await widget.admin.setGeofenceNodes(geofence.id, updated.nodeIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Geofence updated')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? <Map<String, dynamic>>[];
        final fences = items.map((m) => Geofence.fromJson(m)).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _createGeofence,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Geofence'),
                  ),
                  const SizedBox(width: 12),
                  Text('${fences.length} geofences',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: fences.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.fence,
                      title: 'No geofences',
                      subtitle: 'Create a geofence to monitor node positions',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemCount: fences.length,
                      itemBuilder: (context, i) {
                        final f = fences[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: MooColors.accent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.fence,
                                      color: MooColors.accent, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          _AdminInfoChip(
                                              label: 'Nodes',
                                              value: '${f.nodeIds.length}'),
                                          const SizedBox(width: 8),
                                          _AdminInfoChip(
                                              label: 'Points',
                                              value: '${f.points.length}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _editGeofence(f),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 20, color: MooColors.lowBattery),
                                  onPressed: () =>
                                      _deleteGeofence(f.id, f.name),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _CreateGeofenceResult {
  final String name;
  final Map<String, dynamic> geojson;
  final List<int> nodeIds;

  _CreateGeofenceResult(
      {required this.name, required this.geojson, required this.nodeIds});
}

class _GeofenceEditorSheet extends StatefulWidget {
  final List<NodeModel> nodes;
  final Geofence? geofence; // null = create mode

  const _GeofenceEditorSheet({required this.nodes, this.geofence});

  @override
  State<_GeofenceEditorSheet> createState() => _GeofenceEditorSheetState();
}

// ---------------------------------------------------------------------------
// Edit node dialog — supports camera/gallery photo on Android, URL on web
// ---------------------------------------------------------------------------
class _EditNodeDialog extends StatefulWidget {
  final NodeModel node;
  final NodeBackendAdminService admin;

  const _EditNodeDialog({required this.node, required this.admin});

  @override
  State<_EditNodeDialog> createState() => _EditNodeDialogState();
}

class _EditNodeDialogState extends State<_EditNodeDialog> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _breedCtl;
  late final TextEditingController _ageCtl;
  late final TextEditingController _healthCtl;
  late final TextEditingController _commentsCtl;
  late final TextEditingController _photoUrlCtl;

  XFile? _pickedPhoto;
  bool _uploading = false;
  String? _photoPreviewUrl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: widget.node.name);
    _breedCtl = TextEditingController(text: widget.node.breed ?? '');
    _ageCtl = TextEditingController(text: widget.node.age?.toString() ?? '');
    _healthCtl = TextEditingController(text: widget.node.healthStatus ?? '');
    _commentsCtl = TextEditingController(text: widget.node.comments ?? '');
    _photoUrlCtl = TextEditingController(text: widget.node.photoUrl ?? '');
    _photoPreviewUrl = widget.node.photoUrl;
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _breedCtl.dispose();
    _ageCtl.dispose();
    _healthCtl.dispose();
    _commentsCtl.dispose();
    _photoUrlCtl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();

      // Configure camera to go directly to capture without confirmation
      final file = source == ImageSource.camera
          ? await picker.pickImage(
              source: source,
              maxWidth: 1200,
              imageQuality: 90,
              preferredCameraDevice: CameraDevice.rear,
            )
          : await picker.pickImage(
              source: source,
              maxWidth: 1200,
              imageQuality: 90,
            );

      if (file == null) return;

      // On native platforms, open the circular crop UI with safe area padding
      if (!kIsWeb) {
        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 80,
          maxWidth: 800,
          maxHeight: 800,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Crop Node Photo',
              toolbarColor: MooColors.primary,
              toolbarWidgetColor: Colors.white,
              activeControlsWidgetColor: MooColors.primary,
              cropGridColor: Colors.white54,
              cropFrameColor: Colors.white,
              cropStyle: CropStyle.circle,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: false,
            ),
            IOSUiSettings(
              title: 'Crop Node Photo',
              cropStyle: CropStyle.circle,
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              hidesNavigationBar: false,
            ),
          ],
        );
        if (cropped == null) return; // user cancelled crop
        setState(() {
          _pickedPhoto = XFile(cropped.path);
          _photoPreviewUrl = null;
        });
      } else {
        // On web, skip crop — just use the picked file directly
        setState(() {
          _pickedPhoto = file;
          _photoPreviewUrl = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _uploading = true);
    try {
      String? photoUrl =
          _photoUrlCtl.text.trim().isEmpty ? null : _photoUrlCtl.text.trim();

      // If a photo was picked from camera/gallery, upload it first.
      // The server saves the photo_url in the DB via updateNodePhotoUrl.
      if (_pickedPhoto != null) {
        final bytes = await _pickedPhoto!.readAsBytes();
        final filename = _pickedPhoto!.name;
        photoUrl = await widget.admin
            .uploadNodePhoto(widget.node.nodeId, bytes, filename);
        debugPrint('Photo uploaded successfully: $photoUrl');
      }

      // Gather text field values
      final name = _nameCtl.text.trim().isEmpty ? null : _nameCtl.text.trim();
      final breed =
          _breedCtl.text.trim().isEmpty ? null : _breedCtl.text.trim();
      final age = _ageCtl.text.trim().isEmpty
          ? null
          : int.tryParse(_ageCtl.text.trim());
      final health =
          _healthCtl.text.trim().isEmpty ? null : _healthCtl.text.trim();
      final comments =
          _commentsCtl.text.trim().isEmpty ? null : _commentsCtl.text.trim();

      // Only call updateNodeInfo if there's at least one field to send.
      // If only a photo was picked (no text changes), the upload already saved it.
      final hasTextFields = name != null ||
          breed != null ||
          age != null ||
          health != null ||
          comments != null ||
          photoUrl != null;
      if (hasTextFields) {
        await widget.admin.updateNodeInfo(
          widget.node.nodeId,
          friendlyName: name,
          breed: breed,
          age: age,
          healthStatus: health,
          comments: comments,
          photoUrl: photoUrl,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit node ${widget.node.nodeId}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Photo section ---
            _buildPhotoSection(),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                labelText: 'Friendly Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _breedCtl,
              decoration: const InputDecoration(
                labelText: 'Breed',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageCtl,
              decoration: const InputDecoration(
                labelText: 'Age (years)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _healthCtl,
              decoration: const InputDecoration(
                labelText: 'Health Status',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentsCtl,
              decoration: const InputDecoration(
                labelText: 'Comments',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            // On web, show a URL field as fallback
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _photoUrlCtl,
                decoration: const InputDecoration(
                  labelText: 'Photo URL',
                  hintText: 'https://example.com/photo.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _uploading ? null : _save,
          child: _uploading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildPhotoSection() {
    Widget preview;
    if (_pickedPhoto != null) {
      // Show picked file preview
      preview = FutureBuilder<Uint8List>(
        future: _pickedPhoto!.readAsBytes(),
        builder: (ctx, snap) {
          if (snap.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(snap.data!,
                  width: 120, height: 120, fit: BoxFit.cover),
            );
          }
          return const SizedBox(
              width: 120,
              height: 120,
              child: Center(child: CircularProgressIndicator()));
        },
      );
    } else if (_photoPreviewUrl != null && _photoPreviewUrl!.isNotEmpty) {
      debugPrint('Displaying photo from URL: $_photoPreviewUrl');
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _photoPreviewUrl!,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return SizedBox(
              width: 120,
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading photo from $_photoPreviewUrl: $error');
            return _photoPlaceholder();
          },
        ),
      );
    } else {
      preview = _photoPlaceholder();
    }

    return Column(
      children: [
        preview,
        const SizedBox(height: 10),
        // Camera/gallery buttons (Android/iOS only — hidden on web)
        if (!kIsWeb)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        // On web, also allow gallery pick (file chooser)
        if (kIsWeb)
          OutlinedButton.icon(
            onPressed: () => _pickPhoto(ImageSource.gallery),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Choose File'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.pets, size: 48, color: Colors.grey.shade400),
    );
  }
}

// ---------------------------------------------------------------------------
// Small info chip used in admin node/geofence cards
// ---------------------------------------------------------------------------
class _AdminInfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _AdminInfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
      ),
    );
  }
}

class _GeofenceEditorSheetState extends State<_GeofenceEditorSheet> {
  final _nameController = TextEditingController();
  final _mapController = MapController();
  late List<LatLng> _points;
  late Set<int> _selectedNodes;
  int? _draggingIndex;

  @override
  void initState() {
    super.initState();
    final gf = widget.geofence;
    if (gf != null) {
      _nameController.text = gf.name;
      _points = gf.points.toList();
      _selectedNodes = gf.nodeIds.toSet();
    } else {
      _points = [];
      _selectedNodes = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _addPoint(LatLng p) {
    if (_draggingIndex != null) return;
    if (_points.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 10 vertices allowed')));
      return;
    }
    setState(() {
      _points.add(p);
    });
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      _points.removeLast();
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
    });
  }

  void _deleteVertex(int index) {
    setState(() {
      _points.removeAt(index);
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    if (_points.length < 3) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least 3 points')));
      return;
    }

    final ring = <List<double>>[];
    for (final p in _points) {
      ring.add([p.longitude, p.latitude]);
    }
    ring.add([_points.first.longitude, _points.first.latitude]);

    final geojson = {
      'type': 'Feature',
      'geometry': {
        'type': 'Polygon',
        'coordinates': [ring],
      },
      'properties': {},
    };

    Navigator.pop(
      context,
      _CreateGeofenceResult(
        name: name,
        geojson: geojson,
        nodeIds: _selectedNodes.toList()..sort(),
      ),
    );
  }

  List<Marker> _buildDraggableMarkers() {
    return List.generate(_points.length, (i) {
      return Marker(
        point: _points[i],
        width: 30,
        height: 30,
        child: GestureDetector(
          onTap: () {
            // Simple tap to select vertex for deletion
            _deleteVertex(i);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _draggingIndex == i ? Colors.orange : Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
            ),
            child: Center(
              child: Text(
                '${i + 1}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Center on existing points (edit) or first node (create) or default
    final center = _points.isNotEmpty
        ? LatLng(
            _points.map((p) => p.latitude).reduce((a, b) => a + b) /
                _points.length,
            _points.map((p) => p.longitude).reduce((a, b) => a + b) /
                _points.length,
          )
        : widget.nodes.isNotEmpty
            ? LatLng(widget.nodes.first.latitude, widget.nodes.first.longitude)
            : const LatLng(40.4637, -3.7492);

    final polygon = _points.length >= 3
        ? Polygon(
            points: _points,
            color: Colors.blue.withValues(alpha: 0.2),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
          )
        : null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Geofence name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(onPressed: _save, child: const Text('Save')),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                        onPressed: _undo,
                        icon: const Icon(Icons.undo),
                        label: const Text('Undo')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                        onPressed: _clear,
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear')),
                    const SizedBox(width: 12),
                    Text('Points: ${_points.length}'),
                    const Spacer(),
                    Text('Long-press to delete',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14,
                    onTap: (tapPosition, point) => _addPoint(point),
                    interactionOptions: InteractionOptions(
                      flags: _draggingIndex != null
                          ? InteractiveFlag.none
                          : InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.moopoint.tracker',
                    ),
                    if (polygon != null) PolygonLayer(polygons: [polygon]),
                    MarkerLayer(markers: _buildDraggableMarkers()),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Text('Assign nodes',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...widget.nodes.map((c) {
                      final checked = _selectedNodes.contains(c.nodeId);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedNodes.add(c.nodeId);
                            } else {
                              _selectedNodes.remove(c.nodeId);
                            }
                          });
                        },
                        title: Text(c.name),
                        subtitle: Text('Node ID: ${c.nodeId}'),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
