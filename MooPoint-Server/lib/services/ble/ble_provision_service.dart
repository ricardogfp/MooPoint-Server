import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:moo_point/services/api/node_backend_config.dart';
import 'package:moo_point/services/api/node_backend_http_client.dart';

class BLEProvisionService {
  static final BLEProvisionService _instance = BLEProvisionService._internal();
  factory BLEProvisionService() => _instance;
  BLEProvisionService._internal();

  static final Guid serviceUuid = Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid rxUuid = Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e');
  static final Guid txUuid = Guid('6e400003-b5a3-f393-e0a9-e50e24dcca9e');

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  Timer? _scanTimer;

  final StreamController<List<ScanResult>> _devicesController =
      StreamController.broadcast();
  Stream<List<ScanResult>> get devicesStream => _devicesController.stream;

  Function(String)? onStatusChanged;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  BluetoothDevice? get connectedDevice => _connectedDevice;

  Future<bool> initialize() async {
    try {
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
        onStatusChanged
            ?.call('BLE provisioning is available only on Android app builds');
        return false;
      }

      await _requestPermissions();

      if (!await FlutterBluePlus.isSupported) {
        onStatusChanged?.call('Bluetooth not supported');
        return false;
      }

      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        onStatusChanged?.call('Bluetooth disabled');
        return false;
      }

