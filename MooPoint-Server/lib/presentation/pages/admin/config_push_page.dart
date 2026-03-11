import 'package:flutter/material.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';

class ConfigPushPage extends StatefulWidget {
  const ConfigPushPage({super.key});

  @override
  State<ConfigPushPage> createState() => _ConfigPushPageState();
}

class _ConfigPushPageState extends State<ConfigPushPage> {
  final NodeBackendAdminService _admin = NodeBackendAdminService();

  List<Map<String, dynamic>> _nodes = [];
  final Set<int> _selectedNodes = {};
  final List<int> _gatewayIds = [1]; // Default gateway
  bool _loading = false;
  String? _requestId;
  final Map<int, String> _nodeStatus = {};
  String? _errorMessage;

  // Config form fields
  final _loraFreqController = TextEditingController(text: '868.0');
  final _loraSfController = TextEditingController(text: '9');
  final _loraBwController = TextEditingController(text: '125.0');
  final _loraPowerController = TextEditingController(text: '14');
  final _cycle1SleepController = TextEditingController(text: '5');
  final _cycle2SleepController = TextEditingController(text: '10');
  final _cycle3SleepController = TextEditingController(text: '30');
  final _cycle4SleepController = TextEditingController(text: '60');
  final _minSatsController = TextEditingController(text: '4');
  final _maxHdopController = TextEditingController(text: '4.0');

  bool _enableDeepSleep = true;
  bool _enableDisplay = false;
  bool _enableBleLocate = true;
  bool _enableGeofenceAlerts = true;
  bool _enableDebug = false;
  bool _enableGpsSimulator = false;
  bool _enableExtendedMetrics = false;
  bool _enableBehaviorDetection = true;

  @override
  void initState() {
    super.initState();
    _loadNodes();
  }

  @override
  void dispose() {
    _loraFreqController.dispose();
    _loraSfController.dispose();
    _loraBwController.dispose();
    _loraPowerController.dispose();
    _cycle1SleepController.dispose();
    _cycle2SleepController.dispose();
    _cycle3SleepController.dispose();
    _cycle4SleepController.dispose();
    _minSatsController.dispose();
    _maxHdopController.dispose();
    _admin.dispose();
    super.dispose();
  }

  Future<void> _loadNodes() async {
    debugPrint('ConfigPushPage: Loading nodes...');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      debugPrint('ConfigPushPage: Calling listNodes()...');
      final nodes = await _admin.listNodes();
      debugPrint('ConfigPushPage: Received ${nodes.length} nodes');
      if (!mounted) return;
      setState(() {
        _nodes = nodes;
        _loading = false;
        _errorMessage = null;
      });
      debugPrint('ConfigPushPage: State updated successfully');
    } catch (e, stackTrace) {
      debugPrint('ConfigPushPage: Error loading nodes: $e');
      debugPrint('ConfigPushPage: Stack trace: $stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load nodes: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to load nodes: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pushConfig() async {
    debugPrint(
        'ConfigPushPage: Push button clicked, selected nodes: ${_selectedNodes.toList()}');
    if (_selectedNodes.isEmpty) {
      debugPrint('ConfigPushPage: No nodes selected, showing error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tracker')),
      );
      return;
    }
    debugPrint('ConfigPushPage: Starting config push...');

    setState(() => _loading = true);

