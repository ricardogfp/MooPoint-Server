import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/presentation/pages/nodes/widgets/node_details_sheet.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/services/api/node_backend_service.dart';

/// When [nodeId] is null the widget acts as a tab inside HomePage and reads
/// events from the shared [HerdState].  When [nodeId] is provided it is pushed
/// as a standalone page with its own Scaffold and fetches filtered events.
class GeofenceEventsPage extends StatefulWidget {
  final int? nodeId;

  const GeofenceEventsPage({super.key, this.nodeId});

  bool get _isTab => nodeId == null;

  @override
  State<GeofenceEventsPage> createState() => _GeofenceEventsPageState();
}

class _GeofenceEventsPageState extends State<GeofenceEventsPage> {
  // Only used when pushed with a nodeId filter (standalone mode)
  NodeBackendService? _backend;
  Future<List<GeofenceEvent>>? _future;

  // Filter state
  String _typeFilter = 'All'; // 'All', 'exit', 'enter'

  @override
  void initState() {
    super.initState();
    if (!widget._isTab) {
      _backend = NodeBackendService();
      _future = _backend!.getGeofenceEvents(nodeId: widget.nodeId);
    }
  }

  @override
  void dispose() {
    _backend?.dispose();
    super.dispose();
  }

  void _reloadStandalone() {
    setState(() {
      _future = _backend!.getGeofenceEvents(nodeId: widget.nodeId);
    });
  }

  List<GeofenceEvent> _applyFilter(List<GeofenceEvent> events) {
    if (_typeFilter == 'All') return events;
    return events.where((e) => e.type == _typeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    // --- Standalone mode (pushed from node details with nodeId) ---
    if (!widget._isTab) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Events — Node ${widget.nodeId}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reloadStandalone,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: FutureBuilder<List<GeofenceEvent>>(
          future: _future,
          builder: (context, snap) => _buildBody(
            events: snap.data,
            isLoading: snap.connectionState != ConnectionState.done,
            error: snap.hasError ? snap.error.toString() : null,
            onRetry: _reloadStandalone,
          ),
        ),
      );
    }

    // --- Tab mode (reads from HerdState) ---
    return Consumer<HerdState>(
      builder: (context, state, _) {
        return _buildBody(
          events: state.events,
          isLoading: state.eventsLoading,
          error: state.eventsError,
          onRetry: () => state.loadEvents(),
        );
      },
    );
  }

  Widget _buildBody({
    List<GeofenceEvent>? events,
    required bool isLoading,
    String? error,
    required VoidCallback onRetry,
  }) {
    if (isLoading && (events == null || events.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && (events == null || events.isEmpty)) {
      return EmptyStateWidget(
        icon: Icons.error_outline,
        title: 'Failed to load events',
        subtitle: error,
        onAction: onRetry,
        actionLabel: 'Retry',
      );
    }
    final all = events ?? [];
    final filtered = _applyFilter(all);

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _FilterChip(
                label: 'All (${all.length})',
                selected: _typeFilter == 'All',
                onTap: () => setState(() => _typeFilter = 'All'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Exit',
                selected: _typeFilter == 'exit',
                color: MooColors.lowBattery,
                onTap: () => setState(() => _typeFilter = 'exit'),
              ),
              const SizedBox(width: 8),
              _FilterChip(
                label: 'Enter',
                selected: _typeFilter == 'enter',
                color: MooColors.active,
                onTap: () => setState(() => _typeFilter = 'enter'),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.fence,
                  title: 'No geofence events',
                  subtitle:
                      'Events will appear here when nodes enter or exit geofences',
                )
              : RefreshIndicator(
                  onRefresh: () async => onRetry(),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    itemBuilder: (context, i) => _EventCard(event: filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip
// ---------------------------------------------------------------------------
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? MooColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.withOpacity(0.15) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? c : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Event card — color-coded, relative time, tap to navigate
// ---------------------------------------------------------------------------
class _EventCard extends StatelessWidget {
  final GeofenceEvent event;

  const _EventCard({required this.event});

  String _relativeTime(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('MMM dd').format(dt.toLocal());
  }

  void _onTap(BuildContext context) {
    // Try to find the node in HerdState and show details
    try {
      final state = context.read<HerdState>();
      final node = state.nodes.firstWhere((c) => c.nodeId == event.nodeId);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => NodeDetailsSheet(node: node),
      );
    } catch (_) {
      // Node not found in current state — ignore tap
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExit = event.type == 'exit';
    final color = isExit ? MooColors.lowBattery : MooColors.active;
    final icon = isExit ? Icons.logout : Icons.login;
    final typeLabel = isExit ? 'EXIT' : 'ENTER';
    final fenceName = event.geofenceName ?? 'Geofence ${event.geofenceId}';
    final nodeName = event.nodeName ?? 'Node ${event.nodeId}';
    final relative = _relativeTime(event.eventTime);
    final fullTime =
        DateFormat('MMM dd, yyyy HH:mm:ss').format(event.eventTime.toLocal());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _onTap(context),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Color-coded icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(nodeName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        StatusPill(label: typeLabel, color: color),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(fenceName,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.access_time,
                            size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(relative,
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(fullTime,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