      onStatusChanged?.call('Ready');
      return true;
    } catch (e) {
      onStatusChanged?.call('Initialization failed: $e');
      return false;
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await Permission.locationWhenInUse.request();
  }

  bool _isTrackerDevice(ScanResult result) {
    final name = (result.device.platformName.isNotEmpty
            ? result.device.platformName
            : result.advertisementData.advName)
        .toLowerCase();
    if (name.contains('tracker') ||
        name.contains('lora-tracker') ||
        name.contains('cow') ||
        name.contains('mpt_') ||
        name.contains('moopoint')) {
      return true;
    }

    final uuids = result.advertisementData.serviceUuids;
    return uuids
        .any((u) => u.str.toLowerCase() == serviceUuid.str.toLowerCase());
  }

  Future<void> startScanning() async {
    if (_isScanning) return;
    _isScanning = true;
    onStatusChanged?.call('Scanning...');

    final Map<String, ScanResult> seen = {};

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        if (!_isTrackerDevice(r)) continue;
        final id = r.device.remoteId.str;
        if (!seen.containsKey(id) || (r.rssi > (seen[id]?.rssi ?? -999))) {
          seen[id] = r;
          changed = true;
        }
      }
      if (changed) {
        _devicesController.add(
            seen.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi)));
      }
    });

    try {
      if (await FlutterBluePlus.adapterState.first ==
          BluetoothAdapterState.off) {
        await FlutterBluePlus.turnOn();
      }

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
      _scanTimer = Timer(const Duration(seconds: 30), () {
        stopScanning();
      });
    } catch (e) {
      onStatusChanged?.call('Scan failed: $e');
      _isScanning = false;
    }
  }

  Future<void> stopScanning() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _scanSub?.cancel();
    _scanSub = null;
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    onStatusChanged?.call('Scan stopped');
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      onStatusChanged?.call(
          'Connecting to ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}');

      await device.connect(license: License.free);
      _connectedDevice = device;

      // Request larger MTU for bigger write payloads
      try {
        await device.requestMtu(256);
      } catch (_) {
        // MTU negotiation may fail on some devices, continue with default
      }

      final services = await device.discoverServices();
      final svc = services.where((s) => s.uuid == serviceUuid).toList();
      if (svc.isEmpty) {
        onStatusChanged?.call('Provisioning service not found');
        await disconnect();
        return false;
      }

      final chars = svc.first.characteristics;
      BluetoothCharacteristic? findChar(Guid uuid) {
        for (final c in chars) {
          if (c.uuid == uuid) return c;
        }
        return null;
      }

      _rx = findChar(rxUuid);
      _tx = findChar(txUuid);

      if (_rx == null || _tx == null) {
        onStatusChanged?.call('Provisioning characteristics not found');
        await disconnect();
        return false;
      }

      await _tx!.setNotifyValue(true);

      onStatusChanged?.call('Connected');
      return true;
    } catch (e) {
      onStatusChanged?.call('Connection failed: $e');
      return false;
    }
  }

  Future<String> getConfigJson(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_rx == null || _tx == null || _connectedDevice == null) {
      throw StateError('Not connected');
    }

    // Preferred (new) JSON protocol: {"cmd":"get"}
    try {
      final resp = await sendJsonCommand({'cmd': 'get'}, timeout: timeout);
      return jsonEncode(resp);
    } catch (_) {
      // Fallback to legacy protocol.
      return _getConfigJsonLegacy(timeout: timeout);
    }
  }

  Future<String> _getConfigJsonLegacy(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_rx == null || _tx == null || _connectedDevice == null) {
      throw StateError('Not connected');
    }

    final completer = Completer<String>();
    final bytes = <int>[];
    int? expected;
    bool headerDone = false;

    void tryParseHeader() {
      while (true) {
        final idx = bytes.indexOf(0x0A);
        if (idx < 0) return;

        final line = utf8.decode(bytes.sublist(0, idx)).trim();

        if (line.startsWith('ERR:')) {
          bytes.removeRange(0, idx + 1);
          if (!completer.isCompleted) {
            completer.completeError(StateError('GET failed: $line'));
          }
          return;
        }

        if (line.startsWith('LEN:')) {
          final n = int.tryParse(line.substring(4));
          if (n == null || n <= 0) {
            bytes.removeRange(0, idx + 1);
            continue;
          }
          expected = n;
          bytes.removeRange(0, idx + 1);
          headerDone = true;
          return;
        }

        // Discard unexpected line (e.g., stale JSON tail from a previous notify).
        bytes.removeRange(0, idx + 1);
      }
    }

    _notifySub?.cancel();
    _notifySub = _tx!.onValueReceived.listen((value) {
      if (completer.isCompleted) return;
      if (value.isEmpty) return;

      bytes.addAll(value);

      if (!headerDone) {
        tryParseHeader();
      }

      if (headerDone && expected != null && bytes.length >= expected!) {
        final payload = bytes.sublist(0, expected!);
        try {
          completer.complete(utf8.decode(payload));
        } catch (e) {
          completer.completeError(e);
        }
      }
    });

    await _rx!.write(utf8.encode('GET\n'), withoutResponse: true);

    return completer.future.timeout(timeout, onTimeout: () {
      throw TimeoutException('GET timeout');
    });
  }

  Future<void> setConfigJson(String json,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (_rx == null || _tx == null || _connectedDevice == null) {
      throw StateError('Not connected');
    }

    // Preferred (new) JSON protocol: {"cmd":"set", ...}
    try {
      final m = jsonDecode(json);
      if (m is! Map<String, dynamic>) {
        throw const FormatException('SET payload must be a JSON object');
      }
      final cmd = <String, dynamic>{'cmd': 'set', ...m};
      final resp = await sendJsonCommand(cmd, timeout: timeout);
      if (resp['status'] != 'ok') {
        throw StateError('SET failed: ${resp['msg'] ?? 'unknown error'}');
      }
      return;
    } catch (_) {
      // Fallback to legacy protocol.
      await _setConfigJsonLegacy(json, timeout: timeout);
    }
  }

  Future<void> _setConfigJsonLegacy(String json,
      {Duration timeout = const Duration(seconds: 15)}) async {
    if (_rx == null || _tx == null || _connectedDevice == null) {
      throw StateError('Not connected');
    }

    final data = utf8.encode(json);

    final ack1 = await _waitForAck(
        timeout: timeout,
        action: () async {
          await _rx!.write(utf8.encode('SET:${data.length}\n'),
              withoutResponse: false);
        });

    if (ack1 != 'OK') {
      throw StateError('SET rejected: $ack1');
    }

    const int chunk = 20;
    int off = 0;
    while (off < data.length) {
      final end = (off + chunk) > data.length ? data.length : (off + chunk);
      await _rx!.write(data.sublist(off, end), withoutResponse: false);
      off = end;
      await Future.delayed(const Duration(milliseconds: 10));
    }

    final ack2 = await _waitForAck(timeout: timeout, action: () async {});
    if (ack2 != 'OK') {
      throw StateError('SET failed: $ack2');
    }
  }

  Future<Map<String, dynamic>> sendJsonCommand(
    Map<String, dynamic> cmd, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_rx == null || _tx == null || _connectedDevice == null) {
      throw StateError('Not connected');
    }

    final payload = '${jsonEncode(cmd)}\n';
    debugPrint('📤 BLE TX: $payload');
    final resp = await _waitForJson(
        timeout: timeout,
        action: () async {
          await _writeChunked(utf8.encode(payload));
        });
    debugPrint('📥 BLE RX: $resp');
    return resp;
  }

  /// Write data in MTU-safe chunks (20 bytes each)
  Future<void> _writeChunked(List<int> data) async {
    const chunkSize = 20;
    for (var offset = 0; offset < data.length; offset += chunkSize) {
      final end =
          (offset + chunkSize > data.length) ? data.length : offset + chunkSize;
      await _rx!.write(data.sublist(offset, end), withoutResponse: true);
      if (end < data.length) {
        await Future.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  Future<void> saveConfig(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final resp = await sendJsonCommand({'cmd': 'save'}, timeout: timeout);
    if (resp['status'] != 'ok') {
      throw StateError('SAVE failed: ${resp['msg'] ?? 'unknown error'}');
    }
  }

  /// Provision the next available node_id from the server
  Future<int> provisionNextNodeId(
      {Duration timeout = const Duration(seconds: 10)}) async {
    final client = createNodeBackendHttpClient();

    try {
      final response = await client.post(
        Uri.parse('${NodeBackendConfig.baseUrl}/api/provision/node'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Handle nodeId as either int or string
        final nodeIdRaw = data['nodeId'];
        final nodeId = nodeIdRaw is int
            ? nodeIdRaw
            : (nodeIdRaw is String ? int.tryParse(nodeIdRaw) : null);

        if (nodeId == null) {
          throw StateError('Invalid nodeId returned from server');
        }

        onStatusChanged?.call('Node $nodeId provisioned successfully');
        return nodeId;
      } else if (response.statusCode == 409) {
        throw StateError('All node IDs are in use');
      } else {
        throw StateError('Provisioning failed: ${response.statusCode}');
      }
    } catch (e) {
      onStatusChanged?.call('Failed to provision node: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<void> loadProfile(String name,
      {Duration timeout = const Duration(seconds: 10)}) async {
    final resp = await sendJsonCommand({'cmd': 'profile', 'name': name},
        timeout: timeout);
    if (resp['status'] != 'ok') {
      throw StateError('PROFILE failed: ${resp['msg'] ?? 'unknown error'}');
    }
  }

  Future<Map<String, dynamic>> _waitForJson(
      {required Duration timeout,
      required Future<void> Function() action}) async {
    if (_tx == null) throw StateError('Not connected');

    final completer = Completer<Map<String, dynamic>>();
    final buf = <int>[];

    void tryCompleteWithString(String s) {
      if (completer.isCompleted) return;
      final trimmed = s.trim();
      if (!(trimmed.startsWith('{') || trimmed.startsWith('['))) return;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          completer.complete(decoded);
        } else {
          completer.completeError(StateError('Expected JSON object response'));
        }
      } catch (_) {
        // Not complete JSON yet.
      }
    }

    _notifySub?.cancel();
    _notifySub = _tx!.onValueReceived.listen((value) {
      if (completer.isCompleted) return;
      if (value.isEmpty) return;
      buf.addAll(value);

      // First pass: newline-delimited JSON.
      while (true) {
        final idx = buf.indexOf(0x0A);
        if (idx < 0) break;

        final line = utf8.decode(buf.sublist(0, idx));
        buf.removeRange(0, idx + 1);
        tryCompleteWithString(line);
        if (completer.isCompleted) return;
      }

      // Second pass: if device doesn't send newlines, attempt to decode whole buffer.
      if (buf.isNotEmpty) {
        try {
          final s = utf8.decode(buf);
          tryCompleteWithString(s);
        } catch (_) {
          // ignore
        }
      }
    });

    await action();

    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('timeout');
      });
    } finally {
      await _notifySub?.cancel();
      _notifySub = null;
    }
  }

  Future<void> reboot({Duration timeout = const Duration(seconds: 5)}) async {
    if (_rx == null) throw StateError('Not connected');
    try {
      await sendJsonCommand({'cmd': 'reboot'}, timeout: timeout);
    } catch (_) {
      // Device may reset before responding, that's expected.
    }
  }

  Future<void> resetDefaults(
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_rx == null) throw StateError('Not connected');
    try {
      final resp = await sendJsonCommand({'cmd': 'reset'}, timeout: timeout);
      if (resp['status'] != 'ok') {
        throw StateError('RESET failed: ${resp['msg'] ?? 'unknown error'}');
      }
    } catch (e) {
      if (e is StateError) rethrow;
      // Fallback to legacy protocol.
      final resp = await _waitForLine(
          timeout: timeout,
          action: () async {
            await _rx!.write(utf8.encode('RESET\n'), withoutResponse: true);
          });
      if (resp != 'OK') {
        throw StateError('RESET failed: $resp');
      }
    }
  }

  Future<String> _waitForLine(
      {required Duration timeout,
      required Future<void> Function() action}) async {
    if (_tx == null) throw StateError('Not connected');

    final completer = Completer<String>();
    final buf = <int>[];

    _notifySub?.cancel();
    _notifySub = _tx!.onValueReceived.listen((value) {
      if (completer.isCompleted) return;
      if (value.isEmpty) return;
      buf.addAll(value);

      while (true) {
        final idx = buf.indexOf(0x0A);
        if (idx < 0) return;

        final line = utf8.decode(buf.sublist(0, idx)).trim();
        buf.removeRange(0, idx + 1);

        // Ignore stale GET data that might still be in the notify stream.
        if (line.isEmpty) continue;
        if (line.startsWith('LEN:')) continue;
        if (line.startsWith('{') ||
            line.startsWith('"') ||
            line.startsWith('[')) continue;

        completer.complete(line);
        return;
      }
    });

    await action();

    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('timeout');
      });
    } finally {
      await _notifySub?.cancel();
      _notifySub = null;
    }
  }

  Future<String> _waitForAck(
      {required Duration timeout,
      required Future<void> Function() action}) async {
    if (_tx == null) throw StateError('Not connected');

    final completer = Completer<String>();
    final buf = <int>[];

    void completeIfAck(String line) {
      if (completer.isCompleted) return;
      if (line == 'OK' || line.startsWith('ERR:')) {
        completer.complete(line);
      }
    }

    _notifySub?.cancel();
    _notifySub = _tx!.onValueReceived.listen((value) {
      if (completer.isCompleted) return;
      if (value.isEmpty) return;
      buf.addAll(value);

      while (true) {
        final idx = buf.indexOf(0x0A);
        if (idx < 0) return;

        final line = utf8.decode(buf.sublist(0, idx)).trim();
        buf.removeRange(0, idx + 1);

        // Ignore stale GET data that might still be in the notify stream.
        if (line.isEmpty) continue;
        if (line.startsWith('LEN:')) continue;
        if (line.startsWith('{') ||
            line.startsWith('"') ||
            line.startsWith('[')) continue;

        completeIfAck(line);
        if (completer.isCompleted) return;
      }
    });

    await action();

    try {
      return await completer.future.timeout(timeout, onTimeout: () {
        throw TimeoutException('timeout');
      });
    } finally {
      await _notifySub?.cancel();
      _notifySub = null;
    }
  }

  Future<void> disconnect() async {
    try {
      _notifySub?.cancel();
      _notifySub = null;
      if (_connectedDevice?.isConnected == true) {
        await _connectedDevice?.disconnect();
      }
    } finally {
      _connectedDevice = null;
      _rx = null;
      _tx = null;
      onStatusChanged?.call('Disconnected');
    }
  }

  void dispose() {
    _notifySub?.cancel();
    _scanSub?.cancel();
    _scanTimer?.cancel();
    _devicesController.close();
    FlutterBluePlus.stopScan();
  }
}