    try {
      // Build config object
      final config = {
        'lora': {
          'frequency': double.parse(_loraFreqController.text),
          'bandwidth': double.parse(_loraBwController.text),
          'spreading_factor': int.parse(_loraSfController.text),
          'power': int.parse(_loraPowerController.text),
        },
        'power': {
          'cycle1_sleep_min': int.parse(_cycle1SleepController.text),
          'cycle2_sleep_min': int.parse(_cycle2SleepController.text),
          'cycle3_sleep_min': int.parse(_cycle3SleepController.text),
          'cycle4_sleep_min': int.parse(_cycle4SleepController.text),
        },
        'gps': {
          'min_satellites': int.parse(_minSatsController.text),
          'max_hdop': double.parse(_maxHdopController.text),
        },
        'features': {
          'enable_deep_sleep': _enableDeepSleep,
          'enable_display': _enableDisplay,
          'enable_ble_locate': _enableBleLocate,
          'enable_geofence_alerts': _enableGeofenceAlerts,
          'enable_debug_mode': _enableDebug,
          'enable_gps_simulator': _enableGpsSimulator,
          'enable_extended_metrics': _enableExtendedMetrics,
          'enable_behavior_detection': _enableBehaviorDetection,
        },
      };

      // Push config
      final response = await _admin.pushConfig(
        _selectedNodes.toList(),
        _gatewayIds,
        config,
      );

      if (!mounted) return;

      setState(() {
        _requestId = response['requestId'];
        for (var nodeId in _selectedNodes) {
          _nodeStatus[nodeId] = 'pending';
        }
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Config push initiated (ID: $_requestId)'),
          backgroundColor: Colors.green,
        ),
      );

      // Start polling for status
      _pollStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Config push failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pollStatus() async {
    if (_requestId == null) return;

    for (int i = 0; i < 60; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      try {
        final status = await _admin.getConfigPushStatus(_requestId!);
        if (!mounted) return;

        setState(() {
          for (var item in status) {
            // Handle node_id as either int or string
            final nodeIdRaw = item['node_id'];
            final nodeId = nodeIdRaw is int
                ? nodeIdRaw
                : (nodeIdRaw is String ? int.tryParse(nodeIdRaw) : null);

            if (nodeId == null) continue; // Skip invalid entries

            final statusStr = item['status'] as String;
            _nodeStatus[nodeId] = statusStr;
          }
        });

        // Check if all complete
        final allComplete = _nodeStatus.values.every(
          (s) => s == 'confirmed' || s == 'failed',
        );
        if (allComplete) break;
      } catch (e) {
        debugPrint('Status poll error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Push Configuration'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadNodes,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _loading && _nodes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Loading trackers...',
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrackerSelection(),
                      const SizedBox(height: 24),
                      _buildConfigForm(),
                      const SizedBox(height: 24),
                      _buildPushButton(),
                      if (_requestId != null) ...[
                        const SizedBox(height: 24),
                        _buildStatusTable(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildTrackerSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Trackers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Test button to verify clicks work
            ElevatedButton(
              onPressed: () {
                debugPrint('ConfigPushPage: TEST BUTTON CLICKED!');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Test button works!')),
                );
              },
              child: const Text('TEST CLICK'),
            ),
            const SizedBox(height: 12),
            if (_nodes.isEmpty)
              Column(
                children: [
                  const Text('No trackers found',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Debug: Loading=$_loading, Error=$_errorMessage',
                      style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ElevatedButton(
                    onPressed: _loadNodes,
                    child: const Text('Reload'),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text('Found ${_nodes.length} trackers',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                  // Tracker checkboxes
                  ..._nodes.map((node) {
                    // Handle node_id as either int or string
                    final nodeIdRaw = node['node_id'];
                    final nodeId = nodeIdRaw is int
                        ? nodeIdRaw
                        : (nodeIdRaw is String
                            ? int.tryParse(nodeIdRaw)
                            : null);

                    if (nodeId == null) {
                      return const SizedBox.shrink(); // Skip invalid nodes
                    }

                    final name = node['friendly_name'] ?? 'Node $nodeId';
                    final isSelected = _selectedNodes.contains(nodeId);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: Colors.grey.shade300, width: 2),
                          borderRadius: BorderRadius.circular(8),
                          color:
                              isSelected ? Colors.blue.shade50 : Colors.white,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (checked) {
                                  debugPrint(
                                      'ConfigPushPage: Checkbox changed for node $nodeId, checked=$checked');
                                  debugPrint(
                                      'ConfigPushPage: Before change, selected nodes: ${_selectedNodes.toList()}');
                                  setState(() {
                                    if (checked == true) {
                                      _selectedNodes.add(nodeId);
                                    } else {
                                      _selectedNodes.remove(nodeId);
                                    }
                                  });
                                  debugPrint(
                                      'ConfigPushPage: After change, selected nodes: ${_selectedNodes.toList()}');
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Text('Node ID: $nodeId',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // LoRa Settings
            const Text('LoRa Settings',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loraFreqController,
                    decoration: const InputDecoration(
                      labelText: 'Frequency (MHz)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _loraSfController,
                    decoration: const InputDecoration(
                      labelText: 'Spreading Factor',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _loraBwController,
                    decoration: const InputDecoration(
                      labelText: 'Bandwidth (kHz)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _loraPowerController,
                    decoration: const InputDecoration(
                      labelText: 'TX Power (dBm)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Power Management
            const Text('Power Management (Sleep Minutes)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cycle1SleepController,
                    decoration: const InputDecoration(
                      labelText: 'Normal',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cycle2SleepController,
                    decoration: const InputDecoration(
                      labelText: 'Power Save',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cycle3SleepController,
                    decoration: const InputDecoration(
                      labelText: 'Low Battery',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cycle4SleepController,
                    decoration: const InputDecoration(
                      labelText: 'Critical',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // GPS Settings
            const Text('GPS Settings',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minSatsController,
                    decoration: const InputDecoration(
                      labelText: 'Min Satellites',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxHdopController,
                    decoration: const InputDecoration(
                      labelText: 'Max HDOP',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Feature Flags
            const Text('Features',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFeatureChip('Deep Sleep', _enableDeepSleep,
                    (v) => setState(() => _enableDeepSleep = v)),
                _buildFeatureChip('Display', _enableDisplay,
                    (v) => setState(() => _enableDisplay = v)),
                _buildFeatureChip('BLE Locate', _enableBleLocate,
                    (v) => setState(() => _enableBleLocate = v)),
                _buildFeatureChip('Geofence Alerts', _enableGeofenceAlerts,
                    (v) => setState(() => _enableGeofenceAlerts = v)),
                _buildFeatureChip('Debug Mode', _enableDebug,
                    (v) => setState(() => _enableDebug = v)),
                _buildFeatureChip('GPS Simulator', _enableGpsSimulator,
                    (v) => setState(() => _enableGpsSimulator = v)),
                _buildFeatureChip('Extended Metrics', _enableExtendedMetrics,
                    (v) => setState(() => _enableExtendedMetrics = v)),
                _buildFeatureChip(
                    'Behavior Detection',
                    _enableBehaviorDetection,
                    (v) => setState(() => _enableBehaviorDetection = v)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String label, bool value, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: Colors.blue[200],
    );
  }

  Widget _buildPushButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _pushConfig,
        icon: const Icon(Icons.send),
        label: Text(_loading ? 'Pushing...' : 'Push Configuration'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[700],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildStatusTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Push Status (Request: $_requestId)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Table(
              border: TableBorder.all(color: Colors.grey[300]!),
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey[200]),
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Node ID',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ..._nodeStatus.entries.map((entry) {
                  final status = entry.value;
                  Color statusColor = Colors.grey;
                  if (status == 'confirmed') statusColor = Colors.green;
                  if (status == 'failed') statusColor = Colors.red;
                  if (status == 'sent') statusColor = Colors.orange;

                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Node ${entry.key}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Icon(
                              status == 'confirmed'
                                  ? Icons.check_circle
                                  : status == 'failed'
                                      ? Icons.error
                                      : status == 'sent'
                                          ? Icons.schedule
                                          : Icons.pending,
                              size: 16,
                              color: statusColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status,
                              style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
