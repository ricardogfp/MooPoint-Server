import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'package:moo_point/services/ble/ble_provision_service.dart';
import 'package:moo_point/presentation/pages/ble/ble_provision_page.dart';
import 'package:moo_point/services/api/node_backend_admin_service.dart';

class BleProvisioningMenu extends StatefulWidget {
  const BleProvisioningMenu({super.key});

  @override
  State<BleProvisioningMenu> createState() => _BleProvisioningMenuState();
}

class _BleProvisioningMenuState extends State<BleProvisioningMenu> {
  final BLEProvisionService _ble = BLEProvisionService();
  final NodeBackendAdminService _admin = NodeBackendAdminService();

  String _status = 'Initializing...';
  List<ScanResult> _devices = [];
  bool _connected = false;
  bool _loading = false;
  bool _provisioned = false;

  // Current tracker config read from device
  Map<String, dynamic>? _trackerConfig;

  // Provisioning fields
  int? _nodeId;
  int? _generatedDeviceId;
  String? _generatedDeviceKey;

  @override
  void initState() {
    super.initState();

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _status = 'BLE provisioning is available only on Android app builds';
      return;
    }

    _ble.onStatusChanged = (s) {
      if (!mounted) return;
      setState(() => _status = s);
    };

    _ble.devicesStream.listen((d) {
      if (!mounted) return;
      setState(() => _devices = d);
    });

