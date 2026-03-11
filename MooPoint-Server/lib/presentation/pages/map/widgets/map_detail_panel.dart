import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:moo_point/data/models/node_model.dart';
import 'package:moo_point/data/models/behavior_model.dart';
import 'package:moo_point/data/models/geofence_event_model.dart';
import 'package:moo_point/data/models/node_history_model.dart';
import 'package:moo_point/data/models/alert_model.dart';
import 'package:moo_point/app/theme/app_theme.dart';
import 'package:moo_point/l10n/l10n_helper.dart';
import 'package:moo_point/presentation/providers/herd_state.dart';
import 'package:moo_point/presentation/pages/nodes/node_placement_page.dart';
import '../map_page.dart';

class MapDetailPanel extends StatefulWidget {
  final MapViewState state;
  final NodeModel node;
  final VoidCallback onClose;
  final VoidCallback onOpenConfig;

  const MapDetailPanel({
    super.key,
    required this.state,
    required this.node,
    required this.onClose,
    required this.onOpenConfig,
  });

  @override
  State<MapDetailPanel> createState() => _MapDetailPanelState();
}

class _MapDetailPanelState extends State<MapDetailPanel> {
  // Cattle data
  BehaviorSummary? _behaviorSummary;
  List<GeofenceEvent> _geofenceEvents = [];
  bool _behaviorLoading = true;
  bool _eventsLoading = true;

  // Fence data
  List<NodeHistoryPoint> _voltageHistory = [];
  List<AlertModel> _nodeAlerts = [];
  bool _voltageLoading = true;
  bool _alertsLoading = true;
  int _voltageHours = 24; // selected time range for voltage chart

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant MapDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.node.nodeId != widget.node.nodeId ||
        oldWidget.state != widget.state) {
      _loadData();
    }
  }

  void _loadData() {
    final nodeId = widget.node.nodeId;
    final isCattle = widget.state == MapViewState.cattleSelected;
    if (isCattle) {
      _loadCattleData(nodeId);
    } else {
      _loadFenceData(nodeId, hours: _voltageHours);
    }
  }

  Future<void> _loadCattleData(int nodeId) async {
    setState(() {
      _behaviorLoading = true;
      _eventsLoading = true;
    });

    final herdState = context.read<HerdState>();
    final backend = herdState.backend;

    // Load behavior summary and geofence events in parallel
    final results = await Future.wait([
      herdState.getBehaviorSummaryForNode(nodeId).catchError((_) => null),
      backend.getGeofenceEvents(nodeId: nodeId, limit: 10).catchError((_) => <GeofenceEvent>[]),
    ]);

    if (!mounted) return;
    setState(() {
      _behaviorSummary = results[0] as BehaviorSummary?;
      _geofenceEvents = results[1] as List<GeofenceEvent>;
      _behaviorLoading = false;
      _eventsLoading = false;
    });
  }

  Future<void> _loadFenceData(int nodeId, {int? hours}) async {
    setState(() => _voltageLoading = true);
    if (hours != null) {
      setState(() => _alertsLoading = true);
    }

    final backend = context.read<HerdState>().backend;
    final h = hours ?? _voltageHours;
    // Use finer resolution for shorter ranges
    final everyMin = h <= 6 ? 1 : h <= 12 ? 2 : 5;

    final futures = [
      backend.getFenceHistory(nodeId, hours: h, everyMinutes: everyMin)
          .catchError((_) => <NodeHistoryPoint>[]),
      if (hours != null)
        backend.getNodeAlerts(nodeId, limit: 10).catchError((_) => <AlertModel>[]),
    ];

    final results = await Future.wait(futures);

    if (!mounted) return;
    setState(() {
      _voltageHistory = results[0] as List<NodeHistoryPoint>;
      if (results.length > 1) {
        _nodeAlerts = results[1] as List<AlertModel>;
        _alertsLoading = false;
      }
      _voltageLoading = false;
    });
  }

  void _onVoltageRangeChanged(int hours) {
    if (_voltageHours == hours) return;
    setState(() => _voltageHours = hours);
    _loadFenceData(widget.node.nodeId, hours: hours);
  }

  NodeModel get node => widget.node;

  String _lastSeen() {
    final diff = DateTime.now().difference(node.lastUpdated);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Color _statusColor() {
    if (node.hasVoltageFault) return Colors.redAccent;
    if (!node.isRecent) return Colors.grey;
    if (node.batteryLevel < 20) return Colors.orange;
    return Colors.greenAccent;
  }

  String _statusLabel() {
    if (node.hasVoltageFault) return 'FENCE FAULT';
    if (!node.isRecent) return 'OFFLINE';
    if (node.batteryLevel < 20) return 'LOW BATTERY';
    return 'ACTIVE – ONLINE';
  }

  String _signalLabel(int? rssi) {
    if (rssi == null) return 'N/A';
    if (rssi >= -70) return 'Strong';
    if (rssi >= -85) return 'Good';
    if (rssi >= -100) return 'Weak';
    return 'Very Weak';
  }

  int _signalBars(int? rssi) {
    if (rssi == null) return 0;
    if (rssi >= -70) return 4;
    if (rssi >= -85) return 3;
    if (rssi >= -100) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCattle = widget.state == MapViewState.cattleSelected;

    return Container(
      width: 384,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : MooColors.surfaceLight,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
        border: Border(
            left: BorderSide(
                color: isDark ? const Color(0xFF334155) : MooColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context, isCattle),
          Expanded(
            child: isCattle
                ? _buildCattleBody(context, l10n, isDark)
                : _buildFenceBody(context, l10n, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isCattle) {
    final statusColor = _statusColor();
    final statusLabel = _statusLabel();
    final subtitle = isCattle
        ? [node.breed, node.age != null ? '${node.age} Yrs' : null]
            .whereType<String>()
            .join(' · ')
        : node.locationDescription;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        'Last seen ${_lastSeen()}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: widget.onClose,
                color: Colors.grey.shade500,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isCattle)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 13, color: Colors.orange),
                  SizedBox(width: 4),
                  Text('Fence Node',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
            ),
          Text(
            node.getName(),
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (subtitle.isNotEmpty)
            Text(subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
          const SizedBox(height: 16),
          if (!isCattle) ...[
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Battery',
                    value: '${node.batteryLevel}%',
                    icon: Icons.battery_charging_full,
                    color: _batteryColor(node.batteryLevel),
                    progress: node.batteryLevel / 100,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RealSignalCard(
                    label: 'Signal',
                    rssi: node.rssi,
                    signalLabel: _signalLabel(node.rssi),
                    bars: _signalBars(node.rssi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Builder(builder: (context) {
              final faultColor = node.hasVoltageFault ? Colors.redAccent : Colors.green;
              return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: faultColor.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: faultColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: faultColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt, color: node.hasVoltageFault ? Colors.redAccent : Colors.greenAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fence Status',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                      Text(
                        node.hasVoltageFault
                            ? 'FAULT · ${node.voltage != null ? '${(node.voltage! / 1000).toStringAsFixed(1)} kV' : 'No data'}'
                            : node.voltage != null
                                ? 'Energized · ${(node.voltage! / 1000).toStringAsFixed(1)} kV'
                                : 'Energized',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: node.hasVoltageFault
                                ? Colors.redAccent
                                : Colors.greenAccent),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Coords',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      Text(
                        '${node.latitude.toStringAsFixed(4)} · ${node.longitude.toStringAsFixed(4)}',
                        style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ],
              ),
            );
            }),
            const SizedBox(height: 8),
          ]
        ],
      ),
    );
  }

  Color _batteryColor(int level) {
    if (level >= 60) return Colors.greenAccent;
    if (level >= 30) return Colors.orange;
    return Colors.redAccent;
  }

  Widget _buildCattleBody(BuildContext context, dynamic l10n, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Battery',
                value: '${node.batteryLevel}%',
                icon: Icons.battery_full,
                color: _batteryColor(node.batteryLevel),
                progress: node.batteryLevel / 100,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _RealSignalCard(
                label: 'Signal',
                rssi: node.rssi,
                signalLabel: _signalLabel(node.rssi),
                bars: _signalBars(node.rssi),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: node.photoUrl != null && node.photoUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: node.photoUrl!,
                  height: 176,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _photoPlaceholder(),
                  errorWidget: (_, __, ___) => _photoPlaceholder(),
                )
              : _photoPlaceholder(),
        ),
        const SizedBox(height: 20),
        const Text('Daily Behavior',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _buildBehaviorSection(),
        const SizedBox(height: 20),
        const Text('Geofence Events (Last 24h)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        _buildGeofenceEventsSection(),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: widget.onOpenConfig,
          icon: const Icon(Icons.settings, size: 20),
          label: Text(l10n.remoteConfig),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            backgroundColor: MooColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBehaviorSection() {
    if (_behaviorLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
          ),
        ),
      );
    }

    if (_behaviorSummary == null || _behaviorSummary!.totalMinutes == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          'No behavior data available',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          textAlign: TextAlign.center,
        ),
      );
    }

    final s = _behaviorSummary!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        children: [
          _BehaviorBar(
              label: 'Resting',
              value: s.restingPercent.round(),
              color: Colors.blue,
              hours: s.restingHours),
          const SizedBox(height: 12),
          _BehaviorBar(
              label: 'Moving',
              value: s.movingPercent.round(),
              color: Colors.orange,
              hours: s.movingHours),
          const SizedBox(height: 12),
          _BehaviorBar(
              label: 'Grazing',
              value: s.grazingPercent.round(),
              color: Colors.green,
              hours: s.grazingHours),
          const SizedBox(height: 12),
          _BehaviorBar(
              label: 'Ruminating',
              value: s.ruminatingPercent.round(),
              color: Colors.purple,
              hours: s.ruminatingHours),
          if (s.feedingMinutes > 0) ...[
            const SizedBox(height: 12),
            _BehaviorBar(
                label: 'Feeding',
                value: s.feedingPercent.round(),
                color: Colors.teal,
                hours: s.feedingHours),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Total: ${s.totalHours.toStringAsFixed(1)}h tracked today',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeofenceEventsSection() {
    if (_eventsLoading) {
      return const Center(
        child: SizedBox(
          height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
        ),
      );
    }

    // Filter to last 24h
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = _geofenceEvents
        .where((e) => e.eventTime.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.eventTime.compareTo(a.eventTime));

    if (recent.isEmpty) {
      return Text(
        'No geofence events in the last 24h',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF334155), width: 2)),
      ),
      child: Column(
        children: recent.take(5).map((e) {
          final isExit = e.type == 'exit';
          final fenceName = e.geofenceName ?? 'Geofence ${e.geofenceId}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _TimelineEvent(
              title: '${isExit ? 'Exited' : 'Entered'} $fenceName',
              time: _formatEventTime(e.eventTime),
              color: isExit ? Colors.redAccent : Colors.greenAccent,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _formatEventTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) {
      return 'Today, ${DateFormat.jm().format(dt)}';
    }
    if (diff.inHours < 48) {
      return 'Yesterday, ${DateFormat.jm().format(dt)}';
    }
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Widget _buildFenceBody(BuildContext context, dynamic l10n, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Voltage over time',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            Row(
              children: [6, 12, 24, 48].map((h) {
                final active = _voltageHours == h;
                return GestureDetector(
                  onTap: () => _onVoltageRangeChanged(h),
                  child: Container(
                    margin: const EdgeInsets.only(left: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFF334155) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: active ? const Color(0xFF475569) : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      '${h}h',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.grey.shade300 : Colors.grey.shade500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildVoltageChart(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Latest Events',
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            TextButton(
              onPressed: () {},
              child: const Text('View All',
                  style: TextStyle(fontSize: 12, color: MooColors.primary)),
            ),
          ],
        ),
        _buildFenceEventsSection(),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: widget.onOpenConfig,
          icon: const Icon(Icons.settings_remote, size: 18),
          label: Text(l10n.remoteConfig),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: MooColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NodePlacementPage(newNodes: [widget.node]),
              ),
            );
            // Refresh node data after returning from placement
            if (context.mounted) {
              context.read<HerdState>().loadNodesAndGeofences();
            }
          },
          icon: const Icon(Icons.edit_location_alt, size: 18),
          label: const Text('Edit Map Placement'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.orangeAccent,
            side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildVoltageChart() {
    if (_voltageLoading) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Center(
          child: SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
          ),
        ),
      );
    }

    final voltagePoints = _voltageHistory
        .where((p) => p.voltage != null && p.voltage! > 0)
        .toList();

    if (voltagePoints.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Center(
          child: Text('No voltage data available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        ),
      );
    }

    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        size: const Size(double.infinity, 128),
        painter: _VoltageChartPainter(voltagePoints),
      ),
    );
  }

  Widget _buildFenceEventsSection() {
    if (_alertsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(
            height: 20, width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
          ),
        ),
      );
    }

    // Only show unresolved alerts, most recent first
    final events = _nodeAlerts
        .where((a) => !a.resolved)
        .take(5)
        .toList();

    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No recent events',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      children: events.map((alert) {
        IconData icon;
        Color color;
        switch (alert.type) {
          case AlertType.fenceVoltageFailure:
          case AlertType.fenceVoltageDropped:
            icon = Icons.bolt;
            color = Colors.redAccent;
            break;
          case AlertType.nodeLowBattery:
            icon = Icons.battery_alert;
            color = Colors.orangeAccent;
            break;
          case AlertType.nodeOffline:
            icon = Icons.power_off;
            color = Colors.redAccent;
            break;
          default:
            icon = Icons.info_outline;
            color = Colors.blueAccent;
        }
        return _buildEventItem(
          icon,
          color,
          alert.title,
          alert.body,
          _formatEventTime(alert.timestamp),
        );
      }).toList(),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 176,
      width: double.infinity,
      color: const Color(0xFF1E293B),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_camera, size: 48, color: Color(0xFF475569)),
          const SizedBox(height: 8),
          Text('No photo available',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildEventItem(
      IconData icon, Color color, String title, String subtitle, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Text(time,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress;

  const _MetricCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color,
      this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF334155),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ]
        ],
      ),
    );
  }
}