    _initialize();
  }

  Future<void> _initialize() async {
    final ok = await _ble.initialize();
    if (!ok) {
      setState(() => _status = 'BLE initialization failed');
      return;
    }
    await _ble.startScanning();
  }

  @override
  void dispose() {
    _ble.dispose();
    _admin.dispose();
    super.dispose();
  }

  Future<void> _connect(ScanResult r) async {
    setState(() {
      _loading = true;
      _status = 'Connecting...';
      _provisioned = false;
      _trackerConfig = null;
      _generatedDeviceId = null;
      _generatedDeviceKey = null;
    });

    final ok = await _ble.connect(r.device);
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _loading = false;
        _connected = false;
      });
      return;
    }

    setState(() => _connected = true);

    // Read current config
    try {
      setState(() => _status = 'Reading tracker config...');
      final jsonStr = await _ble.getConfigJson();
      final config = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _trackerConfig = config;
        _nodeId = config['node_id'] is int
            ? config['node_id']
            : int.tryParse(config['node_id']?.toString() ?? '');
        _loading = false;
        _status = 'Connected - Ready to provision';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Config read failed: $e';
      });
    }
  }

  /// Generate a random 32-bit device_id (non-zero)
  int _generateDeviceId() {
    final rng = Random.secure();
    // Generate a random positive 32-bit integer (fits uint32_t on tracker/gateway)
    return (rng.nextInt(0x7FFFFFFF) + 1); // 1 .. 2^31-1
  }

  /// Generate a random 32-byte (256-bit) device_key as a 64-char hex string
  String _generateDeviceKey() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _provision() async {
    setState(() {
      _loading = true;
      _status = 'Getting next available node_id...';
      _provisioned = false;
    });

    try {
      // Step 1: Get next available node_id from server
      final nodeId = await _ble.provisionNextNodeId();
      setState(() {
        _nodeId = nodeId;
        _status = 'Generating credentials...';
      });

      final deviceId = _generateDeviceId();
      final deviceKey = _generateDeviceKey();

      setState(() {
        _generatedDeviceId = deviceId;
        _generatedDeviceKey = deviceKey;
      });

      // Step 2: Send node_id to tracker via BLE
      setState(() => _status = 'Setting node_id on tracker...');
      var resp = await _ble.sendJsonCommand({
        'cmd': 'set',
        'node_id': nodeId,
      });
      if (resp['status'] != 'ok') {
        throw StateError('SET node_id failed: ${resp['msg'] ?? resp}');
      }

      // Step 3: Send device_id + device_key to tracker via BLE
      setState(() => _status = 'Setting device credentials on tracker...');
      resp = await _ble.sendJsonCommand({
        'cmd': 'set',
        'device_id': deviceId,
        'device_key': deviceKey,
      });
      if (resp['status'] != 'ok') {
        throw StateError(
            'SET device credentials failed: ${resp['msg'] ?? resp}');
      }

      // Step 4: Save to tracker flash
      setState(() => _status = 'Saving to tracker flash...');
      await _ble.saveConfig();

      // Step 5: Store credentials on server DB
      setState(() => _status = 'Storing credentials on server...');
      await _admin.setNodeDeviceCredentials(
        nodeId,
        deviceId: deviceId,
        deviceKey: deviceKey,
      );

      // Step 6: Publish device map to gateway
      setState(() => _status = 'Publishing device map to gateway...');
      try {
        await _admin.publishDeviceMap();
      } catch (e) {
        debugPrint('Device map publish warning: $e');
        // Non-fatal: credentials are saved, gateway will get map on next boot
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        _provisioned = true;
        _status = 'Provisioning complete!';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Node $_nodeId provisioned successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _status = 'Provisioning failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Provisioning failed: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _disconnect() async {
    await _ble.disconnect();
    if (!mounted) return;
    setState(() {
      _connected = false;
      _trackerConfig = null;
      _provisioned = false;
      _generatedDeviceId = null;
      _generatedDeviceKey = null;
    });
    await _ble.startScanning();
  }

  Widget _buildScanView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(_status,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
              ),
              IconButton(
                icon: Icon(_ble.isScanning ? Icons.stop : Icons.search),
                onPressed: _ble.isScanning
                    ? () => _ble.stopScanning()
                    : () => _ble.startScanning(),
                tooltip: _ble.isScanning ? 'Stop scan' : 'Scan',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_devices.isEmpty)
          const Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Searching for trackers in config mode...',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hold the user button during tracker boot\nto enter config mode',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, i) {
                final r = _devices[i];
                final name = r.device.platformName.isNotEmpty
                    ? r.device.platformName
                    : (r.advertisementData.advName.isNotEmpty
                        ? r.advertisementData.advName
                        : r.device.remoteId.str);
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    title: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle:
                        Text('RSSI: ${r.rssi} dBm\n${r.device.remoteId.str}'),
                    isThreeLine: true,
                    trailing: ElevatedButton.icon(
                      onPressed: () => _connect(r),
                      icon: const Icon(Icons.link),
                      label: const Text('Connect'),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProvisionView() {
    final config = _trackerConfig;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status bar
          Card(
            color: _provisioned ? Colors.green[50] : Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    _provisioned ? Icons.check_circle : Icons.info_outline,
                    color: _provisioned ? Colors.green : Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color:
                            _provisioned ? Colors.green[800] : Colors.blue[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Current tracker info
          const Text('Tracker Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (config != null) ...[
            _infoRow('Node ID', '${config['node_id'] ?? 'N/A'}'),
            _infoRow('Device ID', '${config['device_id'] ?? 'N/A'}'),
            _infoRow(
                'Device Key', _truncateKey(config['device_key']?.toString())),
            _infoRow('LoRa Freq', '${config['lora_freq'] ?? 'N/A'} MHz'),
            _infoRow('LoRa SF', '${config['lora_sf'] ?? 'N/A'}'),
            _infoRow('LoRa Power', '${config['lora_power'] ?? 'N/A'} dBm'),
          ] else
            const Text('No config loaded',
                style: TextStyle(color: Colors.grey)),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Provisioning section
          const Text('Provision Device',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Automatically assign the next available node_id, and generate a unique '
            'device_id and device_key for this tracker. All credentials will be '
            'sent to the tracker via BLE, saved to flash, stored on the server, '
            'and pushed to the gateway.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          if (_generatedDeviceId != null) ...[
            if (_nodeId != null) _infoRow('New Node ID', '$_nodeId'),
            _infoRow('New Device ID', '$_generatedDeviceId'),
            _infoRow('New Device Key', _truncateKey(_generatedDeviceKey)),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _provision,
              icon: const Icon(Icons.vpn_key),
              label: Text(_provisioned ? 'Re-provision' : 'Provision Tracker'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Additional actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BleProvisionPage()),
                          );
                        },
                  icon: const Icon(Icons.settings),
                  label: const Text('Advanced Config'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _disconnect,
                  icon: const Icon(Icons.bluetooth_disabled),
                  label: const Text('Disconnect'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Firmware info display (read-only)
          if (_trackerConfig != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            _infoRow('Current Firmware',
                _trackerConfig!['firmware_version']?.toString() ?? 'Unknown'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Firmware Updates',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Firmware updates are performed via USB using the UF2 bootloader. Double-tap the RESET button to enter bootloader mode, then copy the firmware.hex file to the USB drive.',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _status = 'Rebooting tracker...';
                      });
                      try {
                        await _ble.reboot();
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _status = 'Reboot command sent';
                        });
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _status = 'Reboot failed: $e';
                        });
                      }
                    },
              icon: const Icon(Icons.restart_alt, color: Colors.red),
              label: const Text('Reboot Tracker',
                  style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateKey(String? key) {
    if (key == null || key.isEmpty) return 'N/A';
    if (key.length <= 16) return key;
    return '${key.substring(0, 8)}...${key.substring(key.length - 8)}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker Provisioning'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (_connected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _status = 'Re-reading config...';
                      });
                      try {
                        final jsonStr = await _ble.getConfigJson();
                        final config =
                            jsonDecode(jsonStr) as Map<String, dynamic>;
                        if (!mounted) return;
                        setState(() {
                          _trackerConfig = config;
                          _nodeId = config['node_id'] is int
                              ? config['node_id']
                              : int.tryParse(
                                  config['node_id']?.toString() ?? '');
                          _loading = false;
                          _status = 'Config refreshed';
                        });
                      } catch (e) {
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _status = 'Refresh failed: $e';
                        });
                      }
                    },
              tooltip: 'Refresh config',
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_status, textAlign: TextAlign.center),
                ],
              ),
            )
          : _connected
              ? _buildProvisionView()
              : _buildScanView(),
    );
  }
}