class _RealSignalCard extends StatelessWidget {
  final String label;
  final int? rssi;
  final String signalLabel;
  final int bars;

  const _RealSignalCard({
    required this.label,
    required this.rssi,
    required this.signalLabel,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = bars >= 3
        ? Colors.greenAccent
        : bars >= 2
            ? Colors.orange
            : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.signal_cellular_alt,
                  size: 15, color: bars > 0 ? barColor : Colors.grey),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            ],
          ),
          const SizedBox(height: 6),
          Text(signalLabel,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          if (rssi != null)
            Text('${rssi} dBm',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final active = i < bars;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 2 : 0),
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? barColor : const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _BehaviorBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final double hours;

  const _BehaviorBar({
    required this.label,
    required this.value,
    required this.color,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
            Text('$value% (${hours.toStringAsFixed(1)}h)',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            backgroundColor: const Color(0xFF334155),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _TimelineEvent extends StatelessWidget {
  final String title;
  final String time;
  final Color color;

  const _TimelineEvent({required this.title, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -21,
          top: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF0F172A), width: 2),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(time,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }
}

/// Draws a real voltage chart from InfluxDB history data.
class _VoltageChartPainter extends CustomPainter {
  final List<NodeHistoryPoint> points;

  _VoltageChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chartHeight = size.height - 20; // leave room for labels
    final chartWidth = size.width;

    // Find voltage range
    final voltages = points.map((p) => p.voltage!).toList();
    final maxV = voltages.reduce((a, b) => a > b ? a : b);
    final minV = voltages.reduce((a, b) => a < b ? a : b);
    final range = maxV - minV;
    final paddedMin = range > 0 ? minV - range * 0.1 : minV - 500;
    final paddedMax = range > 0 ? maxV + range * 0.1 : maxV + 500;
    final vRange = paddedMax - paddedMin;

    // Time range
    final startTime = points.first.time.millisecondsSinceEpoch.toDouble();
    final endTime = points.last.time.millisecondsSinceEpoch.toDouble();
    final tRange = endTime - startTime;
    if (tRange <= 0) return;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF334155)
      ..strokeWidth = 0.5;
    for (int i = 0; i < 3; i++) {
      final y = chartHeight * i / 2;
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);
    }

    // Build path
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = ((points[i].time.millisecondsSinceEpoch - startTime) / tRange) * chartWidth;
      final y = chartHeight - ((points[i].voltage! - paddedMin) / vRange) * chartHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Fill under line
    final fillPath = Path.from(path);
    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.lineTo(0, chartHeight);
    fillPath.close();

    // Detect fault regions (below 5kV threshold)
    final hasFault = voltages.any((v) => v < 5000);

    final lineColor = hasFault ? Colors.orange : Colors.brown;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [lineColor.withValues(alpha: 0.3), lineColor.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw fault threshold line at 5kV if visible
    if (paddedMin < 5000 && paddedMax > 5000) {
      final thresholdY = chartHeight - ((5000 - paddedMin) / vRange) * chartHeight;
      final thresholdPaint = Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.5)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, thresholdY), Offset(chartWidth, thresholdY), thresholdPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '5 kV',
          style: TextStyle(fontSize: 9, color: Colors.redAccent.withValues(alpha: 0.7)),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(chartWidth - textPainter.width - 2, thresholdY - 12));
    }

    // Current value dot
    if (points.isNotEmpty) {
      final lastX = chartWidth;
      final lastY = chartHeight - ((points.last.voltage! - paddedMin) / vRange) * chartHeight;
      canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = lineColor);
      canvas.drawCircle(Offset(lastX, lastY), 1.8, Paint()..color = Colors.white);
    }

    // Y-axis labels (min/max voltage in kV)
    final labelStyle = TextStyle(fontSize: 9, color: Colors.grey.shade500);
    final topLabel = TextPainter(
      text: TextSpan(text: '${(paddedMax / 1000).toStringAsFixed(1)} kV', style: labelStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    topLabel.paint(canvas, const Offset(0, 0));

    final bottomLabel = TextPainter(
      text: TextSpan(text: '${(paddedMin / 1000).toStringAsFixed(1)} kV', style: labelStyle),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    bottomLabel.paint(canvas, Offset(0, chartHeight - bottomLabel.height));

    // Time labels
    final timeStart = DateFormat.Hm().format(points.first.time);
    final timeEnd = DateFormat.Hm().format(points.last.time);

    final startLabel = TextPainter(
      text: TextSpan(text: timeStart, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    startLabel.paint(canvas, Offset(0, size.height - startLabel.height));

    final endLabel = TextPainter(
      text: TextSpan(text: timeEnd, style: TextStyle(fontSize: 9, color: Colors.orange.shade300, fontWeight: FontWeight.bold)),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    endLabel.paint(canvas, Offset(chartWidth - endLabel.width, size.height - endLabel.height));
  }

  @override
  bool shouldRepaint(covariant _VoltageChartPainter oldDelegate) =>
      oldDelegate.points != points;
}
